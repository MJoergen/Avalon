library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_avalon_axi is
end entity tb_avalon_axi;

architecture simulation of tb_avalon_axi is

   -- Clock and reset
   signal clk     : std_logic;
   signal rst     : std_logic;

   constant HALF_PERIOD : natural := 5; -- 100 MHz

   -- Avalon Memory Map
   signal avmm_address            : std_logic_vector(19 downto 0);
   signal avmm_byteenable         : std_logic_vector(7 downto 0);
   signal avmm_read               : std_logic;
   signal avmm_readdata           : std_logic_vector(63 downto 0);
   signal avmm_readdatavalid      : std_logic;
   signal avmm_waitrequest        : std_logic;
   signal avmm_write              : std_logic;
   signal avmm_writedata          : std_logic_vector(63 downto 0);
   signal avmm_response           : std_logic_vector(1 downto 0);
   signal avmm_writeresponsevalid : std_logic;

   -- AXI-Lite
   signal axil_awready            : std_logic;
   signal axil_awvalid            : std_logic;
   signal axil_awaddr             : std_logic_vector(19 downto 0);
   signal axil_awprot             : std_logic_vector(2 downto 0);
   signal axil_awid               : std_logic_vector(7 downto 0);
   signal axil_wready             : std_logic;
   signal axil_wvalid             : std_logic;
   signal axil_wdata              : std_logic_vector(63 downto 0);
   signal axil_wstrb              : std_logic_vector(7 downto 0);
   signal axil_bready             : std_logic;
   signal axil_bvalid             : std_logic;
   signal axil_bresp              : std_logic_vector(1 downto 0);
   signal axil_bid                : std_logic_vector(7 downto 0);
   signal axil_arready            : std_logic;
   signal axil_arvalid            : std_logic;
   signal axil_araddr             : std_logic_vector(19 downto 0);
   signal axil_arprot             : std_logic_vector(2 downto 0);
   signal axil_arid               : std_logic_vector(7 downto 0);
   signal axil_rready             : std_logic;
   signal axil_rvalid             : std_logic;
   signal axil_rdata              : std_logic_vector(63 downto 0);
   signal axil_rresp              : std_logic_vector(1 downto 0);
   signal axil_rid                : std_logic_vector(7 downto 0);

   signal mem_address             : std_logic_vector(19 downto 0);
   signal mem_byteenable          : std_logic_vector(7 downto 0);
   signal mem_read                : std_logic;
   signal mem_readdata            : std_logic_vector(63 downto 0);
   signal mem_readdatavalid       : std_logic;
   signal mem_waitrequest         : std_logic;
   signal mem_write               : std_logic;
   signal mem_writedata           : std_logic_vector(63 downto 0);
   signal mem_response            : std_logic_vector(1 downto 0);
   signal mem_writeresponsevalid  : std_logic;

begin

   p_test : process is
      variable data : std_logic_vector(63 downto 0);

      procedure write_avmm(addr : std_logic_vector(19 downto 0); data : std_logic_vector(63 downto 0)) is
      begin
         avmm_byteenable <= (others => '1');
         avmm_address    <= addr;
         avmm_read       <= '0';
         avmm_write      <= '1';
         avmm_writedata  <= data;
         wait until clk = '1';

         while avmm_write = '1' and avmm_waitrequest = '1' loop
            wait until clk = '1';
         end loop;

         avmm_read      <= '0';
         avmm_write     <= '0';
         avmm_address   <= (others => '0');
         avmm_writedata <= (others => '0');
         wait until clk = '1';
      end procedure write_avmm;

      procedure read_avmm(addr : std_logic_vector(19 downto 0); data : out std_logic_vector(63 downto 0)) is
      begin
         avmm_address <= addr;
         avmm_read    <= '1';
         avmm_write   <= '0';
         wait until clk = '1';

         while avmm_read = '1' and avmm_waitrequest = '1' loop
            wait until clk = '1';
         end loop;

         avmm_address   <= (others => '0');
         avmm_read      <= '0';
         avmm_write     <= '0';
         avmm_writedata <= (others => '0');
         wait until clk = '1';

         while avmm_readdatavalid = '0' loop
            wait until clk = '1';
         end loop;

         data := avmm_readdata;
      end procedure read_avmm;

   begin -- p_test
      report "Test started!";

      avmm_read  <= '0';
      avmm_write <= '0';
      wait for 500 ns;
      wait until clk = '1';

      write_avmm(X"01234", X"deadbeefb00bcafe");
      wait for 100 ns;
      wait until clk = '1';

      write_avmm(X"00123", X"cafebabedeadb00b");
      wait for 500 ns;
      wait until clk = '1';

      read_avmm(X"01234", data);
      assert data = X"deadbeefb00bcafe";
      wait for 100 ns;
      wait until clk = '1';

      read_avmm(X"00123", data);
      assert data = X"cafebabedeadb00b";
      wait for 100 ns;
      wait until clk = '1';

      report "Test finished!";
      wait;
   end process p_test;

   p_clk : process
   begin
      clk <= '1';
      wait for HALF_PERIOD * 1 ns;
      clk <= '0';
      wait for HALF_PERIOD * 1 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';

      rst <= '0';
      wait until clk = '1';
      wait;
   end process p_rst;

   i_avalon_axi : entity work.avalon_axi
      generic map (
         G_ADDR_SIZE => 20,
         G_DATA_SIZE => 64
      )
      port map (
         clk_i                      => clk,
         rst_i                      => rst,
         s_avm_address_i            => avmm_address,
         s_avm_byteenable_i         => avmm_byteenable,
         s_avm_read_i               => avmm_read,
         s_avm_readdata_o           => avmm_readdata,
         s_avm_readdatavalid_o      => avmm_readdatavalid,
         s_avm_waitrequest_o        => avmm_waitrequest,
         s_avm_write_i              => avmm_write,
         s_avm_writedata_i          => avmm_writedata,
         s_avm_response_o           => avmm_response,
         s_avm_writeresponsevalid_o => avmm_writeresponsevalid,
         m_axil_awready_i           => axil_awready,
         m_axil_awvalid_o           => axil_awvalid,
         m_axil_awaddr_o            => axil_awaddr,
         m_axil_awprot_o            => axil_awprot,
         m_axil_awid_o              => axil_awid,
         m_axil_wready_i            => axil_wready,
         m_axil_wvalid_o            => axil_wvalid,
         m_axil_wdata_o             => axil_wdata,
         m_axil_wstrb_o             => axil_wstrb,
         m_axil_bready_o            => axil_bready,
         m_axil_bvalid_i            => axil_bvalid,
         m_axil_bresp_i             => axil_bresp,
         m_axil_bid_i               => axil_bid,
         m_axil_arready_i           => axil_arready,
         m_axil_arvalid_o           => axil_arvalid,
         m_axil_araddr_o            => axil_araddr,
         m_axil_arprot_o            => axil_arprot,
         m_axil_arid_o              => axil_arid,
         m_axil_rready_o            => axil_rready,
         m_axil_rvalid_i            => axil_rvalid,
         m_axil_rdata_i             => axil_rdata,
         m_axil_rresp_i             => axil_rresp,
         m_axil_rid_i               => axil_rid
      ); -- i_avalon_axi

   i_axi_avalon : entity work.axi_avalon
      generic map (
         G_ADDR_SIZE => 20,
         G_DATA_SIZE => 64
      )
      port map (
         clk_i                      => clk,
         rst_i                      => rst,
         s_axil_awready_o           => axil_awready,
         s_axil_awvalid_i           => axil_awvalid,
         s_axil_awaddr_i            => axil_awaddr,
         s_axil_awprot_i            => axil_awprot,
         s_axil_awid_i              => axil_awid,
         s_axil_wready_o            => axil_wready,
         s_axil_wvalid_i            => axil_wvalid,
         s_axil_wdata_i             => axil_wdata,
         s_axil_wstrb_i             => axil_wstrb,
         s_axil_bready_i            => axil_bready,
         s_axil_bvalid_o            => axil_bvalid,
         s_axil_bresp_o             => axil_bresp,
         s_axil_bid_o               => axil_bid,
         s_axil_arready_o           => axil_arready,
         s_axil_arvalid_i           => axil_arvalid,
         s_axil_araddr_i            => axil_araddr,
         s_axil_arprot_i            => axil_arprot,
         s_axil_arid_i              => axil_arid,
         s_axil_rready_i            => axil_rready,
         s_axil_rvalid_o            => axil_rvalid,
         s_axil_rdata_o             => axil_rdata,
         s_axil_rresp_o             => axil_rresp,
         s_axil_rid_o               => axil_rid,
         m_avm_address_o            => mem_address,
         m_avm_byteenable_o         => mem_byteenable,
         m_avm_read_o               => mem_read,
         m_avm_readdata_i           => mem_readdata,
         m_avm_readdatavalid_i      => mem_readdatavalid,
         m_avm_waitrequest_i        => mem_waitrequest,
         m_avm_write_o              => mem_write,
         m_avm_writedata_o          => mem_writedata,
         m_avm_response_i           => mem_response,
         m_avm_writeresponsevalid_i => mem_writeresponsevalid
      ); -- i_axi_avalon

   i_avm_memory : entity work.avm_memory
      generic map (
         G_ADDRESS_SIZE => 20,
         G_DATA_SIZE    => 64
      )
      port map (
         clk_i                    => clk,
         rst_i                    => rst,
         avm_address_i            => mem_address,
         avm_byteenable_i         => mem_byteenable,
         avm_burstcount_i         => X"01",
         avm_read_i               => mem_read,
         avm_readdata_o           => mem_readdata,
         avm_readdatavalid_o      => mem_readdatavalid,
         avm_waitrequest_o        => mem_waitrequest,
         avm_write_i              => mem_write,
         avm_writedata_i          => mem_writedata
      ); -- i_avm_memory

end architecture simulation;

