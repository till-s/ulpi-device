library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

use     work.Usb2Pkg.all;
use     work.UlpiPkg.all;
use     work.UsbUtilPkg.all;
use     work.Usb2TstPkg.all;
use     work.Usb2AppCfgPkg.all;
use     work.Usb2DescPkg.all;

entity Usb2HskTb is
end entity Usb2HskTb;

architecture sim of Usb2HskTb is

   signal txDataMst       : Usb2StrmMstType := USB2_STRM_MST_INIT_C;
   signal txDataSub       : Usb2StrmSubType := USB2_STRM_SUB_INIT_C;

   signal ulpiRx          : UlpiRxType;
   signal ulpiTxReq       : UlpiTxReqType   := ULPI_TX_REQ_INIT_C;
   signal ulpiTxRep       : UlpiTxRepType;

   signal iidx            : integer         := 0;
   signal vidx            : natural         := 0;
   signal vend            : integer         := 0;

   signal epRst           : std_logic       := '0';

begin

   U_TST : entity work.Usb2TstPkgProcesses;

   P_TST : process is
      variable pid : std_logic_vector(3 downto 0);
      variable st  : std_logic_vector(7 downto 0);
   begin
      ulpiClkTick;
      ulpiClkTick;
      ulpiClkTick;
      ulpiClkTick;
      ulpiClkTick;
      ulpiClkTick;
      st := x"00";
      ulpiTstWaitHsk( ulpiTstOb, pid, 100, st );
      report "got PID " & integer'image(to_integer(unsigned(pid))) & " ST " & integer'image(to_integer(unsigned(st)));
      ulpiClkTick;
      
      ulpiTstRun <= false;
      report "TEST PASSED";
      wait;
   end process P_TST;

   U_DUT : entity work.Usb2PktTx
   port map (
      clk                          => ulpiTstClk,
      rst                          => open,
      ulpiTxReq                    => ulpiTxReq,
      ulpiTxRep                    => ulpiTxRep,
      txDataMst                    => txDataMst,
      txDataSub                    => txDataSub,
      hiSpeed                      => '0'
   );

   U_ULPI_IO : entity work.UlpiIO
   port map (
      clk                          => ulpiTstClk,
      rst                          => open,
      
      dir                          => ulpiTstOb.dir,
      stp                          => ulpiTstIb.stp,
      nxt                          => ulpiTstOb.nxt,
      dat                          => ulpiDatIO,

      ulpiRx                       => ulpiRx,
      ulpiTxReq                    => ulpiTxReq,
      ulpiTxRep                    => ulpiTxRep,

      regReq                       => open,
      regRep                       => open
   );

   P_DRV : process is
   begin
      txDataMst.dat <= (others => '0');
      txDataMst.usr <= x"2";
      txDataMst.vld <= '0';
      txDataMst.don <= '1';
      ulpiClkTick;
      while ( txDataSub.don = '0' ) loop
         ulpiClkTick;
      end loop;
      txDataMst.don <= '0';
      ulpiClkTick;
      wait;
   end process P_DRV;

end architecture sim;
