library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi_gcr is
end entity tb_axi_gcr;

architecture simulation of tb_axi_gcr is

   constant C_CLK_PERIOD : time := 10 ns;

   signal clk         : std_logic;
   signal rst         : std_logic;
   signal s_enc_ready : std_logic;
   signal s_enc_valid : std_logic;
   signal s_enc_data  : std_logic_vector(7 downto 0);
   signal m_enc_ready : std_logic;
   signal m_enc_valid : std_logic;
   signal m_enc_data  : std_logic_vector(7 downto 0);
   signal s_dec_ready : std_logic;
   signal s_dec_valid : std_logic;
   signal s_dec_data  : std_logic_vector(7 downto 0);
   signal m_dec_ready : std_logic;
   signal m_dec_valid : std_logic;
   signal m_dec_data  : std_logic_vector(7 downto 0);

   signal resp_ready  : std_logic;
   signal resp_valid  : std_logic;
   signal resp_data   : std_logic_vector(7 downto 0);
   signal tb_error    : std_logic;

   signal lfsr_update_s  : std_logic;
   signal lfsr_output_s  : std_logic_vector(31 downto 0);
   signal lfsr_random_s  : std_logic_vector(31 downto 0);
   signal lfsr_reverse_s : std_logic_vector(31 downto 0);

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

      if tb_error = '1' then
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


   --------------------------------------
   -- Provide input stimuli
   -- TBD: Add some random pauses here
   --------------------------------------

   s_enc_valid   <= '1';
   s_enc_data    <= lfsr_random_s(7 downto 0);
   lfsr_update_s <= s_enc_valid and s_enc_ready;


   --------------------------------------
   -- Copy input to FIFO
   --------------------------------------

   i_axi_fifo_small : entity work.axi_fifo_small
      generic map (
         G_RAM_WIDTH => 8,
         G_RAM_DEPTH => 16
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_ready_o => open, -- Just ignore this, because the FIFO is plenty big enough
         s_valid_i => s_enc_valid and s_enc_ready,
         s_data_i  => s_enc_data,
         m_ready_i => resp_ready,
         m_valid_o => resp_valid,
         m_data_o  => resp_data
      ); -- i_axi_fifo_small


   --------------------------------------
   -- Connect encoder and decoder
   -- TBD: Add some random pauses here
   --------------------------------------

   s_dec_valid <= m_enc_valid;
   s_dec_data  <= m_enc_data;
   m_enc_ready <= s_dec_ready;


   --------------------------------------
   -- Check output results
   -- TBD: Add some random pauses here
   --------------------------------------

   m_dec_ready <= '1';
   resp_ready <= m_dec_valid;

   p_verify : process (clk)
   begin
      if rising_edge(clk) then
         if resp_valid = '1' then
            if m_dec_valid /= '1' then
               tb_error <= '1';
            end if;
            if m_dec_data /= resp_data then
               tb_error <= '1';
            end if;
         end if;

         if rst = '1' then
            tb_error <= '0';
         end if;
      end if;
   end process p_verify;


   ---------------------------------------------------------
   -- Instantiate DUT
   ---------------------------------------------------------

   i_axi_gcr : entity work.axi_gcr
      port map (
         clk_i         => clk,
         rst_i         => rst,
         s_enc_ready_o => s_enc_ready,
         s_enc_valid_i => s_enc_valid,
         s_enc_data_i  => s_enc_data,
         s_enc_sync_i  => '0',
         m_enc_ready_i => m_enc_ready,
         m_enc_valid_o => m_enc_valid,
         m_enc_data_o  => m_enc_data,
         s_dec_ready_o => s_dec_ready,
         s_dec_valid_i => s_dec_valid,
         s_dec_data_i  => s_dec_data,
         m_dec_ready_i => m_dec_ready,
         m_dec_valid_o => m_dec_valid,
         m_dec_data_o  => m_dec_data,
         m_dec_sync_o  => open
      ); -- i_axi_gcr


   --------------------------------------
   -- Instantiate randon number generator
   --------------------------------------

   i_lfsr : entity work.lfsr
      generic map (
         G_WIDTH => 32,
         G_TAPS  => X"0000000080000EA6" -- See https://users.ece.cmu.edu/~koopman/lfsr/32.txt
      )
      port map (
         clk_i      => clk,
         rst_i      => rst,
         update_i   => lfsr_update_s,
         load_i     => '0',
         load_val_i => (others => '1'),
         output_o   => lfsr_output_s
      ); -- i_lfsr

   p_reverse : process(all)
   begin
      for i in lfsr_output_s'low to lfsr_output_s'high loop
         lfsr_reverse_s(lfsr_output_s'high - i) <= lfsr_output_s(i);
      end loop;
   end process p_reverse;

   lfsr_random_s <= std_logic_vector(unsigned(lfsr_output_s) + unsigned(lfsr_reverse_s));

end architecture simulation;

