library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_avm_cache is
   generic (
      G_CACHE_SIZE : natural := 8;
      G_REQ_PAUSE  : integer := 0;
      G_RESP_PAUSE : integer := 0
   );
end entity tb_avm_cache;

architecture simulation of tb_avm_cache is

   constant C_DATA_SIZE       : integer := 8;
   constant C_ADDRESS_SIZE    : integer := 4;

   signal clk                 : std_logic;
   signal rst                 : std_logic;
   signal stop_test           : std_logic := '0';

   signal s_avm_has_started   : std_logic := '0';
   signal s_avm_start         : std_logic;
   signal s_avm_wait          : std_logic;

   signal s_avm_write         : std_logic;
   signal s_avm_read          : std_logic;
   signal s_avm_address       : std_logic_vector(C_ADDRESS_SIZE-1 downto 0);
   signal s_avm_writedata     : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal s_avm_byteenable    : std_logic_vector(C_DATA_SIZE/8-1 downto 0);
   signal s_avm_burstcount    : std_logic_vector(7 downto 0);
   signal s_avm_readdata      : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal s_avm_readdatavalid : std_logic;
   signal s_avm_waitrequest   : std_logic;

   signal m_avm_write         : std_logic;
   signal m_avm_read          : std_logic;
   signal m_avm_address       : std_logic_vector(C_ADDRESS_SIZE-1 downto 0);
   signal m_avm_writedata     : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal m_avm_byteenable    : std_logic_vector(C_DATA_SIZE/8-1 downto 0);
   signal m_avm_burstcount    : std_logic_vector(7 downto 0);
   signal m_avm_readdata      : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal m_avm_readdatavalid : std_logic;
   signal m_avm_waitrequest   : std_logic;

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
      s_avm_start <= '0';
      wait until rst = '0';
      s_avm_start <= '1';
      wait until clk = '1';
      s_avm_start <= '0';
      wait;
   end process p_s_avm_start;

   p_has_started : process (clk)
   begin
      if rising_edge(clk) then
         if s_avm_start = '1' then
            s_avm_has_started <= '1';
         end if;
      end if;
   end process p_has_started;

   p_stop_test : process
   begin
      wait until s_avm_has_started = '1';
      wait until s_avm_wait = '0';
      wait until clk = '1';
      stop_test <= '1';
      wait;
   end process p_stop_test;


   ---------------------------------------------------------
   -- Instantiate Master
   ---------------------------------------------------------

   i_avm_master2 : entity work.avm_master2
      generic map (
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         start_i               => s_avm_start,
         wait_o                => s_avm_wait,
         write_burstcount_i    => X"01",
         read_burstcount_i     => X"01",
         m_avm_write_o         => s_avm_write,
         m_avm_read_o          => s_avm_read,
         m_avm_address_o       => s_avm_address,
         m_avm_writedata_o     => s_avm_writedata,
         m_avm_byteenable_o    => s_avm_byteenable,
         m_avm_burstcount_o    => s_avm_burstcount,
         m_avm_readdata_i      => s_avm_readdata,
         m_avm_readdatavalid_i => s_avm_readdatavalid,
         m_avm_waitrequest_i   => s_avm_waitrequest
      ); -- i_avm_master


   ---------------------------------------------------------
   -- Instantiate DUT
   ---------------------------------------------------------

   i_avm_cache : entity work.avm_cache
      generic map (
         G_CACHE_SIZE   => G_CACHE_SIZE,
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
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
      ); -- i_avm_cache

--   s_avm_readdata       <= m_avm_readdata;
--   s_avm_readdatavalid  <= m_avm_readdatavalid;
--   s_avm_waitrequest    <= m_avm_waitrequest;
--   m_avm_write          <= s_avm_write;
--   m_avm_read           <= s_avm_read;
--   m_avm_address        <= s_avm_address;
--   m_avm_writedata      <= s_avm_writedata;
--   m_avm_byteenable     <= s_avm_byteenable;
--   m_avm_burstcount     <= s_avm_burstcount;


   ---------------------------------------------------------
   -- Instantiate Slave
   ---------------------------------------------------------

   i_avm_memory_pause : entity work.avm_memory_pause
      generic map (
         G_REQ_PAUSE    => G_REQ_PAUSE,
         G_RESP_PAUSE   => G_RESP_PAUSE,
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i               => clk,
         rst_i               => rst,
         avm_write_i         => m_avm_write,
         avm_read_i          => m_avm_read,
         avm_address_i       => m_avm_address,
         avm_writedata_i     => m_avm_writedata,
         avm_byteenable_i    => m_avm_byteenable,
         avm_burstcount_i    => m_avm_burstcount,
         avm_readdata_o      => m_avm_readdata,
         avm_readdatavalid_o => m_avm_readdatavalid,
         avm_waitrequest_o   => m_avm_waitrequest
      ); -- i_avm_memory

end architecture simulation;

