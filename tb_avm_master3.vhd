library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_avm_master3 is
end entity tb_avm_master3;

architecture simulation of tb_avm_master3 is

   constant C_DATA_SIZE     : integer := 32;
   constant C_ADDRESS_SIZE  : integer := 5;

   signal clk               : std_logic;
   signal rst               : std_logic;
   signal stop_test         : std_logic := '0';

   signal avm_has_started   : std_logic := '0';
   signal avm_start         : std_logic;
   signal avm_wait          : std_logic;

   signal avm_write         : std_logic;
   signal avm_read          : std_logic;
   signal avm_address       : std_logic_vector(C_ADDRESS_SIZE-1 downto 0);
   signal avm_writedata     : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal avm_byteenable    : std_logic_vector(C_DATA_SIZE/8-1 downto 0);
   signal avm_burstcount    : std_logic_vector(7 downto 0);
   signal avm_readdata      : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal avm_readdatavalid : std_logic;
   signal avm_waitrequest   : std_logic;

   constant C_CLK_PERIOD : time := 10 ns;

begin

   ---------------------------------------------------------
   -- Controller clock and reset
   ---------------------------------------------------------

   p_clk : process
   begin
      clk <= '1';
      wait for C_CLK_PERIOD/2;
      clk <= '0';
      wait for C_CLK_PERIOD/2;
      if stop_test = '1' then
         wait;
      end if;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 10*C_CLK_PERIOD;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;

   p_s_avm_start : process
   begin
      avm_start <= '0';
      wait until rst = '0';
      avm_start <= '1';
      wait until clk = '1';
      avm_start <= '0';
      wait;
   end process p_s_avm_start;

   p_has_started : process (clk)
   begin
      if rising_edge(clk) then
         if avm_start = '1' then
            avm_has_started <= '1';
         end if;
      end if;
   end process p_has_started;

   p_stop_test : process
   begin
      wait until avm_has_started = '1';
      wait until avm_wait = '0';
      wait until clk = '1';
      stop_test <= '1';
      wait;
   end process p_stop_test;


   ---------------------------------------------------------
   -- Instantiate Master
   ---------------------------------------------------------

   i_avm_master3 : entity work.avm_master3
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
      ); -- i_avm_master


   ---------------------------------------------------------
   -- Instantiate Slave
   ---------------------------------------------------------

   i_avm_memory_pause : entity work.avm_memory_pause
      generic map (
         G_REQ_PAUSE    => 0,
         G_RESP_PAUSE   => 0,
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
      ); -- i_avm_memory

end architecture simulation;

