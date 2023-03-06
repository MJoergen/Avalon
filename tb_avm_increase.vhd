library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_avm_increase is
end entity tb_avm_increase;

architecture simulation of tb_avm_increase is

   constant C_SLAVE_DATA_SIZE     : integer := 8;
   constant C_MASTER_DATA_SIZE    : integer := 16;
   constant C_SLAVE_ADDRESS_SIZE  : integer := 6;
   constant C_MASTER_ADDRESS_SIZE : integer := 5;

   signal clk                     : std_logic;
   signal rst                     : std_logic;
   signal tb_start                : std_logic;
   signal tb_wait                 : std_logic;
   signal stop_test               : std_logic := '0';

   signal sp_avm_start            : std_logic;
   signal sp_avm_wait             : std_logic;
   signal sp_avm_write_burstcount : std_logic_vector(7 downto 0);
   signal sp_avm_read_burstcount  : std_logic_vector(7 downto 0);

   signal sp_avm_write            : std_logic;
   signal sp_avm_read             : std_logic;
   signal sp_avm_address          : std_logic_vector(C_SLAVE_ADDRESS_SIZE-1 downto 0);
   signal sp_avm_writedata        : std_logic_vector(C_SLAVE_DATA_SIZE-1 downto 0);
   signal sp_avm_byteenable       : std_logic_vector(C_SLAVE_DATA_SIZE/8-1 downto 0);
   signal sp_avm_burstcount       : std_logic_vector(7 downto 0);
   signal sp_avm_readdata         : std_logic_vector(C_SLAVE_DATA_SIZE-1 downto 0);
   signal sp_avm_readdatavalid    : std_logic;
   signal sp_avm_waitrequest      : std_logic;

   signal s_avm_write             : std_logic;
   signal s_avm_read              : std_logic;
   signal s_avm_address           : std_logic_vector(C_SLAVE_ADDRESS_SIZE-1 downto 0);
   signal s_avm_writedata         : std_logic_vector(C_SLAVE_DATA_SIZE-1 downto 0);
   signal s_avm_byteenable        : std_logic_vector(C_SLAVE_DATA_SIZE/8-1 downto 0);
   signal s_avm_burstcount        : std_logic_vector(7 downto 0);
   signal s_avm_readdata          : std_logic_vector(C_SLAVE_DATA_SIZE-1 downto 0);
   signal s_avm_readdatavalid     : std_logic;
   signal s_avm_waitrequest       : std_logic;

   signal m_avm_write             : std_logic;
   signal m_avm_read              : std_logic;
   signal m_avm_address           : std_logic_vector(C_MASTER_ADDRESS_SIZE-1 downto 0);
   signal m_avm_writedata         : std_logic_vector(C_MASTER_DATA_SIZE-1 downto 0);
   signal m_avm_byteenable        : std_logic_vector(C_MASTER_DATA_SIZE/8-1 downto 0);
   signal m_avm_burstcount        : std_logic_vector(7 downto 0);
   signal m_avm_readdata          : std_logic_vector(C_MASTER_DATA_SIZE-1 downto 0);
   signal m_avm_readdatavalid     : std_logic;
   signal m_avm_waitrequest       : std_logic;

   signal mp_avm_write            : std_logic;
   signal mp_avm_read             : std_logic;
   signal mp_avm_address          : std_logic_vector(C_MASTER_ADDRESS_SIZE-1 downto 0);
   signal mp_avm_writedata        : std_logic_vector(C_MASTER_DATA_SIZE-1 downto 0);
   signal mp_avm_byteenable       : std_logic_vector(C_MASTER_DATA_SIZE/8-1 downto 0);
   signal mp_avm_burstcount       : std_logic_vector(7 downto 0);
   signal mp_avm_readdata         : std_logic_vector(C_MASTER_DATA_SIZE-1 downto 0);
   signal mp_avm_readdatavalid    : std_logic;
   signal mp_avm_waitrequest      : std_logic;

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


   p_start : process
   begin
      tb_start <= '0';
      wait until rst = '0';
      wait until clk = '1';
      tb_start <= '1';
      wait until clk = '1';
      tb_start <= '0';
      wait;
   end process p_start;

   p_stop_test : process
   begin
      wait until tb_start = '1';
      wait until tb_wait = '0';
      wait until clk = '1';
      stop_test <= '1';
      wait;
   end process p_stop_test;



   ---------------------------------------------------------
   -- Instantiate burst controller
   ---------------------------------------------------------

   i_burst_ctrl : entity work.burst_ctrl
      port map (
         clk_i              => clk,
         rst_i              => rst,
         start_i            => tb_start,
         wait_o             => tb_wait,
         start_o            => sp_avm_start,
         wait_i             => sp_avm_wait,
         write_burstcount_o => sp_avm_write_burstcount,
         read_burstcount_o  => sp_avm_read_burstcount
      ); -- i_burst_ctrl


   ---------------------------------------------------------
   -- Instantiate Master
   ---------------------------------------------------------

   i_avm_master : entity work.avm_master
      generic map (
         G_DATA_INIT    => X"B00BBABEDEAFCAFE",
         G_ADDRESS_SIZE => C_SLAVE_ADDRESS_SIZE,
         G_DATA_SIZE    => C_SLAVE_DATA_SIZE
      )
      port map (
         clk_i               => clk,
         rst_i               => rst,
         start_i             => sp_avm_start,
         wait_o              => sp_avm_wait,
         write_burstcount_i  => sp_avm_write_burstcount,
         read_burstcount_i   => sp_avm_read_burstcount,
         avm_write_o         => sp_avm_write,
         avm_read_o          => sp_avm_read,
         avm_address_o       => sp_avm_address,
         avm_writedata_o     => sp_avm_writedata,
         avm_byteenable_o    => sp_avm_byteenable,
         avm_burstcount_o    => sp_avm_burstcount,
         avm_readdata_i      => sp_avm_readdata,
         avm_readdatavalid_i => sp_avm_readdatavalid,
         avm_waitrequest_i   => sp_avm_waitrequest
      ); -- i_avm_master


   ---------------------------------------------------------
   -- Generate pauses in master trafic
   ---------------------------------------------------------

   i_avm_pause_master : entity work.avm_pause
      generic map (
         G_REQ_PAUSE    => 0,
         G_RESP_PAUSE   => 0,
         G_ADDRESS_SIZE => C_SLAVE_ADDRESS_SIZE,
         G_DATA_SIZE    => C_SLAVE_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         s_avm_write_i         => sp_avm_write,
         s_avm_read_i          => sp_avm_read,
         s_avm_address_i       => sp_avm_address,
         s_avm_writedata_i     => sp_avm_writedata,
         s_avm_byteenable_i    => sp_avm_byteenable,
         s_avm_burstcount_i    => sp_avm_burstcount,
         s_avm_readdata_o      => sp_avm_readdata,
         s_avm_readdatavalid_o => sp_avm_readdatavalid,
         s_avm_waitrequest_o   => sp_avm_waitrequest,
         m_avm_write_o         => s_avm_write,
         m_avm_read_o          => s_avm_read,
         m_avm_address_o       => s_avm_address,
         m_avm_writedata_o     => s_avm_writedata,
         m_avm_byteenable_o    => s_avm_byteenable,
         m_avm_burstcount_o    => s_avm_burstcount,
         m_avm_readdata_i      => s_avm_readdata,
         m_avm_readdatavalid_i => s_avm_readdatavalid,
         m_avm_waitrequest_i   => s_avm_waitrequest
      ); -- i_avm_pause_master


   ---------------------------------------------------------
   -- Instantiate DUT
   ---------------------------------------------------------

   i_avm_increase : entity work.avm_increase
      generic map (
         G_SLAVE_ADDRESS_SIZE  => C_SLAVE_ADDRESS_SIZE,
         G_MASTER_ADDRESS_SIZE => C_MASTER_ADDRESS_SIZE,
         G_SLAVE_DATA_SIZE     => C_SLAVE_DATA_SIZE,
         G_MASTER_DATA_SIZE    => C_MASTER_DATA_SIZE
      )
      port map (
         clk_i                  => clk,
         rst_i                  => rst,
         s_avm_write_i          => s_avm_write,
         s_avm_read_i           => s_avm_read,
         s_avm_address_i        => s_avm_address,
         s_avm_writedata_i      => s_avm_writedata,
         s_avm_byteenable_i     => s_avm_byteenable,
         s_avm_burstcount_i     => s_avm_burstcount,
         s_avm_readdata_o       => s_avm_readdata,
         s_avm_readdatavalid_o  => s_avm_readdatavalid,
         s_avm_waitrequest_o    => s_avm_waitrequest,
         m_avm_write_o          => m_avm_write,
         m_avm_read_o           => m_avm_read,
         m_avm_address_o        => m_avm_address,
         m_avm_writedata_o      => m_avm_writedata,
         m_avm_byteenable_o     => m_avm_byteenable,
         m_avm_burstcount_o     => m_avm_burstcount,
         m_avm_readdata_i       => m_avm_readdata,
         m_avm_readdatavalid_i  => m_avm_readdatavalid,
         m_avm_waitrequest_i    => m_avm_waitrequest
      ); -- i_avm_increase


   ---------------------------------------------------------
   -- Generate pauses in slave reception
   ---------------------------------------------------------

   i_avm_pause_slave : entity work.avm_pause
      generic map (
         G_REQ_PAUSE    => 0,
         G_RESP_PAUSE   => 0,
         G_ADDRESS_SIZE => C_MASTER_ADDRESS_SIZE,
         G_DATA_SIZE    => C_MASTER_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         s_avm_write_i         => m_avm_write,
         s_avm_read_i          => m_avm_read,
         s_avm_address_i       => m_avm_address,
         s_avm_writedata_i     => m_avm_writedata,
         s_avm_byteenable_i    => m_avm_byteenable,
         s_avm_burstcount_i    => m_avm_burstcount,
         s_avm_readdata_o      => m_avm_readdata,
         s_avm_readdatavalid_o => m_avm_readdatavalid,
         s_avm_waitrequest_o   => m_avm_waitrequest,
         m_avm_write_o         => mp_avm_write,
         m_avm_read_o          => mp_avm_read,
         m_avm_address_o       => mp_avm_address,
         m_avm_writedata_o     => mp_avm_writedata,
         m_avm_byteenable_o    => mp_avm_byteenable,
         m_avm_burstcount_o    => mp_avm_burstcount,
         m_avm_readdata_i      => mp_avm_readdata,
         m_avm_readdatavalid_i => mp_avm_readdatavalid,
         m_avm_waitrequest_i   => mp_avm_waitrequest
      ); -- i_avm_pause_slave


   ---------------------------------------------------------
   -- Instantiate Slave
   ---------------------------------------------------------

   i_avm_memory : entity work.avm_memory
      generic map (
         G_ADDRESS_SIZE => C_MASTER_ADDRESS_SIZE,
         G_DATA_SIZE    => C_MASTER_DATA_SIZE
      )
      port map (
         clk_i               => clk,
         rst_i               => rst,
         avm_write_i         => mp_avm_write,
         avm_read_i          => mp_avm_read,
         avm_address_i       => mp_avm_address,
         avm_writedata_i     => mp_avm_writedata,
         avm_byteenable_i    => mp_avm_byteenable,
         avm_burstcount_i    => mp_avm_burstcount,
         avm_readdata_o      => mp_avm_readdata,
         avm_readdatavalid_o => mp_avm_readdatavalid,
         avm_waitrequest_o   => mp_avm_waitrequest
      ); -- i_avm_memory

end architecture simulation;

