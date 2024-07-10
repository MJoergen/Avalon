library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity avm_pipe is
   generic (
      G_ADDRESS_SIZE : integer; -- Number of bits
      G_DATA_SIZE    : integer  -- Number of bits
   );
   port (
      clk_i                 : in    std_logic;
      rst_i                 : in    std_logic;
      s_avm_waitrequest_o   : out   std_logic;
      s_avm_write_i         : in    std_logic;
      s_avm_read_i          : in    std_logic;
      s_avm_address_i       : in    std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      s_avm_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      s_avm_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
      s_avm_burstcount_i    : in    std_logic_vector(7 downto 0);
      s_avm_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      s_avm_readdatavalid_o : out   std_logic;
      m_avm_waitrequest_i   : in    std_logic;
      m_avm_write_o         : out   std_logic;
      m_avm_read_o          : out   std_logic;
      m_avm_address_o       : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      m_avm_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
      m_avm_burstcount_o    : out   std_logic_vector(7 downto 0);
      m_avm_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_readdatavalid_i : in    std_logic
   );
end entity avm_pipe;

architecture synthesis of avm_pipe is

begin

   s_avm_waitrequest_o <= (m_avm_write_o or m_avm_read_o) and m_avm_waitrequest_i;

   pipe_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         s_avm_readdata_o      <= m_avm_readdata_i;
         s_avm_readdatavalid_o <= m_avm_readdatavalid_i;

         if m_avm_waitrequest_i = '0' then
            m_avm_write_o <= '0';
            m_avm_read_o  <= '0';
         end if;

         if s_avm_waitrequest_o = '0' then
            m_avm_write_o      <= s_avm_write_i;
            m_avm_read_o       <= s_avm_read_i;
            m_avm_address_o    <= s_avm_address_i;
            m_avm_writedata_o  <= s_avm_writedata_i;
            m_avm_byteenable_o <= s_avm_byteenable_i;
            m_avm_burstcount_o <= s_avm_burstcount_i;
         end if;

         if rst_i = '1' then
            m_avm_write_o <= '0';
            m_avm_read_o  <= '0';
         end if;
      end if;
   end process pipe_proc;

end architecture synthesis;

