import sys
import io

# accessor for an attribute
def acc(off,sz=1):
    def deco(func):
      def setter(self, v = None):
         if ( v is None ):
            v = 0
            for i in range(sz):
               v |= (self.cont[off+i] << (8*i))
            return v
         v = func(self, v)
         for i in range(sz):
            self.cont[off + i] = (v & 0xff)
            v >>= 8
         return self
      return setter
    return deco

class Usb2DescContext(list):

  def __init__(self):
    super().__init__()
    self.strtbl_  = []
    # language IDs
    self.wrapped_ = False

  @property
  def wrapped(self):
    return self.wrapped_

  def nStrings(self):
    return len(self.strtbl_)

  def addString(self, s):
    if ( self.wrapped ):
      raise RuntimeError("Nothing can be added to the context once it is wrapped")
    try:
      return self.strtbl_.index(s) + 1
    except ValueError:
      self.strtbl_.append(s)
      return len(self.strtbl_)

  def wrapup(self):
    if ( self.wrapped ):
       raise RuntimeError("Context is already wrapped")
    cnf  = None
    totl = 0
    numi = 0
    ns   = self.Usb2Desc.clazz
    seti = set()
    for d in self:
      if ( d.bDescriptorType() == ns.DSC_TYPE_CONFIGURATION ):
        if ( not cnf is None ):
          break
        cnf  = d
        totl = 0
        numi = 0
        seti = set()
      if ( d.bDescriptorType() == ns.DSC_TYPE_INTERFACE ):
        ifn =  d.bInterfaceNumber()
        if not ifn in seti:
           numi += 1
           seti.add(ifn)
      totl += d.bLength()
    print("Total length {:d}, num interfaces {:d}".format(totl, numi))
    cnf.wTotalLength(totl)
    cnf.bNumInterfaces(numi)
    # append string descriptors
    if ( len( self.strtbl_ ) > 0 ):
      # lang-id at string index 0
      self.Usb2Desc(4, ns.DSC_TYPE_STRING).cont[2:4] = [0x09, 0x04]
      for s in self.strtbl_:
         self.Usb2StringDesc( s )
    # append TAIL
    self.Usb2Desc(2, ns.DSC_TYPE_RESERVED)
    self.wrapped_ = True

  def vhdl(self, f = sys.stdout):
    if ( not self.wrapped ):
      RuntimeError("Must wrapup context before VHDL can be emitted")
    if isinstance(f, str):
      with io.open(f, "w") as f:
         self.vhdl(f)
    else:
      i = 0
      for x in self:
        for b in x.cont:
           print('      {:3d} => x"{:02x}",'.format(i, b), file = f)
           i += 1


  # the 'factory' decorator converts local classes
  # to factory methods of the context class. Subclasses
  # of the local classes use the 'clazz' attribute from
  # the decorated members (which have been converted
  # from class constructors to context members)
  def factory(clazz):
    def instantiate(ctxt, *args, **kwargs):
      if ( ctxt.wrapped ):
        raise RuntimeError("Nothing can be added to the context once it is wrapped")
      i = clazz(*args, **kwargs)
      i.setContext(ctxt)
      ctxt.append(i)
      return i
    setattr(instantiate, "clazz", clazz)
    return instantiate

  @factory
  class Usb2Desc(object):

    DSC_TYPE_RESERVED                  = 0x00
    DSC_TYPE_DEVICE                    = 0x01
    DSC_TYPE_CONFIGURATION             = 0x02
    DSC_TYPE_STRING                    = 0x03
    DSC_TYPE_INTERFACE                 = 0x04
    DSC_TYPE_ENDPOINT                  = 0x05
    DSC_TYPE_DEVICE_QUALIFIER          = 0x06
    DSC_TYPE_OTHER_SPEED_CONFIGURATION = 0x07
    DSC_TYPE_INTEFACE_POWER            = 0x08

    DSC_DEV_CLASS_NONE                 = 0x00
    DSC_DEV_SUBCLASS_NONE              = 0x00
    DSC_DEV_PROTOCOL_NONE              = 0x00
    DSC_DEV_CLASS_CDC                  = 0x02

    DSC_IFC_CLASS_CDC                  = 0x02

    DSC_CDC_SUBCLASS_ACM               = 0x02
    DSC_CDC_SUBCLASS_ECM               = 0x06

    DSC_CDC_PROTOCOL_NONE              = 0x00

    DSC_IFC_CLASS_DAT                  = 0x0A
    DSC_DAT_SUBCLASS_NONE              = 0x00
    DSC_DAT_PROTOCOL_NONE              = 0x00

    def __init__(self, length, typ):
      super().__init__()
      self.cont_    = bytearray(length)
      self.bLength( length )
      self.bDescriptorType( typ )
      self.ctxt_ = None

    def setContext(self, ctxt):
      self.ctxt_ = ctxt

    @property
    def context(self):
      return self.ctxt_

    def addString(self, s):
      return self.context.addString(s)

    def len(self):
      return len(self.cont)

    @property
    def cont(self):
      return self.cont_
    @acc(0)
    def bLength(self, v): return v
    @acc(1)
    def bDescriptorType(self, v): return v

  @factory
  class Usb2StringDesc(Usb2Desc.clazz):

    def __init__(self, s):
      senc = s.encode('utf-16-le')
      super().__init__(2 + len(senc), self.DSC_TYPE_STRING)
      self.cont[2:] = senc

    def __repr__(self):
      return self.cont[2:].decode('utf-16-le')

  @factory
  class Usb2DeviceDesc(Usb2Desc.clazz):

    def __init__(self):
      super().__init__(18, self.DSC_TYPE_DEVICE)
      self.bcdDevice(0x0200)

    @acc(4)
    def bDeviceClass(self, v): return v
    @acc(5)
    def bDeviceSubClass(self, v): return v
    @acc(6)
    def bDeviceProtocol(self, v): return v
    @acc(7)
    def bMaxPacketSize0(self, v): return v
    @acc(8,2)
    def idVendor(self,v): return v 
    @acc(10,2)
    def idProduct(self,v): return v 
    @acc(12,2)
    def bcdDevice(self,v): return v 
    @acc(14)
    def iManufacturer(self, v): return self.addString(v)
    @acc(15)
    def iProduct(self, v): return self.addString(v)
    @acc(16)
    def iSerialNumber(self, v): return self.addString(v)
    @acc(17)
    def bNumConfigurations(self, v): return v

  @factory
  class Usb2ConfigurationDesc(Usb2Desc.clazz):

    CONF_ATT_SELF_POWERED  = 0x40
    CONF_ATT_REMOTE_WAKEUP = 0x20

    def __init__(self):
      super().__init__(9, self.DSC_TYPE_CONFIGURATION)
      self.bmAttributes(0x00)
    @acc(2,2)
    def wTotalLength(self, v): return v
    @acc(4)
    def bNumInterfaces(self, v): return v
    @acc(5)
    def bConfigurationValue(self, v): return v
    @acc(6)
    def iConfiguration(self, v): return self.addString(v)
    @acc(7)
    def bmAttributes(self, v): return v | 0x80
    @acc(8)
    def bMaxPower(self, v): return v

  @factory
  class Usb2InterfaceDesc(Usb2Desc.clazz):
    def __init__(self):
      super().__init__(9, self.DSC_TYPE_INTERFACE)
    @acc(2)
    def bInterfaceNumber(self, v): return v
    @acc(3)
    def bAlternateSetting(self, v): return v
    @acc(4)
    def bNumEndpoints(self, v): return v
    @acc(5)
    def bInterfaceClass(self, v): return v
    @acc(6)
    def bInterfaceSubClass(self, v): return v
    @acc(7)
    def bInterfaceProtocol(self, v): return v
    @acc(8)
    def iInterface(self, v): return self.addString(v)

  @factory
  class Usb2EndpointDesc(Usb2Desc.clazz):
    ENDPOINT_IN  = 0x80
    ENDPOINT_OUT = 0x00

    ENDPOINT_TT_CONTROL            = 0x00
    ENDPOINT_TT_ISOCHRONOUS        = 0x01
    ENDPOINT_TT_BULK               = 0x02
    ENDPOINT_TT_INTERRUPT          = 0x03

    ENDPOINT_SYNC_NONE             = 0x00
    ENDPOINT_SYNC_ASYNC            = 0x04
    ENDPOINT_SYNC_ADAPTIVE         = 0x08
    ENDPOINT_SYNC_SYNCHRONOUS      = 0x0c

    ENDPOINT_USAGE_DATA            = 0x00
    ENDPOINT_USAGE_FEEDBACK        = 0x10
    ENDPOINT_USAGE_IMPLICIT        = 0x20

    def __init__(self):
      super().__init__(7, self.DSC_TYPE_ENDPOINT)
    @acc(2)
    def bEndpointAddress(self, v): return v
    @acc(3)
    def bmAttributes(self, v): return v
    @acc(4,2)
    def wMaxPacketSize(self, v): return v
    @acc(6)
    def bInterval(self, v): return v

  @factory
  class Usb2CDCDesc(Usb2Desc.clazz):

    DSC_TYPE_CS_INTERFACE                                = 0x24
    DSC_TYPE_CS_ENDPOINT                                 = 0x25

    DSC_SUBTYPE_HEADER                                   = 0x00
    DSC_SUBTYPE_CALL_MANAGEMENT                          = 0x01
    DSC_SUBTYPE_UNION                                    = 0x06
    DSC_SUBTYPE_ABSTRACT_CONTROL_MANAGEMENT              = 0x02
    DSC_SUBTYPE_ETHERNET_NETWORKING                      = 0x0F

    def __init__(self, length, typ):
      super().__init__(length, typ)

    @acc(2)
    def bDescriptorSubtype(self, v): return v
    
  @factory
  class Usb2CDCFuncHeaderDesc(Usb2CDCDesc.clazz):
    def __init__(self):
      super().__init__(5, self.DSC_TYPE_CS_INTERFACE)
      self.bDescriptorSubtype( self.DSC_SUBTYPE_HEADER )
      self.bcdCDC(0x0120)
    @acc(3,2)
    def bcdCDC(self, v): return v

  @factory
  class Usb2CDCFuncCallManagementDesc(Usb2CDCDesc.clazz):
    DSC_CM_HANDLE_MYSELF            = 0x01
    DSC_CM_OVER_DATA                = 0x02
    def __init__(self):
      super().__init__(5, self.DSC_TYPE_CS_INTERFACE)
      self.bDescriptorSubtype( self.DSC_SUBTYPE_CALL_MANAGEMENT )
    @acc(3)
    def bmCapabilities(self, v): return v
    @acc(4)
    def bDataInterface(self, v): return v

  @factory
  class Usb2CDCFuncACMDesc(Usb2CDCDesc.clazz):
    DSC_ACM_SUP_NOTIFY_NETWORK_CONN = 0x08
    DSC_ACM_SUP_SEND_BREAK          = 0x04
    DSC_ACM_SUP_LINE_CODING         = 0x02
    DSC_ACM_SUP_COMM_FEATURE        = 0x01
    def __init__(self):
      super().__init__(4, self.DSC_TYPE_CS_INTERFACE)
      self.bDescriptorSubtype( self.DSC_SUBTYPE_ABSTRACT_CONTROL_MANAGEMENT )
    @acc(3)
    def bmCapabilities(self, v): return v

  @factory
  class Usb2CDCFuncUnionDesc(Usb2CDCDesc.clazz):
    def __init__(self, numSubordinateInterfaces):
      super().__init__(4 + numSubordinateInterfaces, self.DSC_TYPE_CS_INTERFACE)
      self.bDescriptorSubtype( self.DSC_SUBTYPE_UNION )
    @acc(3)
    def bControlInterface(self, v): return v

    def bSubordinateInterface(self, n, v = None):
      if ( n + 4 > self.bLength() ):
        raise ValueError("subordinate interface out of range")
        
      if ( v is None ):
        return self.cont[4 + n]
      self.cont[4+n] = v & 0xff
      return self

  @factory
  class Usb2CDCFuncEthernetDesc(Usb2CDCDesc.clazz):

    DSC_ETH_SUP_MC_PERFECT = 0x8000 # flag in wNumberMCFilters

    def __init__(self):
      super().__init__(13, self.DSC_TYPE_CS_INTERFACE)
      self.bDescriptorSubtype( self.DSC_SUBTYPE_ETHERNET_NETWORKING )
      self.bmEthernetStatistics( 0 )
      self.wMaxSegmentSize( 1514 )
      self.wNumberMCFilters( 0 )
      self.bNumberPowerFilters( 0 )
    @acc(3)
    def iMACAddress(self, v): return self.addString(vo
    @acc(4,4)
    def bmEthernetStatistics(self, v): return v
    @acc(8,2)
    def wMaxSegmentSize(self, v): return v
    @acc(10, 2)
    def wNumberMCFilters(self, v): return v
    @acc(12)
    def bNumberPowerFilters(self, v): return v

def basicACM(epPktSize=8):
  c  = Usb2DescContext()

  # device
  d = c.Usb2DeviceDesc()
  d.bDeviceClass( d.DSC_DEV_CLASS_NONE )
  d.bDeviceSubClass( d.DSC_DEV_SUBCLASS_NONE )
  d.bDeviceProtocol( d.DSC_DEV_PROTOCOL_NONE )
  d.bMaxPacketSize0( 8 )
  d.idVendor(0x0123)
  d.idProduct(0xabcd)
  d.bcdDevice(0x0100)
  d.iProduct( "Till's ULPI Test Board" )
  d.bNumConfigurations(1)

  # configuration
  d = c.Usb2ConfigurationDesc()
  d.bNumInterfaces(2)
  d.bConfigurationValue(1)
  d.bMaxPower(0x32)

  # interface 0
  d = c.Usb2InterfaceDesc()
  d.bInterfaceNumber(0)
  d.bAlternateSetting(0)
  d.bNumEndpoints(1)
  d.bInterfaceClass( d.DSC_IFC_CLASS_CDC )
  d.bInterfaceSubClass( d.DSC_CDC_SUBCLASS_ACM )
  d.bInterfaceProtocol( d.DSC_CDC_PROTOCOL_NONE )

  # functional descriptors; header
  d = c.Usb2CDCFuncHeaderDesc()

  # functional descriptors; call management
  d = c.Usb2CDCFuncCallManagementDesc()
  d.bDataInterface(1)

  # functional descriptors; header
  d = c.Usb2CDCFuncACMDesc()
  d.bmCapabilities(0)

  # functional descriptors; union
  d = c.Usb2CDCFuncUnionDesc( numSubordinateInterfaces = 1 )
  d.bControlInterface( 0 )
  d.bSubordinateInterface( 0, 1 )

  # Endpoint -- unused but linux cdc-acm driver refuses to bind w/o it
  # endpoint 2, INTERRUPT IN
  d = c.Usb2EndpointDesc()
  d.bEndpointAddress( d.ENDPOINT_IN  | 0x02 )
  d.bmAttributes( d.ENDPOINT_TT_INTERRUPT )
  d.wMaxPacketSize(8)
  d.bInterval(255) #ms

  # interface 1
  d = c.Usb2InterfaceDesc()
  d.bInterfaceNumber(1)
  d.bAlternateSetting(0)
  d.bNumEndpoints(2)
  d.bInterfaceClass( d.DSC_IFC_CLASS_DAT )
  d.bInterfaceSubClass( d.DSC_DAT_SUBCLASS_NONE )
  d.bInterfaceProtocol( d.DSC_CDC_PROTOCOL_NONE )

  # endpoint 1, BULK IN
  d = c.Usb2EndpointDesc()
  d.bEndpointAddress( d.ENDPOINT_IN | 0x01 )
  d.bmAttributes( d.ENDPOINT_TT_BULK )
  d.wMaxPacketSize(epPktSize)
  d.bInterval(0)

  # endpoint 1, BULK OUT
  d = c.Usb2EndpointDesc()
  d.bEndpointAddress( d.ENDPOINT_OUT | 0x01 )
  d.bmAttributes( d.ENDPOINT_TT_BULK )
  d.wMaxPacketSize(epPktSize)
  d.bInterval(0)

  c.wrapup()
  return c
