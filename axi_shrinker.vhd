library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity axi_shrinker is
   generic (
      G_INPUT_SIZE  : natural;
      G_OUTPUT_SIZE : natural
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      s_ready_o : out std_logic;
      s_valid_i : in  std_logic;
      s_data_i  : in  std_logic_vector(G_INPUT_SIZE-1 downto 0);
      m_ready_i : in  std_logic;
      m_valid_o : out std_logic;
      m_data_o  : out std_logic_vector(G_OUTPUT_SIZE-1 downto 0)
   );
end entity axi_shrinker;

architecture synthesis of axi_shrinker is

   constant C_CONCAT_SIZE : natural := 2*G_INPUT_SIZE;

   signal concat_s : std_logic_vector(C_CONCAT_SIZE-1 downto 0);

   signal data_r   : std_logic_vector(G_INPUT_SIZE-1 downto 0);
   signal size_r   : natural range 0 to C_CONCAT_SIZE;

begin

   concat_s <= data_r & s_data_i;

   assert G_OUTPUT_SIZE < G_INPUT_SIZE;

   s_ready_o <= '0' when rst_i = '1' else
                '1' when size_r + G_INPUT_SIZE <= G_OUTPUT_SIZE else
                '1' when m_valid_o = '0' or m_ready_i = '1' else
                '0';

   p_shrinker : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         if s_valid_i = '1' and s_ready_o = '1' then
            data_r <= concat_s(G_INPUT_SIZE-1 downto 0);

            if size_r + G_INPUT_SIZE < G_OUTPUT_SIZE then
               size_r <= size_r + G_INPUT_SIZE;
            else
               m_data_o  <= concat_s(size_r+G_INPUT_SIZE-1 downto size_r+G_INPUT_SIZE-G_OUTPUT_SIZE);
               m_valid_o <= '1';
               size_r <= size_r + G_INPUT_SIZE - G_OUTPUT_SIZE;
            end if;
         else
            if size_r >= G_OUTPUT_SIZE then
               m_data_o  <= concat_s(size_r-1 downto size_r-G_OUTPUT_SIZE);
               m_valid_o <= '1';
               size_r <= size_r - G_OUTPUT_SIZE;
            end if;
         end if;

         if rst_i = '1' then
            size_r    <= 0;
            m_valid_o <= '0';
         end if;
      end if;
   end process p_shrinker;

end architecture synthesis;

