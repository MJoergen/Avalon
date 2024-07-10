library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity avm_verifier is
   generic (
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

   signal wr_en    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
   signal mem_data : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

   wr_en <= avm_byteenable_i when avm_write_i = '1' and avm_waitrequest_i = '0' else
            (others => '0');

   spram_be_inst : entity work.spram_be
      generic map (
         G_INIT_ZEROS   => true,
         G_ADDRESS_SIZE => G_ADDRESS_SIZE,
         G_DATA_SIZE    => G_DATA_SIZE
      )
      port map (
         clk_i     => clk_i,
         en_i      => '1',
         addr_i    => avm_address_i,
         wr_en_i   => wr_en,
         wr_data_i => avm_writedata_i,
         rd_data_o => mem_data
      ); -- spram_be_inst

   verifier_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if avm_readdatavalid_i = '1' then
            if avm_readdata_i /= mem_data then
               if count_error_o = 0 then
                  address_o   <= avm_address_i;
                  data_exp_o  <= mem_data;
                  data_read_o <= avm_readdata_i;
               end if;
               assert false
                  report "ERROR at Address " & to_hstring(avm_address_i) &
                         ". Expected " & to_hstring(mem_data) &
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

