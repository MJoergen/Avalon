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

   signal enc_data_4_valid : natural range 0 to 8;
   signal enc_data_4       : std_logic_vector(7 downto 0);  -- Valid bits are from 7 down.
   signal enc_data_5_valid : natural range 0 to 8;
   signal enc_data_5       : std_logic_vector(7 downto 0);  -- Valid bits are from 0 up.

   signal dec_bit_cnt : natural range 0 to 4;
   signal dec_data    : std_logic_vector(4 downto 0);

   signal enc_concat_s : std_logic_vector(12 downto 0);

begin

   ---------------------------------------------------------
   -- Encoder - 8 bit to 10 bit
   ---------------------------------------------------------

   s_enc_ready_o <= '1' when enc_data_4_valid = 0 and rst_i = '0' else '0';

   p_enc_concat : process (all)
   begin
      enc_concat_s <= (others => '0');
      enc_concat_s(12 downto 13-enc_data_5_valid)                 <= enc_data_5(enc_data_5_valid-1 downto 0);
      enc_concat_s(12-enc_data_5_valid downto 8-enc_data_5_valid) <= enc_4_to_5(enc_data_4(7 downto 4));
   end process p_enc_concat;

   p_enc : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if m_enc_ready_i = '1' then
            m_enc_valid_o <= '0';
         end if;

         if enc_data_4_valid >= 4 then
            if enc_data_5_valid + 5 >= 8 then
               if m_enc_valid_o = '0' or m_enc_ready_i = '1' then
                  m_enc_data_o  <= enc_concat_s(12 downto 5);
                  m_enc_valid_o <= '1';
                  enc_data_5(7 downto 3) <= enc_concat_s(4 downto 0);
                  enc_data_5_valid <= enc_data_5_valid + 5 - 8;
                  enc_data_4_valid <= enc_data_4_valid - 4;
               end if;
            end if;

            if enc_data_5_valid + 5 <= 8 then
               enc_data_5(enc_data_5_valid+4 downto 5) <= enc_data_5(enc_data_5_valid-1 downto 0);
               enc_data_5(4 downto 0) <= enc_4_to_5(enc_data_4(7 downto 4));
               enc_data_4(7 downto 4) <= enc_data_4(3 downto 0);
               enc_data_5_valid <= enc_data_5_valid + 5;
               enc_data_4_valid <= enc_data_4_valid - 4;
            end if;
         else
            if enc_data_5_valid = 8 then
               m_enc_data_o     <= enc_data_5;
               m_enc_valid_o    <= '1';
               enc_data_5_valid <= 0;
            end if;
         end if;

         if s_enc_valid_i = '1' and s_enc_ready_o = '1' then
            assert enc_data_4_valid = 0;
            enc_data_4 <= s_enc_data_i;
            enc_data_4_valid <= 8;
         end if;

         if s_enc_sync_i = '1' then
            m_enc_valid_o <= '1';
         end if;

         if rst_i = '1' then
            enc_data_4_valid <= 0;
            enc_data_5_valid <= 0;
            m_enc_valid_o    <= '0';
         end if;
      end if;
   end process p_enc;


   ---------------------------------------------------------
   -- Decoder - 5 bit to 4 bit
   ---------------------------------------------------------

   s_dec_ready_o <= '1' when dec_bit_cnt = 0 and rst_i = '0' else '0';

   p_dec : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_dec_ready_i = '1' then
            m_dec_valid_o <= '0';
         end if;

         if rst_i = '1' then
            m_dec_sync_o  <= '0';
            m_dec_valid_o <= '0';
            dec_bit_cnt   <= 0;
         end if;
      end if;
   end process p_dec;

end architecture synthesis;

