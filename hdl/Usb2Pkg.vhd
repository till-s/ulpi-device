library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

package Usb2Pkg is

   subtype  Usb2PidType             is std_logic_vector(3 downto 0);
   subtype  Usb2PidGroupType        is std_logic_vector(1 downto 0);

   subtype  Usb2EndpIdxType         is unsigned(3 downto 0);
   subtype  Usb2DevAddrType         is std_logic_vector(6 downto 0);

   subtype  Usb2ByteType            is std_logic_vector(7 downto 0);
   type     Usb2ByteArray           is array(natural range <>) of Usb2ByteType;
 
   subtype  Usb2TimerType           is signed(17 downto 0);
   constant USB2_TIMER_MAX_C        : Usb2TimerType   := (Usb2TimerType'left => '0', others => '1');
   constant USB2_TIMER_EXPIRED_C    : Usb2TimerType   := (others => '1');

   function usb2TimerExpired(constant t: in Usb2TimerType) return boolean;

   procedure usb2TimerPause(variable t: inout Usb2TimerType);
   procedure usb2TimerStart(variable t: inout Usb2TimerType);

   constant USB2_DEV_ADDR_DFLT_C    : Usb2DevAddrType := (others => '0');
   constant USB2_ENDP_ZERO_C        : Usb2EndpIdxType := (others => '0');

   function usb2PidIsTok(constant x : in Usb2PidType) return boolean;
   function usb2PidIsDat(constant x : in Usb2PidType) return boolean;
   function usb2PidIsHsk(constant x : in Usb2PidType) return boolean;
   function usb2PidIsSpc(constant x : in Usb2PidType) return boolean;

   function usb2PidGroup(constant x : in Usb2PidType) return Usb2PidGroupType;

   constant USB2_PID_GROUP_TOK_C    : Usb2PidGroupType := "01";
   constant USB2_PID_GROUP_DAT_C    : Usb2PidGroupType := "11";
   constant USB2_PID_GROUP_HSK_C    : Usb2PidGroupType := "10";
   constant USB2_PID_GROUP_SPC_C    : Usb2PidGroupType := "00";

   constant USB2_PID_TOK_OUT_C      : Usb2PidType := x"1";
   constant USB2_PID_TOK_SOF_C      : Usb2PidType := x"5";
   constant USB2_PID_TOK_IN_C       : Usb2PidType := x"9";
   constant USB2_PID_TOK_SETUP_C    : Usb2PidType := x"D";

   constant USB2_PID_DAT_DATA0_C    : Usb2PidType := x"3";
   constant USB2_PID_DAT_DATA2_C    : Usb2PidType := x"7";
   constant USB2_PID_DAT_DATA1_C    : Usb2PidType := x"B";
   constant USB2_PID_DAT_MDATA_C    : Usb2PidType := x"F";

   constant USB2_PID_HSK_ACK_C      : Usb2PidType := x"2";
   constant USB2_PID_HSK_NYET_C     : Usb2PidType := x"6";
   constant USB2_PID_HSK_NAK_C      : Usb2PidType := x"A";
   constant USB2_PID_HSK_STALL_C    : Usb2PidType := x"E";

   constant USB2_PID_SPC_PRE_C      : Usb2PidType := x"C";
   constant USB2_PID_SPC_ERR_C      : Usb2PidType := x"C"; -- reused
   constant USB2_PID_SPC_SPLIT_C    : Usb2PidType := x"8";
   constant USB2_PID_SPC_PING_C     : Usb2PidType := x"4";

   constant USB2_PID_SPC_NONE_C     : Usb2PidType := x"0"; -- reserved

   type Usb2PktHdrType is record
      pid     : Usb2PidType;
      tokDat  : std_logic_vector(10 downto 0);
      sof     : boolean;   -- header is a SOF
      vld     : std_logic; -- asserted for 1 cycle
   end record Usb2PktHdrType;

   constant USB2_PKT_HDR_INIT_C : Usb2PktHdrType := (
      pid     => USB2_PID_SPC_NONE_C,
      tokDat  => (others => '0'),
      sof     => false,
      vld     => '0'
   );

   function usb2TokenPktAddr(constant x : in Usb2PktHdrType)
      return Usb2DevAddrType;

   function usb2TokenPktEndp(constant x : in Usb2PktHdrType)
      return Usb2EndpIdxType;

   type Usb2StrmMstType is record
      dat   : std_logic_vector(7 downto 0);
      usr   : std_logic_vector(3 downto 0);
      vld   : std_logic;
      don   : std_logic;
      err   : std_logic; -- when asserted with 'don' then there was e.g., a bad checksum
   end record Usb2StrmMstType;

   constant USB2_STRM_MST_INIT_C : Usb2StrmMstType := (
      dat   => (others => '0'),
      usr   => (others => '0'),
      vld   => '0',
      don   => '0',
      err   => '0'
   );

   type Usb2StrmSubType is record
      rdy   : std_logic;
      -- if an error occurs then the stream is aborted (sender must stop)
      -- i.e., 'don' may be asserted before all the data are sent!
      err   : std_logic;
      don   : std_logic;
   end record Usb2StrmSubType;

   constant USB2_STRM_SUB_INIT_C : Usb2StrmSubType := (
      rdy   => '0',
      err   => '0',
      don   => '0'
   );

   type Usb2RxType is record
      pktHdr       : Usb2PktHdrType;
      rxCmd        : Usb2ByteType; -- last RXCMD seen
      isRxCmd      : boolean;      -- this cycle carries new RXCMD
      rxActive     : boolean;
      mst          : Usb2StrmMstType;
   end record Usb2RxType;

   constant USB2_RX_INIT_C : Usb2RxType := (
      pktHdr       => USB2_PKT_HDR_INIT_C,
      rxCmd        => (others => '0'),
      isRxCmd      => false,
      rxActive     => false,
      mst          => USB2_STRM_MST_INIT_C
   );

   constant USB2_CRC5_POLY_C  : std_logic_vector(15 downto 0) := x"0014";
   constant USB2_CRC5_CHCK_C  : std_logic_vector(15 downto 0) := x"0006";
   constant USB2_CRC5_INIT_C  : std_logic_vector(15 downto 0) := x"001F";

   constant USB2_CRC16_POLY_C : std_logic_vector(15 downto 0) := x"A001";
   constant USB2_CRC16_CHCK_C : std_logic_vector(15 downto 0) := x"B001";
   constant USB2_CRC16_INIT_C : std_logic_vector(15 downto 0) := x"FFFF";

   type Usb2DevStateType is (POWERED, DEFAULT, ADDRESS, CONFIGURED, SUSPENDED);

   type Usb2DevStatusType is record
      state      : Usb2DevStateType;
      devAddr    : Usb2DevAddrType;
      remWakeup  : boolean; -- whether remote wakeup is supported and enabled
      hiSpeed    : boolean; -- device is in hi-speed mode (supported and enabled)
      selHaltInp : std_logic_vector(15 downto 0);
      selHaltOut : std_logic_vector(15 downto 0);
      clrHalt    : std_logic;
      setHalt    : std_logic;
      usb2Rst    : std_logic;
   end record;

   constant USB2_DEV_STATUS_INIT_C : Usb2DevStatusType := (
      state      => DEFAULT,
      devAddr    => (others => '0'),
      hiSpeed    => false,
      remWakeup  => false,
      selHaltInp => (others => '0'),
      selHaltOut => (others => '0'),
      clrHalt    => '0',
      setHalt    => '0',
      usb2Rst    => '0'
   );

   -- HANDSHAKE
   -- Between endpoints and the packet engine the following
   -- handshake protocol is used in IN direction (mstInp/subInp)
   --
   --   mst.vld  mst.don  mst.dat sub.rdy
   --      1        0       Dn       0         master has data
   --      1        0       Dn       1         sub consumes Dn
   --      1        0       Dn+1     1         sub consumes Dn+1
   --      1        0       Dn+2     0         wait cycle (optional)
   --      1        0       Dn+2     1         sub consumes Dn+2
   --      0        1        X       0         master done
   --      0        1        X       0         wait cycle (optional)
   --      0        1        X       1         sub consumes 'don' flag
   --
   -- NOTES:
   --   - mst.vld and mst.don must never be asserted during the same cycle
   --   - mst.vld, once asserted must not be deasserted until 'don'
   --   - zero-length packets are sent using the same protocol; no cycle
   --     has 'vld' asserted:
   --      0        1        X        0       NULL packet
   --      0        1        X        1       sub consumes 'don' flag
   --   - if the endpoint sets the 'bFramedInp' (no framing) flag
   --     then the 'don' flag is not used (and must never be asserted).
   --     Packets are directly framed by 'vld' but no NULL packets can
   --     be sent; packets are always at least 1 byte.
   --
   -- In the OUT direction a slightly different protocol must be
   -- observed. Since the EP must be able to absorb an entire max. packet
   -- as soon as it has signalled 'rdy' this flag has no further meaning
   -- for the current packet but is used to signal if further packets
   -- also are acceptable. This is necessary to handle the high-speed
   -- protocol in presence of our RX buffer (engine needs to know if
   -- it can fill the buffer with the next frame while the current
   -- one is being read out).
   -- Payload frames are framed by 'vld' and/or 'don', i.e., between
   -- two frames there is at least one cycle with 'vld' deasserted.
   --
   --    mst.vld   mst.don  sub.rdy
   --       0          0       1        -- EP ready for data
   --       1          0       1        -- EP starts reading
   --       1          0       0        --> no further packets allowed into the buffer
   --       1          0       0        --> EP continues reading
   --       1          0       0        --> EP continues reading
   --       0          0       0        --> frame received (assume max pkt size 4)
   --       0          0       1        -> EP ready for data
   --       0          1       1        -> received NULL packet
   --       0          0       1        -> 
   --       0          0       1        -> ready for next
   --       1          0       1        -> EP starts reading
   --       1          0       1        -> continue reading; meanwhile next frame is allowed
   --       1          0       1        -> in to the buffer (and could be consumed)
   --       0          1       1        -> frame done (short)
   --       1          0       1        -> receive next frame
   --       1          0       0        -> throttle next but keep reading current
   --       1          0       0        -> throttle next but keep reading current
   --       1          0       0        -> throttle next but keep reading current
   --       0          0       0        -> End of frame

   -- signals traveling from EP -> bus
   type Usb2EndpPairIbType is record
      stalledInp : std_logic; -- input  endpoint is halted
      stalledOut : std_logic; -- output endpoint is halted
      bFramedInp : std_logic; -- when set: no framing by 'don'; send as soon as 'vld' deasserted or maxPktSize reached
      -- if mstInp.vld is asserted then the endpoint
      -- must be able to supply the entire payload of
      -- a data packet (or less if there is no data); 
      -- empty packets are sent setting 'vld = 0, don = 1'
      mstInp     : Usb2StrmMstType;
      -- if subOut.rdy is asserted then the endpoint
      -- must be able to absorb an entire payload of
      -- packet data.
      subOut     : Usb2StrmSubType;
   end record Usb2EndpPairIbType;

   constant USB2_ENDP_PAIR_IB_INIT_C : Usb2EndpPairIbType := (
      stalledInp => '0',
      stalledOut => '0',
      bFramedInp => '0',
      mstInp     => USB2_STRM_MST_INIT_C,
      subOut     => USB2_STRM_SUB_INIT_C
   );
 
   -- signals traveling from bus -> EP
   type Usb2EndpPairObType is record
      mstOut     : Usb2StrmMstType;
      subInp     : Usb2StrmSubType;
      -- control endpoints receive setup data here;
      mstCtl     : Usb2StrmMstType;
   end record Usb2EndpPairObType;

   constant USB2_ENDP_PAIR_OB_INIT_C : Usb2EndpPairObType := (
      mstOut     => USB2_STRM_MST_INIT_C,
      subInp     => USB2_STRM_SUB_INIT_C,
      mstCtl     => USB2_STRM_MST_INIT_C
   );

   subtype Usb2TransferType is std_logic_vector(1 downto 0);

   subtype Usb2PktSizeType  is unsigned(10 downto 0);

   constant USB2_TT_CONTROL_C     : Usb2TransferType := "00";
   constant USB2_TT_ISOCHRONOUS_C : Usb2TransferType := "01";
   constant USB2_TT_BULK_C        : Usb2TransferType := "10";
   constant USB2_TT_INTERRUPT_C   : Usb2TransferType := "11";

   -- this information is passed via generic to the packet
   -- processor but also passed into the endpoint descriptor
   -- Note that the endpoint address/number is implicitly
   -- encoded (place of the endpoint in an array).
   -- If one direction of a pair is unsupported/not implemented
   -- then 'maxPktSize' must be set to 0.
   type Usb2EndpPairConfigType is record
      transferTypeInp  : Usb2TransferType;
      maxPktSizeInp    : Usb2PktSizeType;
      hasHaltInp       : boolean;
      transferTypeOut  : Usb2TransferType;
      maxPktSizeOut    : Usb2PktSizeType;
      hasHaltOut       : boolean;
   end record Usb2EndpPairConfigType;

   constant USB2_ENDP_PAIR_CONFIG_INIT_C : Usb2EndpPairConfigType := (
      transferTypeInp  => USB2_TT_CONTROL_C,
      maxPktSizeInp    => (others => '0'),
      hasHaltInp       => true,
      transferTypeOut  => USB2_TT_CONTROL_C,
      maxPktSizeOut    => (others => '0'),
      hasHaltOut       => true
   );

   type Usb2EndpPairConfigArray is array (natural range <>) of Usb2EndpPairConfigType;
   type Usb2EndpPairIbArray       is array (natural range <>) of Usb2EndpPairIbType;
   type Usb2EndpPairObArray       is array (natural range <>) of Usb2EndpPairObType;

   type Usb2DevConfigType is record
      hasRemoteWakeup  : boolean;
   end record Usb2DevConfigType;

   function USB2_REQ_TYP_DEV2HOST_F (constant reqTyp : in Usb2ByteType) return boolean;
   function USB2_REQ_TYP_TYPE_F     (constant reqTyp : in Usb2ByteType) return std_logic_vector;
   function USB2_REQ_TYP_RECIPIENT_F(constant reqTyp : in Usb2ByteType) return std_logic_vector;

   constant USB2_REQ_TYP_TYPE_STANDARD_C           : std_logic_vector(1 downto 0) := "00";
   constant USB2_REQ_TYP_TYPE_CLASS_C              : std_logic_vector(1 downto 0) := "01";
   constant USB2_REQ_TYP_TYPE_VENDOR_C             : std_logic_vector(1 downto 0) := "10";

   constant USB2_REQ_TYP_RECIPIENT_DEV_C           : std_logic_vector(1 downto 0) := "00";
   constant USB2_REQ_TYP_RECIPIENT_IFC_C           : std_logic_vector(1 downto 0) := "01";
   constant USB2_REQ_TYP_RECIPIENT_EPT_C           : std_logic_vector(1 downto 0) := "10";

   subtype  Usb2StdRequestCodeType                 is unsigned(3 downto 0);
   constant USB2_REQ_STD_GET_STATUS_C              : Usb2StdRequestCodeType     := x"0";
   constant USB2_REQ_STD_CLEAR_FEATURE_C           : Usb2StdRequestCodeType     := x"1";
   constant USB2_REQ_STD_SET_FEATURE_C             : Usb2StdRequestCodeType     := x"3";
   constant USB2_REQ_STD_SET_ADDRESS_C             : Usb2StdRequestCodeType     := x"5";
   constant USB2_REQ_STD_GET_DESCRIPTOR_C          : Usb2StdRequestCodeType     := x"6";
   constant USB2_REQ_STD_SET_DESCRIPTOR_C          : Usb2StdRequestCodeType     := x"7";
   constant USB2_REQ_STD_GET_CONFIGURATION_C       : Usb2StdRequestCodeType     := x"8";
   constant USB2_REQ_STD_SET_CONFIGURATION_C       : Usb2StdRequestCodeType     := x"9";
   constant USB2_REQ_STD_GET_INTERFACE_C           : Usb2StdRequestCodeType     := x"A";
   constant USB2_REQ_STD_SET_INTERFACE_C           : Usb2StdRequestCodeType     := x"B";
   constant USB2_REQ_STD_SYNCH_FRAME_C             : Usb2StdRequestCodeType     := x"C";

   subtype  Usb2CtlRequestCodeType                 is unsigned(7 downto 0);

   -- class-specific request
   constant USB2_REQ_CLS_CDC_SEND_BREAK_C          : Usb2CtlRequestCodeType     := x"23";

   subtype  Usb2StdDescriptorTypeType              is unsigned(3 downto 0);
   constant USB2_STD_DESC_TYPE_DEVICE_C            : Usb2StdDescriptorTypeType  := x"1";
   constant USB2_STD_DESC_TYPE_CONFIGURATION_C     : Usb2StdDescriptorTypeType  := x"2";
   constant USB2_STD_DESC_TYPE_STRING_C            : Usb2StdDescriptorTypeType  := x"3";
   constant USB2_STD_DESC_TYPE_INTERFACE_C         : Usb2StdDescriptorTypeType  := x"4";
   constant USB2_STD_DESC_TYPE_ENDPOINT_C          : Usb2StdDescriptorTypeType  := x"5";
   constant USB2_STD_DESC_TYPE_DEVICE_QUALIFIER_C  : Usb2StdDescriptorTypeType  := x"6";
   constant USB2_STD_DESC_TYPE_OTHER_SPEED_CONF_C  : Usb2StdDescriptorTypeType  := x"7";
   constant USB2_STD_DESC_TYPE_INTERFACE_POWER_C   : Usb2StdDescriptorTypeType  := x"8";
   -- use as a sentinel to terminate table
   constant USB2_STD_DESC_TYPE_SENTINEL_C          : Usb2ByteType               := x"FF";

   function usb2DescIsSentinel(constant x: Usb2ByteType) return boolean;
    
   subtype  Usb2StdFeatureType                     is unsigned(1 downto 0);
   constant USB2_STD_FEAT_ENDPOINT_HALT_C          : Usb2StdFeatureType         := "00";
   constant USB2_STD_FEAT_DEVICE_REMOTE_WAKEUP_C   : Usb2StdFeatureType         := "01";
   constant USB2_STD_FEAT_DEVICE_TEST_MODE_C       : Usb2StdFeatureType         := "10";

   type     Usb2CtlReqParamType is record
      dev2Host  : boolean;
      reqType   : std_logic_vector( 1 downto 0);
      recipient : std_logic_vector( 1 downto 0);
      -- hold all bits to support non-std requests
      request   : Usb2CtlRequestCodeType;
      value     : std_logic_vector(15 downto 0);
      index     : std_logic_vector(15 downto 0);
      length    : unsigned        (15 downto 0);
      vld       : std_logic;
   end record Usb2CtlReqParamType;

   constant USB2_CTL_REQ_PARAM_INIT_C : Usb2CtlReqParamType := (
      dev2Host  => false,
      reqType   => ( others => '0' ),
      recipient => ( others => '0' ),
      request   => ( others => '0' ),
      value     => ( others => '0' ),
      index     => ( others => '0' ),
      length    => ( others => '0' ),
      vld       => '0'
    );

   type Usb2CtlExtType is record
      -- 'ack' the param's 'vld' flag
      ack       : std_logic;
      -- if set during the 'ack' phase
      -- then the external agent is OK
      -- to take over the data phase of
      -- the request; otherwise (err=1)
      -- a STALL will be emitted by the
      -- default controller.
      err       : std_logic;
      -- once the external agent is
      -- finished processing it asserts
      -- 'don' for 1 cycle and conveys
      -- status:
      --    don  ack  err
      --     1    0    0    -> NAK
      --     1    1    0    -> ACK
      --     1    0    1    -> STALL
      --     1    1    1    -> STALL
      don       : std_logic;
   end record Usb2CtlExtType;

   constant USB2_CTL_EXT_NAK_C : Usb2CtlExtType := (
      ack       => '1',
      err       => '1',
      don       => '0'
   );

   constant USB2_CTL_EXT_INIT_C : Usb2CtlExtType := (
      ack       => '0',
      err       => '0',
      don       => '0'
   );

   subtype  Usb2Utf16CharType is std_logic_vector(15 downto 0);

   constant USB2_LANGID_EN_US_C : Usb2Utf16CharType := x"0409";
   constant USB2_LANGID_EN_UK_C : Usb2Utf16CharType := x"0809";
   constant USB2_LANGID_EN_AU_C : Usb2Utf16CharType := x"0c09";

end package Usb2Pkg;

package body Usb2Pkg is

   function usb2TokenPktAddr(constant x : in Usb2PktHdrType)
      return Usb2DevAddrType is
   begin
      return x.tokDat(6 downto 0);
   end function usb2TokenPktAddr;

   function usb2TokenPktEndp(constant x : in Usb2PktHdrType)
      return Usb2EndpIdxType is
   begin
      return unsigned( x.tokDat(10 downto 7) );
   end function usb2TokenPktEndp;

   function usb2PidIsTok(constant x : in Usb2PidType) return boolean is
   begin
      return ( x(1 downto 0) = "01" ) or ( x = USB2_PID_SPC_PING_C );
   end function usb2PidIsTok;

   function usb2PidIsDat(constant x : in Usb2PidType) return boolean is
   begin
      return x(1 downto 0) = "11";
   end function usb2PidIsDat;

   function usb2PidIsHsk(constant x : in Usb2PidType) return boolean is
   begin
      return x(1 downto 0) = "10";
   end function usb2PidIsHsk;

   function usb2PidIsSpc(constant x : in Usb2PidType) return boolean is
   begin
      return x(1 downto 0) = "00";
   end function usb2PidIsSpc;

   function usb2PidGroup(constant x : in Usb2PidType) return Usb2PidGroupType is
   begin
      return x(1 downto 0);
   end function usb2PidGroup;

   function USB2_REQ_TYP_DEV2HOST_F (constant reqTyp : in Usb2ByteType)
   return boolean is begin
      return reqTyp(7) = '1';
   end function USB2_REQ_TYP_DEV2HOST_F;

   function USB2_REQ_TYP_TYPE_F     (constant reqTyp : in Usb2ByteType)
   return std_logic_vector is begin
      return reqTyp(6 downto 5);
   end function USB2_REQ_TYP_TYPE_F;

   function USB2_REQ_TYP_RECIPIENT_F(constant reqTyp : in Usb2ByteType)
   return std_logic_vector is begin
      return reqTyp(1 downto 0);
   end function USB2_REQ_TYP_RECIPIENT_F;

   function usb2DescIsSentinel(constant x: Usb2ByteType)
   return boolean is begin
      return x(7) = '1';
   end function usb2DescIsSentinel;
   
   function usb2TimerExpired(constant t: in Usb2TimerType)
   return boolean is begin
      return t(t'left) = '1';
   end function usb2TimerExpired;

   procedure usb2TimerPause(variable t: inout Usb2TimerType)
   is begin
      t := t;
      t(t'left) := '1';
   end procedure usb2TimerPause;

   procedure usb2TimerStart(variable t: inout Usb2TimerType)
   is begin
      t := t;
      t(t'left) := '0';
   end procedure usb2TimerStart;

end package body Usb2Pkg;
