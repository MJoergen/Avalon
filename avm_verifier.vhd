library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity avm_verifier is
   generic (
      G_INIT_ZEROS   : boolean;
      G_ADDRESS_SIZE : integer; -- Number of bits
      G_DATA_SIZE    : integer  -- Number of bits
   );
   port (
      clk_i               : in    std_logic;
      rst_i               : in    std_logic;
      avm_write_i         : in    std_logic;
      avm_read_i          : in    std_logic;
      avm_address_i       : in    std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      avm_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      avm_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
      avm_burstcount_i    : in    std_logic_vector(7 downto 0);
      avm_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      avm_readdatavalid_i : in    std_logic;
      avm_waitrequest_i   : in    std_logic;
      -- Debug output
      count_error_o       : out   std_logic_vector(31 downto 0);
      address_o           : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      data_exp_o          : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      data_read_o         : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
   );
end entity avm_verifier;

architecture synthesis of avm_verifier is

   signal wr_en : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);

   signal afs_s_ready : std_logic;
   signal afs_s_valid : std_logic;
   signal afs_s_data  : std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal afs_m_ready : std_logic;
   signal afs_m_valid : std_logic;
   signal afs_m_data  : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- spram_be is a Single Port RAM with byte-enable.
   -- This is used as a "shadow" copy of the Avalon Memory transactions.
   ---------------------------------------------------------------------------

   wr_en <= avm_byteenable_i when avm_write_i = '1' and avm_waitrequest_i = '0' else
            (others => '0');

   spram_be_inst : entity work.spram_be
      generic map (
         G_INIT_ZEROS   => G_INIT_ZEROS,
         G_ADDRESS_SIZE => G_ADDRESS_SIZE,
         G_DATA_SIZE    => G_DATA_SIZE
      )
      port map (
         clk_i     => clk_i,
         addr_i    => avm_address_i,
         wr_en_i   => wr_en,
         wr_data_i => avm_writedata_i,
         rd_en_i   => avm_read_i and not avm_waitrequest_i,
         rd_data_o => afs_s_data
      ); -- spram_be_inst


   ---------------------------------------------------------------------------
   -- The FIFO is used to store the results returned from the shadow memory.
   ---------------------------------------------------------------------------

   afs_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         assert not (afs_s_valid = '1' and afs_s_ready = '0'); -- Check FIFO not full
         afs_s_valid <= avm_read_i and not avm_waitrequest_i;
      end if;
   end process afs_proc;

   afs_m_ready <= avm_readdatavalid_i;

   axi_fifo_small_inst : entity work.axi_fifo_small
      generic map (
         G_RAM_WIDTH => G_DATA_SIZE,
         G_RAM_DEPTH => 64
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_valid_i => afs_s_valid,
         s_ready_o => afs_s_ready,
         s_data_i  => afs_s_data,
         m_valid_o => afs_m_valid,
         m_ready_i => afs_m_ready,
         m_data_o  => afs_m_data
      ); -- axi_fifo_small_inst


   ---------------------------------------------------------------------------
   -- Main verification process
   ---------------------------------------------------------------------------

   verifier_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if avm_readdatavalid_i = '1' then
            assert afs_m_valid = '1'; -- Check FIFO not empty
            if avm_readdata_i /= afs_m_data then
               if count_error_o = 0 then
                  address_o   <= avm_address_i;
                  data_exp_o  <= afs_m_data;
                  data_read_o <= avm_readdata_i;
               end if;
               assert false
                  report "ERROR at Address " & to_hstring(avm_address_i) &
                         ". Expected " & to_hstring(afs_m_data) &
                         ", read " & to_hstring(avm_readdata_i)
                  severity failure;
               count_error_o <= count_error_o + 1;
            end if;
         end if;
         if rst_i = '1' then
            count_error_o <= (others => '0');
         end if;
      end if;
   end process verifier_proc;

end architecture synthesis;

