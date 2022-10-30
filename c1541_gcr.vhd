library ieee;
use ieee.std_logic_1164.all;

entity c1541_gcr is
   port (
      clk          : in  std_logic;
      ce           : in  std_logic;
      dout         : out std_logic_vector(7 downto 0);
      din          : in  std_logic_vector(7 downto 0);
      mode         : in  std_logic;
      mtr          : in  std_logic;
      freq         : in  std_logic_vector(1 downto 0);
      sync_n       : out std_logic;
      byte_n       : out std_logic;
      track        : in  std_logic_vector(5 downto 0);
      busy         : in  std_logic;
      we           : out std_logic;
      sd_clk       : in  std_logic;
      sd_lba       : in  std_logic_vector(31 downto 0);
      sd_buff_addr : in  std_logic_vector(12 downto 0);
      sd_buff_din  : out std_logic_vector(7 downto 0);
      sd_buff_wr   : in  std_logic
   );
end entity c1541_gcr;

architecture synthesis of c1541_gcr is

   signal rst         : std_logic;
   signal s_enc_ready : std_logic;
   signal s_enc_valid : std_logic;
   signal s_enc_data  : std_logic_vector(7 downto 0);
   signal s_enc_sync  : std_logic;
   signal m_enc_ready : std_logic;
   signal m_enc_valid : std_logic;
   signal m_enc_data  : std_logic_vector(7 downto 0);
   signal s_dec_ready : std_logic;
   signal s_dec_valid : std_logic;
   signal s_dec_data  : std_logic_vector(7 downto 0);
   signal m_dec_ready : std_logic;
   signal m_dec_valid : std_logic;
   signal m_dec_data  : std_logic_vector(7 downto 0);
   signal m_dec_sync  : std_logic;

begin

   i_axi_gcr : entity work.axi_gcr
      port map (
         clk_i         => clk,
         rst_i         => rst,
         s_enc_ready_o => s_enc_ready,
         s_enc_valid_i => s_enc_valid,
         s_enc_data_i  => s_enc_data,
         s_enc_sync_i  => s_enc_sync,
         m_enc_ready_i => m_enc_ready,
         m_enc_valid_o => m_enc_valid,
         m_enc_data_o  => m_enc_data,
         s_dec_ready_o => s_dec_ready,
         s_dec_valid_i => s_dec_valid,
         s_dec_data_i  => s_dec_data,
         m_dec_ready_i => m_dec_ready,
         m_dec_valid_o => m_dec_valid,
         m_dec_data_o  => m_dec_data,
         m_dec_sync_o  => m_dec_sync
      ); -- i_axi_gcr

end architecture synthesis;

