library ieee;
use ieee.std_logic_1164.all;

entity axi_gcr is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- Encoding : 8 bit to 10 bit
      s_enc_ready_o : out std_logic;
      s_enc_valid_i : in  std_logic;
      s_enc_data_i  : in  std_logic_vector(7 downto 0);
      s_enc_sync_i  : in  std_logic;
      m_enc_ready_i : in  std_logic;
      m_enc_valid_o : out std_logic;
      m_enc_data_o  : out std_logic_vector(7 downto 0);

      -- Decoding : 10 bit to 8 bit
      s_dec_ready_o : out std_logic;
      s_dec_valid_i : in  std_logic;
      s_dec_data_i  : in  std_logic_vector(7 downto 0);
      m_dec_ready_i : in  std_logic;
      m_dec_valid_o : out std_logic;
      m_dec_data_o  : out std_logic_vector(7 downto 0);
      m_dec_sync_o  : out std_logic
   );
end entity axi_gcr;

architecture synthesis of axi_gcr is

   pure function enc_4_to_5(arg : std_logic_vector(3 downto 0)) return std_logic_vector is
   begin
      case arg is
         when "0000" => return "01010";
         when "0001" => return "11010";
         when "0010" => return "01001";
         when "0011" => return "11001";
         when "0100" => return "01110";
         when "0101" => return "11110";
         when "0110" => return "01101";
         when "0111" => return "11101";
         when "1000" => return "10010";
         when "1001" => return "10011";
         when "1010" => return "01011";
         when "1011" => return "11011";
         when "1100" => return "10110";
         when "1101" => return "10111";
         when "1110" => return "01111";
         when "1111" => return "10101";
         when others => return "11111";
      end case;
   end function enc_4_to_5;

   pure function dec_5_to_4(arg : std_logic_vector(4 downto 0)) return std_logic_vector is
   begin
      case arg is
         when "01010" => return "0000";
         when "11010" => return "0001";
         when "01001" => return "0010";
         when "11001" => return "0011";
         when "01110" => return "0100";
         when "11110" => return "0101";
         when "01101" => return "0110";
         when "11101" => return "0111";
         when "10010" => return "1000";
         when "10011" => return "1001";
         when "01011" => return "1010";
         when "11011" => return "1011";
         when "10110" => return "1100";
         when "10111" => return "1101";
         when "01111" => return "1110";
         when "10101" => return "1111";
         when others  => return "1111";
      end case;
   end function dec_5_to_4;

   signal dec_data : std_logic_vector(9 downto 0);

begin

   ---------------------------------------------------------
   -- Encoder - 8 bit to 10 bit
   ---------------------------------------------------------

   i_axi_shrinker : entity work.axi_shrinker
      generic map (
         G_INPUT_SIZE  => 10,
         G_OUTPUT_SIZE => 8
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_ready_o => s_enc_ready_o,
         s_valid_i => s_enc_valid_i,
         s_data_i  => enc_4_to_5(s_enc_data_i(7 downto 4)) & enc_4_to_5(s_enc_data_i(3 downto 0)),
         m_ready_i => m_enc_ready_i ,
         m_valid_o => m_enc_valid_o ,
         m_data_o  => m_enc_data_o
      ); -- i_axi_shrinker


   ---------------------------------------------------------
   -- Decoder - 10 bit to 8 bit
   ---------------------------------------------------------

   i_axi_expander : entity work.axi_expander
      generic map (
         G_INPUT_SIZE  => 8,
         G_OUTPUT_SIZE => 10
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         s_ready_o => s_dec_ready_o,
         s_valid_i => s_dec_valid_i,
         s_data_i  => s_dec_data_i,
         m_ready_i => m_dec_ready_i ,
         m_valid_o => m_dec_valid_o ,
         m_data_o  => dec_data
      ); -- i_axi_expander

   m_dec_data_o(7 downto 4) <= dec_5_to_4(dec_data(9 downto 5));
   m_dec_data_o(3 downto 0) <= dec_5_to_4(dec_data(4 downto 0));

end architecture synthesis;

