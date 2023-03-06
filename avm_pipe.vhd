library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
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

  subtype  R_ADDRESS    is natural range G_ADDRESS_SIZE - 1 downto 0;
  subtype  R_WRITEDATA  is natural range R_ADDRESS'left    + G_DATA_SIZE     downto R_ADDRESS'left + 1;
  subtype  R_BYTEENABLE is natural range R_WRITEDATA'left  + G_DATA_SIZE / 8 downto R_WRITEDATA'left + 1;
  subtype  R_BURSTCOUNT is natural range R_BYTEENABLE'left + 8               downto R_BYTEENABLE'left + 1;
  constant R_WRITE   : natural := R_BURSTCOUNT'left + 1;
  constant C_WR_SIZE : natural := R_BURSTCOUNT'left + 2;

  signal   s_wr_ready : std_logic;
  signal   s_wr_valid : std_logic;
  signal   s_wr_data  : std_logic_vector(C_WR_SIZE - 1 downto 0);

  signal   m_wr_ready : std_logic;
  signal   m_wr_valid : std_logic;
  signal   m_wr_data  : std_logic_vector(C_WR_SIZE - 1 downto 0);

begin

  s_avm_waitrequest_o     <= not s_wr_ready;
  s_wr_data(R_ADDRESS)    <= s_avm_address_i;
  s_wr_data(R_WRITEDATA)  <= s_avm_writedata_i;
  s_wr_data(R_BYTEENABLE) <= s_avm_byteenable_i;
  s_wr_data(R_BURSTCOUNT) <= s_avm_burstcount_i;
  s_wr_data(R_WRITE)      <= s_avm_write_i;
  s_wr_valid              <= s_avm_write_i or s_avm_read_i;

  i_axi_skid_buffer_wr : entity work.axi_skid_buffer
    generic map (
      G_TDATA_SIZE => C_WR_SIZE
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      s_tready_o => s_wr_ready,
      s_tvalid_i => s_wr_valid,
      s_tdata_i  => s_wr_data,
      m_tready_i => m_wr_ready,
      m_tvalid_o => m_wr_valid,
      m_tdata_o  => m_wr_data
    ); -- i_axi_skid_buffer_wr

  m_wr_ready         <= not m_avm_waitrequest_i;
  m_avm_address_o    <= m_wr_data(R_ADDRESS);
  m_avm_writedata_o  <= m_wr_data(R_WRITEDATA);
  m_avm_byteenable_o <= m_wr_data(R_BYTEENABLE);
  m_avm_burstcount_o <= m_wr_data(R_BURSTCOUNT);
  m_avm_write_o      <= m_wr_valid and m_wr_data(R_WRITE);
  m_avm_read_o       <= m_wr_valid and not m_wr_data(R_WRITE);

  i_axi_skid_buffer_rd : entity work.axi_skid_buffer
    generic map (
      G_TDATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      s_tready_o => open,
      s_tvalid_i => m_avm_readdatavalid_i,
      s_tdata_i  => m_avm_readdata_i,
      m_tready_i => '1',
      m_tvalid_o => s_avm_readdatavalid_o,
      m_tdata_o  => s_avm_readdata_o
    ); -- i_axi_skid_buffer_rd

end architecture synthesis;

