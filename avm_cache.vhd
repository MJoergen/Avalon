-- This module implements a very simple read cache with just one cache line.
--
-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/HyperRAM).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity avm_cache is
   generic (
      G_CACHE_SIZE   : integer;
      G_ADDRESS_SIZE : integer; -- Number of bits
      G_DATA_SIZE    : integer  -- Number of bits
   );
   port (
      clk_i                 : in  std_logic;
      rst_i                 : in  std_logic;
      s_avm_write_i         : in  std_logic;
      s_avm_read_i          : in  std_logic;
      s_avm_address_i       : in  std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      s_avm_writedata_i     : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_byteenable_i    : in  std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      s_avm_burstcount_i    : in  std_logic_vector(7 downto 0);
      s_avm_readdata_o      : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_readdatavalid_o : out std_logic;
      s_avm_waitrequest_o   : out std_logic;
      m_avm_write_o         : out std_logic;
      m_avm_read_o          : out std_logic;
      m_avm_address_o       : out std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      m_avm_writedata_o     : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_byteenable_o    : out std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      m_avm_burstcount_o    : out std_logic_vector(7 downto 0);
      m_avm_readdata_i      : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_readdatavalid_i : in  std_logic;
      m_avm_waitrequest_i   : in  std_logic
   );
end entity avm_cache;

architecture synthesis of avm_cache is

   -- Registers
   type mem_t is array (0 to G_CACHE_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal cache_data   : mem_t;
   signal cache_addr   : std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
   signal cache_valid  : std_logic;
   signal cache_count  : natural range 0 to G_CACHE_SIZE;

   type t_state is (IDLE_ST, READING_IN_ST, READING_OUT_ST);
   signal state : t_state := IDLE_ST;

   -- Combinatorial
   signal cache_offset_s : std_logic_vector(G_ADDRESS_SIZE-1 downto 0);

begin

   s_avm_waitrequest_o <= '0' when state = IDLE_ST else '1';

   -- Two's complement, i.e. wrap-around
   cache_offset_s <= s_avm_address_i - cache_addr;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_waitrequest_i = '1' then
            m_avm_write_o      <= '0';
            m_avm_read_o       <= '0';
            m_avm_address_o    <= (others => '0');
            m_avm_writedata_o  <= (others => '0');
            m_avm_byteenable_o <= (others => '0');
            m_avm_burstcount_o <= (others => '0');
         end if;

         case state is
            when IDLE_ST =>
               assert not (s_avm_write_i = '1' and s_avm_read_i = '1');

               if s_avm_write_i = '1' then
                  cache_valid <= '0';
                  m_avm_write_o      <= s_avm_write_i;
                  m_avm_read_o       <= s_avm_read_i;
                  m_avm_address_o    <= s_avm_address_i;
                  m_avm_writedata_o  <= s_avm_writedata_i;
                  m_avm_byteenable_o <= s_avm_byteenable_i;
                  m_avm_burstcount_o <= s_avm_burstcount_i;
               end if;

               if s_avm_read_i = '1' then
                  if cache_valid = '1' and cache_offset_s < G_CACHE_SIZE then
                     state <= READING_OUT_ST;
                  else
                     state <= READING_IN_ST;
                  end if;
               end if;

            -- Reading data into cache
            when READING_IN_ST =>
               state <= READING_OUT_ST;

            -- Reading data out of cache
            when READING_OUT_ST =>
               state <= IDLE_ST;

            when others =>
               null;

         end case;

         if rst_i = '1' then
            cache_valid <= '0';
            state       <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

end architecture synthesis;

