library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This allows a Avalon Master to be connected to an AXI Slave

entity avalon_axi is
   generic (
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
   );
   port (
      clk_i                      : in  std_logic;
      rst_i                      : in  std_logic;

      -- Avalon Memory Map interface (slave)
      s_avm_write_i              : in  std_logic;
      s_avm_read_i               : in  std_logic;
      s_avm_address_i            : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      s_avm_writedata_i          : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_byteenable_i         : in  std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      s_avm_readdata_o           : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_readdatavalid_o      : out std_logic;
      s_avm_waitrequest_o        : out std_logic;
      s_avm_writeresponsevalid_o : out std_logic;
      s_avm_response_o           : out std_logic_vector(1 downto 0);

      -- AXI Lite interface (master)
      m_axil_awready_i           : in  std_logic;
      m_axil_awvalid_o           : out std_logic;
      m_axil_awaddr_o            : out std_logic_vector(G_ADDR_SIZE-1 downto 0);
      m_axil_awprot_o            : out std_logic_vector(2 downto 0);
      m_axil_awid_o              : out std_logic_vector(7 downto 0);
      m_axil_wready_i            : in  std_logic;
      m_axil_wvalid_o            : out std_logic;
      m_axil_wdata_o             : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_axil_wstrb_o             : out std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      m_axil_bready_o            : out std_logic;
      m_axil_bvalid_i            : in  std_logic;
      m_axil_bresp_i             : in  std_logic_vector(1 downto 0);
      m_axil_bid_i               : in  std_logic_vector(7 downto 0);
      m_axil_arready_i           : in  std_logic;
      m_axil_arvalid_o           : out std_logic;
      m_axil_araddr_o            : out std_logic_vector(G_ADDR_SIZE-1 downto 0);
      m_axil_arprot_o            : out std_logic_vector(2 downto 0);
      m_axil_arid_o              : out std_logic_vector(7 downto 0);
      m_axil_rready_o            : out std_logic;
      m_axil_rvalid_i            : in  std_logic;
      m_axil_rdata_i             : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_axil_rresp_i             : in  std_logic_vector(1 downto 0);
      m_axil_rid_i               : in  std_logic_vector(7 downto 0)
   );
end entity avalon_axi;

architecture synthesis of avalon_axi is

   signal alm_awvalid            : std_logic;
   signal alm_awaddr             : std_logic_vector(G_ADDR_SIZE-1 downto 0);
   signal alm_wvalid             : std_logic;
   signal alm_wvalid_d           : std_logic;
   signal alm_wdata              : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal alm_wstrb              : std_logic_vector(G_DATA_SIZE/8-1 downto 0);
   signal avs_response           : std_logic_vector(1 downto 0);
   signal avs_writeresponsevalid : std_logic;

   signal avs_readdata           : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal avs_readdatavalid      : std_logic;
   signal alm_arvalid            : std_logic;
   signal alm_araddr             : std_logic_vector(G_ADDR_SIZE-1 downto 0);

begin

   -- Handle write

   m_axil_awvalid_o <= alm_awvalid;
   m_axil_awaddr_o  <= alm_awaddr;
   m_axil_wvalid_o  <= alm_wvalid_d;
   m_axil_wdata_o   <= alm_wdata;
   m_axil_wstrb_o   <= alm_wstrb;
   m_axil_bready_o  <= '1';

   m_axil_awprot_o <= (others => '0');
   m_axil_awid_o   <= (others => '0');
   m_axil_arprot_o <= (others => '0');
   m_axil_arid_o   <= (others => '0');

   s_avm_response_o           <= avs_response;
   s_avm_writeresponsevalid_o <= avs_writeresponsevalid;


   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         alm_wvalid_d <= alm_wvalid;
         if m_axil_awready_i = '1' then
            alm_awvalid <= '0';
         end if;

         if m_axil_wready_i = '1' then
            alm_wvalid <= '0';
         end if;

         if m_axil_wready_i = '1' then
            alm_wvalid <= '0';
         end if;

         if s_avm_write_i = '1' then
            alm_awaddr  <= s_avm_address_i;
            alm_awvalid <= '1';

            alm_wdata  <= s_avm_writedata_i;
            alm_wvalid <= '1';
            alm_wstrb  <= s_avm_byteenable_i;
         end if;

         if m_axil_bvalid_i = '1' then
            avs_response <= m_axil_bresp_i;
            avs_writeresponsevalid <= '1';
         else
            avs_response <= (others => '0');
            avs_writeresponsevalid <= '0';
         end if;
      end if;
   end process p_write;


   -- Handle read

   s_avm_readdata_o      <= avs_readdata;
   s_avm_readdatavalid_o <= avs_readdatavalid;
   s_avm_waitrequest_o   <= '0';
   m_axil_rready_o       <= '1';
   m_axil_arvalid_o      <= alm_arvalid;
   m_axil_araddr_o       <= alm_araddr;

   p_r : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_axil_arready_i = '1' then
            alm_arvalid <= '0';
         end if;

         if s_avm_read_i = '1' then
            alm_araddr  <= s_avm_address_i;
            alm_arvalid <= '1';
         end if;
      end if;
   end process p_r;

   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         avs_readdatavalid <= '0';

         if m_axil_rvalid_i = '1' and m_axil_rready_o = '1' then
            avs_readdata      <= m_axil_rdata_i;
            avs_readdatavalid <= '1';
         end if;
      end if;
   end process p_read;

end architecture synthesis;

