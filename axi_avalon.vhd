library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This allows a Avalon Slave to be connected to an AXI Master

entity axi_avalon is
   generic (
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
   );
   port (
      clk_i                      : in  std_logic;
      rst_i                      : in  std_logic;

      -- AXI Lite interface (slave)
      s_axil_awready_o           : out std_logic;
      s_axil_awvalid_i           : in  std_logic;
      s_axil_awaddr_i            : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      s_axil_awprot_i            : in  std_logic_vector(2 downto 0);
      s_axil_awid_i              : in  std_logic_vector(7 downto 0);
      s_axil_wready_o            : out std_logic;
      s_axil_wvalid_i            : in  std_logic;
      s_axil_wdata_i             : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_axil_wstrb_i             : in  std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      s_axil_bready_i            : in  std_logic;
      s_axil_bvalid_o            : out std_logic;
      s_axil_bresp_o             : out std_logic_vector(1 downto 0);
      s_axil_bid_o               : out std_logic_vector(7 downto 0);
      s_axil_arready_o           : out std_logic;
      s_axil_arvalid_i           : in  std_logic;
      s_axil_araddr_i            : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      s_axil_arprot_i            : in  std_logic_vector(2 downto 0);
      s_axil_arid_i              : in  std_logic_vector(7 downto 0);
      s_axil_rready_i            : in  std_logic;
      s_axil_rvalid_o            : out std_logic;
      s_axil_rdata_o             : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_axil_rresp_o             : out std_logic_vector(1 downto 0);
      s_axil_rid_o               : out std_logic_vector(7 downto 0);

      -- Avalon Memory Map interface (master)
      m_avm_write_o              : out std_logic;
      m_avm_read_o               : out std_logic;
      m_avm_address_o            : out std_logic_vector(G_ADDR_SIZE-1 downto 0);
      m_avm_writedata_o          : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_byteenable_o         : out std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      m_avm_readdata_i           : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_readdatavalid_i      : in  std_logic;
      m_avm_waitrequest_i        : in  std_logic;
      m_avm_writeresponsevalid_i : in  std_logic;
      m_avm_response_i           : in  std_logic_vector(1 downto 0)
   );
end entity axi_avalon;

architecture synthesis of axi_avalon is

   signal avm_read_address  : std_logic_vector(G_ADDR_SIZE-1 downto 0);
   signal avm_write_address : std_logic_vector(G_ADDR_SIZE-1 downto 0);
   signal avm_byteenable    : std_logic_vector(G_DATA_SIZE/8-1 downto 0);
   signal avm_read          : std_logic;
   signal avm_write         : std_logic;
   signal avm_writedata     : std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal aw_stored         : std_logic;
   signal w_stored          : std_logic;

   signal s_axil_rvalid     : std_logic;
   signal s_axil_rdata      : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal s_axil_rresp      : std_logic_vector(1 downto 0);

begin

   -- Handle write

   m_avm_address_o    <= avm_write_address when avm_write = '1' else avm_read_address;
   m_avm_byteenable_o <= avm_byteenable;
   m_avm_read_o       <= avm_read;
   m_avm_write_o      <= avm_write;
   m_avm_writedata_o  <= avm_writedata;

   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         avm_read <= '0';

         if s_axil_arvalid_i = '1' and s_axil_arready_o = '1' then
            avm_read_address <= s_axil_araddr_i;
            s_axil_rid_o     <= s_axil_arid_i;
            avm_read         <= '1';
         end if;
      end if;
   end process p_read;

   s_axil_awready_o <= not aw_stored;
   s_axil_wready_o  <= not w_stored;
   avm_write        <= aw_stored and w_stored and not avm_read;

   p_stored : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_axil_awvalid_i = '1' and s_axil_awready_o = '1' then
            avm_write_address <= s_axil_awaddr_i;
            s_axil_bid_o      <= s_axil_awid_i;
            aw_stored         <= '1';
         end if;

         if s_axil_wvalid_i = '1' and s_axil_wready_o = '1' then
            avm_writedata  <= s_axil_wdata_i;
            avm_byteenable <= s_axil_wstrb_i;
            w_stored       <= '1';
         end if;

         if avm_write = '1' or rst_i = '1' then
            aw_stored <= '0';
            w_stored  <= '0';
         end if;
      end if;
   end process p_stored;

   p_b : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_axil_bready_i = '1' then
            s_axil_bvalid_o <= '0';
         end if;

         if m_avm_writeresponsevalid_i = '1' then
            s_axil_bvalid_o <= '1';
            s_axil_bresp_o  <= m_avm_response_i;
         end if;
      end if;
   end process p_b;


   -- Handle read response

   s_axil_rvalid_o  <= s_axil_rvalid;
   s_axil_rdata_o   <= s_axil_rdata;
   s_axil_rresp_o   <= s_axil_rresp;
   s_axil_arready_o <= '1';

   p_r : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_axil_rready_i = '1' then
            s_axil_rvalid <= '0';
         end if;

         if m_avm_readdatavalid_i = '1' then
            s_axil_rdata <= m_avm_readdata_i;
            s_axil_rvalid <= '1';
         end if;
      end if;
   end process p_r;

end architecture synthesis;

