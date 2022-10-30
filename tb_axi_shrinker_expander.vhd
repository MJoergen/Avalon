library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi_shrinker_expander is
end entity tb_axi_shrinker_expander;

architecture simulation of tb_axi_shrinker_expander is

   constant C_CLK_PERIOD : time := 10 ns;

   constant C_STIM_SIZE   : natural := 12;
   constant C_SHRINK_SIZE : natural := 8;

   signal clk          : std_logic;
   signal rst          : std_logic;
   signal stim_ready   : std_logic;
   signal stim_valid   : std_logic;
   signal stim_data    : std_logic_vector(C_STIM_SIZE-1 downto 0);
   signal shrink_ready : std_logic;
   signal shrink_valid : std_logic;
   signal shrink_data  : std_logic_vector(C_SHRINK_SIZE-1 downto 0);
   signal expand_ready : std_logic;
   signal expand_valid : std_logic;
   signal expand_data  : std_logic_vector(C_STIM_SIZE-1 downto 0);

   signal resp_ready  : std_logic;
   signal resp_valid  : std_logic;
   signal resp_data   : std_logic_vector(C_STIM_SIZE-1 downto 0);
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
         report "Test ERROR";
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

   stim_valid   <= '1';
   stim_data    <= lfsr_random_s(C_STIM_SIZE-1 downto 0);
   lfsr_update_s <= stim_valid and stim_ready;


   --------------------------------------
   -- Copy input to FIFO
   --------------------------------------

   i_axi_fifo_small : entity work.axi_fifo_small
      generic map (
         G_RAM_WIDTH => C_STIM_SIZE,
         G_RAM_DEPTH => 16
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_ready_o => open, -- Just ignore this, because the FIFO is plenty big enough
         s_valid_i => stim_valid and stim_ready,
         s_data_i  => stim_data,
         m_ready_i => resp_ready,
         m_valid_o => resp_valid,
         m_data_o  => resp_data
      ); -- i_axi_fifo_small


   --------------------------------------
   -- Check output results
   -- TBD: Add some random pauses here
   --------------------------------------

   expand_ready <= '1';
   resp_ready <= expand_valid;

   p_verify : process (clk)
   begin
      if rising_edge(clk) then
         if resp_valid = '1' and resp_ready = '1' then
            if expand_data /= resp_data then
               tb_error <= '1';
            end if;
         end if;

         if rst = '1' then
            tb_error <= '0';
         end if;
      end if;
   end process p_verify;


   ---------------------------------------------------------
   -- Instantiate Shrinker
   ---------------------------------------------------------

   i_axi_shrinker : entity work.axi_shrinker
      generic map (
         G_INPUT_SIZE  => C_STIM_SIZE,
         G_OUTPUT_SIZE => C_SHRINK_SIZE
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_ready_o => stim_ready,
         s_valid_i => stim_valid,
         s_data_i  => stim_data,
         m_ready_i => shrink_ready,
         m_valid_o => shrink_valid,
         m_data_o  => shrink_data
      ); -- i_axi_shrinker


   ---------------------------------------------------------
   -- Instantiate Expander
   ---------------------------------------------------------

   i_axi_expander : entity work.axi_expander
      generic map (
         G_INPUT_SIZE  => C_SHRINK_SIZE,
         G_OUTPUT_SIZE => C_STIM_SIZE
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_ready_o => shrink_ready,
         s_valid_i => shrink_valid,
         s_data_i  => shrink_data,
         m_ready_i => expand_ready,
         m_valid_o => expand_valid,
         m_data_o  => expand_data
      ); -- i_axi_expander


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

