library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity tb_avm_arbit is
   generic (
      G_PREFER_SWAP : boolean;
      G_M0_START    : integer := 11;
      G_M1_START    : integer := 10;
      G_REQ_PAUSE   : integer := 0;
      G_RESP_PAUSE  : integer := 0
   );
end entity tb_avm_arbit;

architecture simulation of tb_avm_arbit is

   constant C_DATA_SIZE    : integer         := 16;
   constant C_ADDRESS_SIZE : integer         := 6;

   signal   clk     : std_logic              := '1';
   signal   rst     : std_logic              := '1';
   signal   running : std_logic              := '1';

   signal   m0_avm_has_started   : std_logic := '0';
   signal   m0_avm_start         : std_logic;
   signal   m0_avm_wait          : std_logic;
   signal   m0_avm_write         : std_logic;
   signal   m0_avm_read          : std_logic;
   signal   m0_avm_address       : std_logic_vector(C_ADDRESS_SIZE - 1 downto 0);
   signal   m0_avm_writedata     : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   m0_avm_byteenable    : std_logic_vector(C_DATA_SIZE / 8 - 1 downto 0);
   signal   m0_avm_burstcount    : std_logic_vector(7 downto 0);
   signal   m0_avm_readdata      : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   m0_avm_readdatavalid : std_logic;
   signal   m0_avm_waitrequest   : std_logic;

   signal   m1_avm_has_started   : std_logic := '0';
   signal   m1_avm_start         : std_logic;
   signal   m1_avm_wait          : std_logic;
   signal   m1_avm_write         : std_logic;
   signal   m1_avm_read          : std_logic;
   signal   m1_avm_address       : std_logic_vector(C_ADDRESS_SIZE - 1 downto 0);
   signal   m1_avm_writedata     : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   m1_avm_byteenable    : std_logic_vector(C_DATA_SIZE / 8 - 1 downto 0);
   signal   m1_avm_burstcount    : std_logic_vector(7 downto 0);
   signal   m1_avm_readdata      : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   m1_avm_readdatavalid : std_logic;
   signal   m1_avm_waitrequest   : std_logic;

   signal   s_avm_write         : std_logic;
   signal   s_avm_read          : std_logic;
   signal   s_avm_address       : std_logic_vector(C_ADDRESS_SIZE downto 0);
   signal   s_avm_writedata     : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   s_avm_byteenable    : std_logic_vector(C_DATA_SIZE / 8 - 1 downto 0);
   signal   s_avm_burstcount    : std_logic_vector(7 downto 0);
   signal   s_avm_readdata      : std_logic_vector(C_DATA_SIZE - 1 downto 0);
   signal   s_avm_readdatavalid : std_logic;
   signal   s_avm_waitrequest   : std_logic;

   constant C_CLK_PERIOD : time              := 10 ns;

begin

   ---------------------------------------------------------
   -- Controller clock and reset
   ---------------------------------------------------------

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   m0_avm_start_proc : process
   begin
      m0_avm_start <= '0';
      wait until rst = '0';

      for i in 0 to G_M0_START loop
         wait until clk = '1';
      end loop;

      m0_avm_start <= '1';
      wait until clk = '1';
      m0_avm_start <= '0';
      wait;
   end process m0_avm_start_proc;

   m1_avm_start_proc : process
   begin
      m1_avm_start <= '0';
      wait until rst = '0';

      for i in 0 to G_M1_START loop
         wait until clk = '1';
      end loop;

      m1_avm_start <= '1';
      wait until clk = '1';
      m1_avm_start <= '0';
      wait;
   end process m1_avm_start_proc;

   has_started_proc : process (clk)
   begin
      if rising_edge(clk) then
         if m0_avm_start = '1' then
            m0_avm_has_started <= '1';
         end if;
         if m1_avm_start = '1' then
            m1_avm_has_started <= '1';
         end if;
      end if;
   end process has_started_proc;

   stop_test_proc : process
   begin
      wait until m0_avm_has_started = '1' and m1_avm_has_started = '1';
      wait until m0_avm_wait = '0' and m1_avm_wait = '0';
      wait until clk = '1';
      running <= '0';
      wait;
   end process stop_test_proc;


   ---------------------------------------------------------
   -- Instantiate Master 0
   ---------------------------------------------------------

   avm_master_general0_inst : entity work.avm_master_general
      generic map (
         G_DATA_INIT    => X"CAFEBABEDEADBEEF",
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         start_i               => m0_avm_start,
         wait_o                => m0_avm_wait,
         m_avm_write_o         => m0_avm_write,
         m_avm_read_o          => m0_avm_read,
         m_avm_address_o       => m0_avm_address,
         m_avm_writedata_o     => m0_avm_writedata,
         m_avm_byteenable_o    => m0_avm_byteenable,
         m_avm_burstcount_o    => m0_avm_burstcount,
         m_avm_readdata_i      => m0_avm_readdata,
         m_avm_readdatavalid_i => m0_avm_readdatavalid,
         m_avm_waitrequest_i   => m0_avm_waitrequest
      ); -- avm_master_general0_inst


   ---------------------------------------------------------
   -- Instantiate Master 1
   ---------------------------------------------------------

   avm_master_general1_inst : entity work.avm_master_general
      generic map (
         G_DATA_INIT    => X"BABEDEADBEEFCAFE",
         G_ADDRESS_SIZE => C_ADDRESS_SIZE,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i                 => clk,
         rst_i                 => rst,
         start_i               => m1_avm_start,
         wait_o                => m1_avm_wait,
         m_avm_write_o         => m1_avm_write,
         m_avm_read_o          => m1_avm_read,
         m_avm_address_o       => m1_avm_address,
         m_avm_writedata_o     => m1_avm_writedata,
         m_avm_byteenable_o    => m1_avm_byteenable,
         m_avm_burstcount_o    => m1_avm_burstcount,
         m_avm_readdata_i      => m1_avm_readdata,
         m_avm_readdatavalid_i => m1_avm_readdatavalid,
         m_avm_waitrequest_i   => m1_avm_waitrequest
      ); -- avm_master_general1_inst


   ---------------------------------------------------------
   -- DUT
   ---------------------------------------------------------

   avm_arbit_inst : entity work.avm_arbit
      generic map (
         G_PREFER_SWAP  => G_PREFER_SWAP,
         G_ADDRESS_SIZE => C_ADDRESS_SIZE + 1,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i                  => clk,
         rst_i                  => rst,
         s0_avm_write_i         => m0_avm_write,
         s0_avm_read_i          => m0_avm_read,
         s0_avm_address_i       => "0" & m0_avm_address,
         s0_avm_writedata_i     => m0_avm_writedata,
         s0_avm_byteenable_i    => m0_avm_byteenable,
         s0_avm_burstcount_i    => m0_avm_burstcount,
         s0_avm_readdata_o      => m0_avm_readdata,
         s0_avm_readdatavalid_o => m0_avm_readdatavalid,
         s0_avm_waitrequest_o   => m0_avm_waitrequest,
         s1_avm_write_i         => m1_avm_write,
         s1_avm_read_i          => m1_avm_read,
         s1_avm_address_i       => "1" & m1_avm_address,
         s1_avm_writedata_i     => m1_avm_writedata,
         s1_avm_byteenable_i    => m1_avm_byteenable,
         s1_avm_burstcount_i    => m1_avm_burstcount,
         s1_avm_readdata_o      => m1_avm_readdata,
         s1_avm_readdatavalid_o => m1_avm_readdatavalid,
         s1_avm_waitrequest_o   => m1_avm_waitrequest,
         m_avm_write_o          => s_avm_write,
         m_avm_read_o           => s_avm_read,
         m_avm_address_o        => s_avm_address,
         m_avm_writedata_o      => s_avm_writedata,
         m_avm_byteenable_o     => s_avm_byteenable,
         m_avm_burstcount_o     => s_avm_burstcount,
         m_avm_readdata_i       => s_avm_readdata,
         m_avm_readdatavalid_i  => s_avm_readdatavalid,
         m_avm_waitrequest_i    => s_avm_waitrequest
      ); -- avm_arbit_inst


   ---------------------------------------------------------
   -- Instantiate Slave
   ---------------------------------------------------------

   avm_memory_pause_inst : entity work.avm_memory_pause
      generic map (
         G_REQ_PAUSE    => G_REQ_PAUSE,
         G_RESP_PAUSE   => G_RESP_PAUSE,
         G_ADDRESS_SIZE => C_ADDRESS_SIZE + 1,
         G_DATA_SIZE    => C_DATA_SIZE
      )
      port map (
         clk_i               => clk,
         rst_i               => rst,
         avm_write_i         => s_avm_write,
         avm_read_i          => s_avm_read,
         avm_address_i       => s_avm_address,
         avm_writedata_i     => s_avm_writedata,
         avm_byteenable_i    => s_avm_byteenable,
         avm_burstcount_i    => s_avm_burstcount,
         avm_readdata_o      => s_avm_readdata,
         avm_readdatavalid_o => s_avm_readdatavalid,
         avm_waitrequest_o   => s_avm_waitrequest
      ); -- avm_memory_pause_inst

end architecture simulation;

