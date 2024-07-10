library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity tb_avm_master3 is
end entity tb_avm_master3;

architecture simulation of tb_avm_master3 is

   constant C_DATA_SIZE    : integer := 32;
   constant C_ADDRESS_SIZE : integer := 5;

   signal   clk     : std_logic      := '1';
   signal   rst     : std_logic      := '1';
   signal   running : std_logic      := '1';

   signal   avm_start : std_logic;
   signal   avm_wait  : std_logic;

   signal   avm_write         : std_logic;
   signal   avm_read          : std_logic;
   signal   avm_address       : std_logic_vector(C_ADDRESS_SIZE - 1 downto 0);
   signal   avm_writedata     : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   avm_byteenable    : std_logic_vector(C_DATA_SIZE / 8 - 1 downto 0);
   signal   avm_burstcount    : std_logic_vector(7 downto 0);
   signal   avm_readdata      : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   avm_readdatavalid : std_logic;
   signal   avm_waitrequest   : std_logic;

   constant C_CLK_PERIOD : time      := 10 ns;

begin

   ---------------------------------------------------------
   -- Controller clock and reset
   ---------------------------------------------------------

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   avm_start_proc : process
   begin
      avm_start <= '0';
      wait until rst = '0';

      avm_start <= '1';
      wait until clk = '1';
      avm_start <= '0';
      wait until clk = '1';
      wait until avm_wait = '0';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      avm_start <= '1';
      wait until clk = '1';
      avm_start <= '0';
      wait until clk = '1';
      wait until avm_wait = '0';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      running   <= '0';
      wait;
   end process avm_start_proc;


   ---------------------------------------------------------
   -- Instantiate Master
   ---------------------------------------------------------

   avm_master3_inst : entity work.avm_master3
      generic map (
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         start_i               => avm_start,
         wait_o                => avm_wait,
         m_avm_write_o         => avm_write,
         m_avm_read_o          => avm_read,
         m_avm_address_o       => avm_address,
         m_avm_writedata_o     => avm_writedata,
         m_avm_byteenable_o    => avm_byteenable,
         m_avm_burstcount_o    => avm_burstcount,
         m_avm_readdata_i      => avm_readdata,
         m_avm_readdatavalid_i => avm_readdatavalid,
         m_avm_waitrequest_i   => avm_waitrequest
      ); -- avm_master3_inst


   ---------------------------------------------------------
   -- Instantiate Slave
   ---------------------------------------------------------

   avm_memory_pause_inst : entity work.avm_memory_pause
      generic map (
         G_REQ_PAUSE    => 3,
         G_RESP_PAUSE   => 4,
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i               => clk,
         rst_i               => rst,
         avm_write_i         => avm_write,
         avm_read_i          => avm_read,
         avm_address_i       => avm_address,
         avm_writedata_i     => avm_writedata,
         avm_byteenable_i    => avm_byteenable,
         avm_burstcount_i    => avm_burstcount,
         avm_readdata_o      => avm_readdata,
         avm_readdatavalid_o => avm_readdatavalid,
         avm_waitrequest_o   => avm_waitrequest
      ); -- avm_memory_pause_inst

end architecture simulation;

