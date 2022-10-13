library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_avm_cache2 is
   generic (
      G_CACHE_SIZE : natural := 8;
      G_REQ_PAUSE  : integer;
      G_RESP_PAUSE : integer
   );
end entity tb_avm_cache2;

architecture simulation of tb_avm_cache2 is

   constant C_DATA_SIZE     : integer := 8;
   constant C_ADDRESS_SIZE  : integer := 4;

   signal clk               : std_logic;
   signal rst               : std_logic;
   signal stop_test         : std_logic := '0';

   signal avm_write         : std_logic;
   signal avm_read          : std_logic;
   signal avm_address       : std_logic_vector(C_ADDRESS_SIZE-1 downto 0);
   signal avm_writedata     : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal avm_byteenable    : std_logic_vector(C_DATA_SIZE/8-1 downto 0);
   signal avm_burstcount    : std_logic_vector(7 downto 0);
   signal avm_readdata      : std_logic_vector(C_DATA_SIZE-1 downto 0);
   signal avm_readdatavalid : std_logic;
   signal avm_waitrequest   : std_logic;

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
   -- Main test process
   ---------------------------------------------------------

   p_test : process is
      procedure write(addr : std_logic_vector(C_ADDRESS_SIZE-1 downto 0); data : std_logic_vector(C_DATA_SIZE-1 downto 0)) is
      begin
         avm_write      <= '1';
         avm_read       <= '0';
         avm_address    <= addr;
         avm_writedata  <= data;
         avm_byteenable <= (others => '1');
         avm_burstcount <= X"01";
         wait until clk = '1';

         while avm_write = '1' and avm_waitrequest = '1' loop
            wait until clk = '1';
         end loop;

         avm_write      <= '0';
         avm_read       <= '0';
         avm_address    <= (others => '0');
         avm_writedata  <= (others => '0');
         avm_byteenable <= (others => '0');
         avm_burstcount <= (others => '0');
      end procedure write;

      procedure read(addr : std_logic_vector(C_ADDRESS_SIZE-1 downto 0); data : out std_logic_vector(C_DATA_SIZE-1 downto 0)) is
      begin
         avm_write      <= '0';
         avm_read       <= '1';
         avm_address    <= addr;
         avm_burstcount <= X"01";
         wait until clk = '1';

         while avm_read = '1' and avm_waitrequest = '1' loop
            wait until clk = '1';
         end loop;

         avm_write      <= '0';
         avm_read       <= '0';
         avm_address    <= (others => '0');
         avm_burstcount <= (others => '0');

         while avm_readdatavalid = '0' loop
            wait until clk = '1';
         end loop;

         data := avm_readdata;
      end procedure read;

      procedure verify(addr : std_logic_vector(C_ADDRESS_SIZE-1 downto 0); exp_data : std_logic_vector(C_DATA_SIZE-1 downto 0)) is
         variable read_data : std_logic_vector(C_DATA_SIZE-1 downto 0);
      begin
         read(addr, read_data);
         assert read_data = exp_data
            report "From address " & to_hstring(addr) & " read 0x" & to_hstring(read_data) & ", but expected " & to_hstring(exp_data)
               severity failure;
      end procedure verify;

   begin -- p_test
      report "Test started!";

      avm_write <= '0';
      avm_read  <= '0';
      wait for 200 ns;
      wait until clk = '1';
      write(X"0", X"11");
      write(X"1", X"22");
      write(X"2", X"33");
      write(X"3", X"44");
      write(X"4", X"55");
      write(X"5", X"66");
      write(X"6", X"77");
      write(X"7", X"88");
      write(X"8", X"99");

      verify(X"0", X"11");
      write(X"5", X"AA");
      verify(X"1", X"22");
      verify(X"2", X"33");
      verify(X"3", X"44");
      verify(X"4", X"55");
      verify(X"5", X"AA");
      verify(X"6", X"77");
      verify(X"7", X"88");
      verify(X"8", X"99");

      wait for 100 ns;
      wait until clk = '1';

      report "Test finished!";
      stop_test <= '1';
      wait;
   end process p_test;


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
         s_avm_write_i          => avm_write,
         s_avm_read_i           => avm_read,
         s_avm_address_i        => avm_address,
         s_avm_writedata_i      => avm_writedata,
         s_avm_byteenable_i     => avm_byteenable,
         s_avm_burstcount_i     => avm_burstcount,
         s_avm_readdata_o       => avm_readdata,
         s_avm_readdatavalid_o  => avm_readdatavalid,
         s_avm_waitrequest_o    => avm_waitrequest,
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

-- Skip the cache:
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

