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

   signal mem_data : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

   mem_proc : process (clk_i)
      -- This defines a type containing an array of bytes
      type     mem_type is array (0 to 2 ** G_ADDRESS_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
      variable mem_v : mem_type := (others => (others => '0'));
   begin
      if rising_edge(clk_i) then
         if avm_write_i = '1' and avm_waitrequest_i = '0' then

            for b in 0 to G_DATA_SIZE / 8 - 1 loop
               if avm_byteenable_i(b) = '1' then
                  mem_v(to_integer(avm_address_i))(8 * b + 7 downto 8 * b) := avm_writedata_i(8 * b + 7 downto 8 * b);
               end if;
            end loop;

         end if;

         if avm_read_i = '1' and avm_waitrequest_i = '0' then
            mem_data <= mem_v(to_integer(avm_address_i));
         end if;
      end if;
   end process mem_proc;

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

