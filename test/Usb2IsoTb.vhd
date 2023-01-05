package IsoTstPkg is
   -- not conforming to USB spec but OK for testing (multiple pkt/microframe have larger min size)
   constant ISO_EP_PKTSZ_C : natural := 8;
end package IsoTstPkg;

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

use     work.Usb2Pkg.all;
use     work.UlpiPkg.all;
use     work.Usb2UtilPkg.all;
use     work.Usb2DescPkg.all;

use     work.IsoTstPkg.all;

package body Usb2AppCfgPkg is

   procedure pr(constant x: Usb2ByteArray) is
      variable s : string(1 to 8);
   begin
      for i in x'range loop
         for j in x(i)'left downto x(i)'right loop
            s(8-j) := std_logic'image(x(i)(j))(2);
         end loop;
         report "D[" & integer'image(i) & "]  => " & s;
      end loop;
   end procedure pr;

   function USB2_APP_DESCRIPTORS_F return Usb2ByteArray is
      constant c : Usb2ByteArray := (
      -- Usb2DeviceDesc
        0 => x"12",
        1 => x"01",
        2 => x"00",
        3 => x"00",
        4 => x"00",
        5 => x"00",
        6 => x"00",
        7 => x"40",
        8 => x"23",
        9 => x"01",
       10 => x"cd",
       11 => x"ab",
       12 => x"00",
       13 => x"01",
       14 => x"00",
       15 => x"01",
       16 => x"00",
       17 => x"01",
      -- Usb2ConfigurationDesc
       18 => x"09",
       19 => x"02",
       20 => x"20",
       21 => x"00",
       22 => x"01",
       23 => x"01",
       24 => x"00",
       25 => x"80",
       26 => x"32",
      -- Usb2InterfaceDesc
       27 => x"09",
       28 => x"04",
       29 => x"00",
       30 => x"00",
       31 => x"02",
       32 => x"00",
       33 => x"00",
       34 => x"00",
       35 => x"00",
      -- Usb2EndpointDesc
       36 => x"07",
       37 => x"05",
       38 => x"81",
       39 => x"01", -- ISO
       40 => std_logic_vector( to_unsigned( ISO_EP_PKTSZ_C, 8 ) ), -- max pkt
       41 => x"20", -- 12:11 additional pkts/uFrame
       42 => x"00",
      -- Usb2EndpointDesc
       43 => x"07",
       44 => x"05",
       45 => x"01",
       46 => x"01", -- ISO
       47 => std_logic_vector( to_unsigned( ISO_EP_PKTSZ_C, 8 ) ), -- max pkt
       48 => x"20", -- 12:11 additional pkts/uFrame
       49 => x"00",
      -- Usb2Desc
       50 => x"04",
       51 => x"03",
       52 => x"09",
       53 => x"04",
      -- Usb2StringDesc
       54 => x"2e",
       55 => x"03",
       56 => x"54",
       57 => x"00",
       58 => x"69",
       59 => x"00",
       60 => x"6c",
       61 => x"00",
       62 => x"6c",
       63 => x"00",
       64 => x"27",
       65 => x"00",
       66 => x"73",
       67 => x"00",
       68 => x"20",
       69 => x"00",
       70 => x"55",
       71 => x"00",
       72 => x"4c",
       73 => x"00",
       74 => x"50",
       75 => x"00",
       76 => x"49",
       77 => x"00",
       78 => x"20",
       79 => x"00",
       80 => x"54",
       81 => x"00",
       82 => x"65",
       83 => x"00",
       84 => x"73",
       85 => x"00",
       86 => x"74",
       87 => x"00",
       88 => x"20",
       89 => x"00",
       90 => x"42",
       91 => x"00",
       92 => x"6f",
       93 => x"00",
       94 => x"61",
       95 => x"00",
       96 => x"72",
       97 => x"00",
       98 => x"64",
       99 => x"00",
      -- Usb2Desc
      100 => x"02",
      101 => x"ff"
      );
   begin
   return c;
   end function;

end package body Usb2AppCfgPkg;

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

use     work.Usb2Pkg.all;
use     work.UlpiPkg.all;
use     work.Usb2UtilPkg.all;
use     work.Usb2TstPkg.all;
use     work.Usb2AppCfgPkg.all;
use     work.Usb2DescPkg.all;
use     work.IsoTstPkg.all;

entity Usb2IsoTb is
end entity Usb2IsoTb;

architecture sim of Usb2IsoTb is

   constant TST_EP_IDX_C           : natural := 1;
   constant TST_EP_C               : Usb2EndpIdxType := to_unsigned(TST_EP_IDX_C,Usb2EndpIdxType'length);

   constant DEV_ADDR_C             : Usb2DevAddrType := Usb2DevAddrType( to_unsigned(66, Usb2DevAddrType'length) );

   constant CONFIG_VALUE_C         : std_logic_vector(7 downto 0) := x"01";
   -- index is zero-based (?)
   constant CONFIG_INDEX_C         : std_logic_vector(7 downto 0) := x"00";

   constant NUM_ENDPOINTS_C        : natural                      := USB2_APP_NUM_ENDPOINTS_F(USB2_APP_DESCRIPTORS_C);

   constant ALT_C                  : std_logic_vector(15 downto 0) := x"0000";
   constant IFC_C                  : std_logic_vector(15 downto 0) := x"0000";
   
   signal epIb                     : Usb2EndpPairIbArray(1 to NUM_ENDPOINTS_C - 1) := (others => USB2_ENDP_PAIR_IB_INIT_C);
   signal epOb                     : Usb2EndpPairObArray(0 to NUM_ENDPOINTS_C - 1) := (others => USB2_ENDP_PAIR_OB_INIT_C);

   signal usb2Rx                   : Usb2RxType := USB2_RX_INIT_C;

   constant EP1_C                  : natural    := TST_EP_IDX_C;

   constant d2 : Usb2ByteArray := (
      x"c7",
      x"3d",
      x"25",
      x"93",
      x"ba",
      x"bb",
      x"b3",
      x"5e",
      x"54",
      x"5a",
      x"ac",
      x"5a",
      x"6c",
      x"ee",
      x"00",
      x"ab"
   );

   type RcvStateType is ( IDLE, RCV );

   type RcvRegType is record
      state        : RcvStateType;
      framNo       : integer;
      idx          : natural;
   end record RcvRegType;

   constant RCV_REG_INIT_C : RcvRegType := (
      state        => IDLE,
      framNo       => -1,
      idx          => 0
   );

   signal rcvReg : RcvRegType             := RCV_REG_INIT_C;

   function vx(constant l : in natural) return Usb2ByteArray is
      variable v : Usb2ByteArray(1 to l);
   begin
      for i in v'range loop
         v(i) := std_logic_vector( to_unsigned( i, 8 ) );
      end loop;
      return v;
   end function vx;

   constant V3_C : natural := 3;
   constant V8_C : natural := 8;
   constant V9_C : natural := 9;
   constant V16_C : natural := 16;
   constant V23_C : natural := 23;
   constant V24_C : natural := 24;

   procedure SendDat(
      signal   ob : inout UlpiIbType;
      constant e  : in    natural;
      constant d  : in    Usb2ByteArray
   ) is
      variable s   : natural;
      variable l   : natural;
      variable p   : Usb2PidType;
      variable r   : integer;
      constant APF : natural := 2; -- additional pkts per microframe
   begin
      s := 1;
      r := d'length;
      assert d'length <= (1 + APF)*ISO_EP_PKTSZ_C report "illegal ISO pkt in test" severity failure;
      p := USB2_PID_DAT_MDATA_C;
      while ( p = USB2_PID_DAT_MDATA_C ) loop
         if ( r > ISO_EP_PKTSZ_C or (r = ISO_EP_PKTSZ_C and d'length < (1 + APF)*ISO_EP_PKTSZ_C ) ) then
            l := ISO_EP_PKTSZ_C;
         else
            l := r;
            if    ( d'length >= 2*ISO_EP_PKTSZ_C ) then
               p := USB2_PID_DAT_DATA2_C;
            elsif ( d'length >= 1*ISO_EP_PKTSZ_C ) then
               p := USB2_PID_DAT_DATA1_C;
            else
               p := USB2_PID_DAT_DATA0_C;
            end if;
         end if;
         ulpiTstSendTok   ( ob, USB2_PID_TOK_OUT_C, to_unsigned(e, 4), DEV_ADDR_C );
         ulpiTstSendDatPkt( ob, p, d(s to s + l - 1) );
         s := s + l;
         r := r - l;
      end loop;
   end procedure SendDat;

begin

   U_TST : entity work.Usb2TstPkgProcesses;

   P_TST : process is
      variable pid            : std_logic_vector(3 downto 0);
      variable reqval         : std_logic_vector(15 downto 0);
      variable reqidx         : std_logic_vector(15 downto 0);

      constant stridx         : natural                := USB2_APP_STRINGS_IDX_F(USB2_APP_DESCRIPTORS_C);
      constant devdsc         : Usb2ByteArray(0 to 17) := USB2_APP_DESCRIPTORS_C(0  to 17);
      constant cfgdsc         : Usb2ByteArray          := USB2_APP_DESCRIPTORS_C(18 to stridx - 1);
      constant strdsc         : Usb2ByteArray          := USB2_APP_DESCRIPTORS_C(stridx + 4 to stridx + 9);
      variable epCfg          : Usb2TstEpCfgArray      := (others => USB2_TST_EP_CFG_INIT_C);

      constant EP0_SZ_C       : Usb2ByteType           := USB2_APP_DESCRIPTORS_F(USB2_DEV_DESC_IDX_MAX_PKT_SIZE0_C); 
      constant EP1_SZ_C       : Usb2ByteType           := std_logic_vector( to_unsigned( ISO_EP_PKTSZ_C, 8 ) );


   begin
      epCfg( to_integer( USB2_ENDP_ZERO_C ) ).maxPktSizeInp := to_integer(unsigned(EP0_SZ_C));
      epCfg( to_integer( USB2_ENDP_ZERO_C ) ).maxPktSizeOut := to_integer(unsigned(EP0_SZ_C));
      epCfg( TST_EP_IDX_C                   ).maxPktSizeInp := to_integer(unsigned(EP1_SZ_C));
      epCfg( TST_EP_IDX_C                   ).maxPktSizeOut := to_integer(unsigned(EP1_SZ_C));

      ulpiTstHandlePhyInit( ulpiTstOb );

      usb2TstPkgConfig( epCfg );

      ulpiClkTick; ulpiClkTick;

report "SET_ADDRESS";
      ulpiTstSendCtlReq(ulpiTstOb, USB2_REQ_STD_SET_ADDRESS_C, USB2_DEV_ADDR_DFLT_C, val => (x"00" & "0" & DEV_ADDR_C) );
report "SET_CONFIG";
      ulpiTstSendCtlReq(ulpiTstOb, USB2_REQ_STD_SET_CONFIGURATION_C, DEV_ADDR_C, val => (x"00" & CONFIG_VALUE_C ) );
report "SET_INTERFACE";
      ulpiTstSendCtlReq(ulpiTstOb, USB2_REQ_STD_SET_INTERFACE_C,     DEV_ADDR_C, val => ALT_C, idx => IFC_C );

      for i in 0 to 20 loop
         ulpiClkTick;
      end loop;

      ulpiTstSendSOF( ulpiTstOb, to_unsigned( 0, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V3_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( 1, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V3_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( V8_C, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V8_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( V9_C, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V9_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( V16_C, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V16_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( V23_C, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V23_C) );

      ulpiClkTick;
      ulpiTstSendSOF( ulpiTstOb, to_unsigned( V24_C, 11 ) );
      ulpiClkTick;
      SendDat( ulpiTstOb, EP1_C, vx(V24_C) );

      ulpiTstSendSOF( ulpiTstOb, to_unsigned( 255, 11 ) );
      wait;
   end process P_TST;

   P_RCV : process ( ulpiTstClk ) is
   begin
      if ( rising_edge( ulpiTstClk ) ) then
         case ( rcvReg.state ) is
            when IDLE =>
               if ( usb2Rx.pktHdr.vld = '1' and usb2Rx.pktHdr.sof ) then
                  rcvReg.framNo <= to_integer(unsigned(usb2Rx.pktHdr.tokDat));
                  rcvReg.idx    <= 1;
                  rcvReg.state  <= RCV;
               end if;
            when RCV =>
               if ( epOb(EP1_C).mstOut.vld = '1' ) then
                  assert unsigned(epOb(EP1_C).mstOut.usr(1 downto 0)) = (rcvReg.idx - 1) / ISO_EP_PKTSZ_C report "ISO: unexpected USR bits" severity failure;
                  assert to_integer( unsigned( epOb(EP1_C).mstOut.dat ) ) = rcvReg.idx report "ISO RX mismatch" severity failure;
                  rcvReg.idx <= rcvReg.idx + 1;
               end if;
               case ( rcvReg.framNo ) is
                  when 0 | 1 =>
                     if ( epOb(EP1_C).mstOut.don = '1' ) then
                        assert rcvReg.idx = V3_C + 1 report "idx count mismatch" severity failure;
                        rcvReg.state <= IDLE;
                     end if;
                  when V8_C | V9_C =>
                     if ( epOb(EP1_C).mstOut.usr(1 downto 0) = "01" and epOb(EP1_C).mstOut.don = '1' ) then
                        assert rcvReg.idx = rcvReg.framNo + 1 report "idx count mismatch" severity failure;
                        rcvReg.state <= IDLE;
                     end if;
                  when V16_C | V23_C | V24_C =>
                     if ( epOb(EP1_C).mstOut.usr(1 downto 0) = "10" and epOb(EP1_C).mstOut.don = '1' ) then
                        assert rcvReg.idx = rcvReg.framNo + 1 report "idx count mismatch" severity failure;
                        rcvReg.state <= IDLE;
                     end if;
                  when 255 =>
                     ulpiTstRun <= false;
                     report "TEST PASSED";

                  when others =>
               end case;
         end case;
      end if;
   end process P_RCV;

   U_DUT : entity work.Usb2Core
   generic map (
      SIMULATION_G                 => true,
      DESCRIPTORS_G                => USB2_APP_DESCRIPTORS_C
   )
   port map (
      clk                          => ulpiTstClk,

      ulpiRst                      => open,
      usb2Rst                      => open,

      ulpiIb                       => ulpiTstOb,
      ulpiOb                       => ulpiTstIb,

      usb2DevStatus                => open,
      usb2Rx                       => usb2Rx,

      usb2Ep0ReqParam              => open,
      usb2Ep0CtlExt                => open,
      usb2Ep0CtlEpExt              => open,

      usb2EpIb                     => epIb,
      usb2EpOb                     => epOb
   );

end architecture sim;
