-- This module implements a single-line read-ahead (prefetch) buffer using the
-- Avalon Memory-Mapped bus interface. On a read miss, it fetches G_CACHE_SIZE
-- words starting from the requested address. When the client reads past the
-- midpoint, the buffer slides forward: the upper half is shifted down, and
-- the next G_CACHE_SIZE/2 words are speculatively fetched from memory.
-- Writes are passed through to the master bus, with write-through updates
-- to the buffer when the write address falls within the cached region.
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
      s_avm_waitrequest_o   : out std_logic;
      s_avm_write_i         : in  std_logic;
      s_avm_read_i          : in  std_logic;
      s_avm_address_i       : in  std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      s_avm_writedata_i     : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_byteenable_i    : in  std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      s_avm_burstcount_i    : in  std_logic_vector(7 downto 0);
      s_avm_readdata_o      : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      s_avm_readdatavalid_o : out std_logic;
      m_avm_waitrequest_i   : in  std_logic;
      m_avm_write_o         : out std_logic;
      m_avm_read_o          : out std_logic;
      m_avm_address_o       : out std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      m_avm_writedata_o     : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_byteenable_o    : out std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      m_avm_burstcount_o    : out std_logic_vector(7 downto 0);
      m_avm_readdata_i      : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_readdatavalid_i : in  std_logic
   );
end entity avm_cache;

architecture synthesis of avm_cache is

   type mem_t is array (0 to G_CACHE_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);
   type t_state is (IDLE_ST, READING_ST);

   -- Registers
   signal cache_data    : mem_t;
   signal cache_addr    : std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
   signal cache_count   : natural range 0 to G_CACHE_SIZE;
   signal rd_burstcount : std_logic_vector(7 downto 0);
   signal state         : t_state := IDLE_ST;

   -- Combinatorial
   signal cache_offset_s : std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
   signal cache_rd_hit_s : std_logic;
   signal cache_wr_hit_s : std_logic;
   signal cache_filled_s : std_logic;

begin

   -- Asserted for one cycle when the final word of a cache fill is received.
   cache_filled_s <= '1' when state = READING_ST and m_avm_readdatavalid_i = '1' and cache_count = G_CACHE_SIZE-1 else '0';

   -- Read hit detection (single-word reads only; burst reads always miss):
   --   Case 1: Requested word is already in the buffer (offset < count).
   --   Case 2: Requested word is arriving from memory this cycle (same-cycle forwarding)
   cache_rd_hit_s <= '1' when s_avm_read_i = '1' and s_avm_burstcount_i = X"01" and cache_offset_s < cache_count else
                     '1' when s_avm_read_i = '1' and s_avm_burstcount_i = X"01" and cache_offset_s = cache_count and cache_count < G_CACHE_SIZE and m_avm_readdatavalid_i = '1' else
                     '0';

   -- Write hit: the write address falls within the currently valid cached region
   -- (single-word writes only). Used to update the buffer on write-through.
   cache_wr_hit_s <= '1' when s_avm_write_i = '1' and s_avm_burstcount_i = X"01" and cache_offset_s < cache_count else
                     '0';

   -- Waitrequest logic (active-high, deasserted = ready):
   --   1. Cache fill just completed, no pending write, no outstanding client burst → ready
   --   2. Read hit during READING_ST, no pending write → ready (serve from buffer)
   --   3. IDLE_ST: pass through master's waitrequest when a bus transaction is active
   --   4. READING_ST with outstanding client burst (rd_burstcount > 0) → wait
   --   5. Cache is full (READING_ST complete, all data received) → ready
   --   6. Otherwise → wait
   s_avm_waitrequest_o <= '0' when cache_filled_s = '1' and s_avm_write_i = '0' and rd_burstcount = X"00" else
                          '0' when cache_rd_hit_s = '1' and s_avm_write_i = '0' and state = READING_ST else
                           m_avm_waitrequest_i and (m_avm_write_o or m_avm_read_o) when state = IDLE_ST else
                          '1' when rd_burstcount /= X"00" else
                          '0' when cache_count = G_CACHE_SIZE else
                          '1';

   -- Compute the offset of the requested address relative to the cache base address.
   -- Unsigned subtraction with natural modular wrap-around on G_ADDRESS_SIZE bits.
   cache_offset_s <= std_logic_vector(unsigned(s_avm_address_i) - unsigned(cache_addr));

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         s_avm_readdata_o      <= (others => '0');
         s_avm_readdatavalid_o <= '0';

         if m_avm_waitrequest_i = '0' then
            m_avm_write_o      <= '0';
            m_avm_read_o       <= '0';
         end if;

         case state is
            when IDLE_ST =>
               assert not (s_avm_write_i = '1' and s_avm_read_i = '1');

               if s_avm_write_i = '1' and s_avm_waitrequest_o = '0' then
                  m_avm_write_o      <= s_avm_write_i;
                  m_avm_read_o       <= s_avm_read_i;
                  m_avm_address_o    <= s_avm_address_i;
                  m_avm_writedata_o  <= s_avm_writedata_i;
                  m_avm_byteenable_o <= s_avm_byteenable_i;
                  m_avm_burstcount_o <= s_avm_burstcount_i;
                  if cache_wr_hit_s = '1' then
                     for i in 0 to G_DATA_SIZE/8-1 loop
                        if s_avm_byteenable_i(i) = '1' then
                           cache_data(to_integer(cache_offset_s))(8*i+7 downto 8*i) <= s_avm_writedata_i(8*i+7 downto 8*i);
                        end if;
                     end loop;
                  end if;
                  state              <= IDLE_ST;
               end if;

               if s_avm_read_i = '1' and s_avm_waitrequest_o = '0' then
                  if cache_rd_hit_s = '1' then
                     s_avm_readdata_o      <= cache_data(to_integer(cache_offset_s));
                     s_avm_readdatavalid_o <= '1';

                     -- Trigger read-ahead when the client reaches the buffer midpoint.
                     -- TBD: Do we need the extra check on s_avm_byteenable_i?
                     if cache_offset_s = G_CACHE_SIZE/2-1 and s_avm_byteenable_i(G_DATA_SIZE/8-1) = '1' then
                        -- The client has read to the midpoint of the buffer.
                        -- Slide the window forward: shift the upper half into the lower half,
                        -- advance the base address by G_CACHE_SIZE/2, and initiate a speculative
                        -- read of G_CACHE_SIZE/2 new words to fill the up
                        m_avm_write_o      <= '0';
                        m_avm_read_o       <= '1';
                        m_avm_address_o    <= std_logic_vector(unsigned(cache_addr) + G_CACHE_SIZE);
                        m_avm_burstcount_o <= to_stdlogicvector(G_CACHE_SIZE/2, 8);
                        cache_data(0 to G_CACHE_SIZE/2-1) <= cache_data(G_CACHE_SIZE/2 to G_CACHE_SIZE-1);
                        cache_addr         <= std_logic_vector(unsigned(cache_addr) + G_CACHE_SIZE/2);
                        cache_count        <= G_CACHE_SIZE/2;
                        rd_burstcount      <= (others => '0'); -- Speculative prefetch:
                                                               -- no client burst to forward data to
                        state              <= READING_ST;
                     end if;
                  else
                     m_avm_write_o      <= '0';
                     m_avm_read_o       <= '1';
                     m_avm_address_o    <= s_avm_address_i;
                     m_avm_burstcount_o <= to_stdlogicvector(G_CACHE_SIZE, 8);
                     cache_addr         <= s_avm_address_i;
                     cache_count        <= 0;
                     rd_burstcount      <= s_avm_burstcount_i;
                     state              <= READING_ST;
                  end if;
               end if;

            -- READING_ST: Cache fill is in progress.
            -- - Incoming master data is stored in cache_data and optionally forwarded to the client.
            -- - On fill completion, new slave requests are accepted immediately (same cycle).
            -- - Read hits against already-filled entries are served during the fill.
            when READING_ST =>
               if m_avm_readdatavalid_i = '1' then
                  cache_data(cache_count) <= m_avm_readdata_i;
                  if rd_burstcount /= 0 then
                     s_avm_readdata_o        <= m_avm_readdata_i;
                     s_avm_readdatavalid_o   <= '1';
                     rd_burstcount           <= std_logic_vector(unsigned(rd_burstcount) - 1);
                  end if;

                  if cache_count >= G_CACHE_SIZE-1 then
                     cache_count <= G_CACHE_SIZE;
                     state       <= IDLE_ST;

                     -- Priority (last-assignment-wins): continuation read > new read > new write.
                     -- These blocks are intentionally ordered so that later assignments override earlier one
                     if s_avm_write_i = '1' and s_avm_waitrequest_o = '0' then
                        m_avm_write_o      <= s_avm_write_i;
                        m_avm_read_o       <= s_avm_read_i;
                        m_avm_address_o    <= s_avm_address_i;
                        m_avm_writedata_o  <= s_avm_writedata_i;
                        m_avm_byteenable_o <= s_avm_byteenable_i;
                        m_avm_burstcount_o <= s_avm_burstcount_i;
                        if cache_wr_hit_s = '1' then
                           for i in 0 to G_DATA_SIZE/8-1 loop
                              if s_avm_byteenable_i(i) = '1' then
                                 cache_data(to_integer(cache_offset_s))(8*i+7 downto 8*i) <= s_avm_writedata_i(8*i+7 downto 8*i);
                              end if;
                           end loop;
                        end if;
                        state              <= IDLE_ST;
                     end if;

                     if s_avm_read_i = '1' and s_avm_waitrequest_o = '0' then
                        if cache_rd_hit_s = '1' then
                           s_avm_readdata_o      <= cache_data(to_integer(cache_offset_s));
                           s_avm_readdatavalid_o <= '1';
                        else
                           m_avm_write_o      <= '0';
                           m_avm_read_o       <= '1';
                           m_avm_address_o    <= s_avm_address_i;
                           m_avm_burstcount_o <= to_stdlogicvector(G_CACHE_SIZE, 8);
                           rd_burstcount      <= s_avm_burstcount_i;
                           cache_count        <= 0;
                           cache_addr         <= s_avm_address_i;
                           state              <= READING_ST;
                        end if;
                     end if;

                     if rd_burstcount > 0 then
                        m_avm_write_o      <= '0';
                        m_avm_read_o       <= '1';
                        m_avm_address_o    <= std_logic_vector(unsigned(cache_addr) + G_CACHE_SIZE);
                        m_avm_burstcount_o <= to_stdlogicvector(G_CACHE_SIZE, 8);
                        cache_count        <= 0;
                        cache_addr         <= std_logic_vector(unsigned(cache_addr) + G_CACHE_SIZE);
                        state              <= READING_ST;
                     end if;
                  else
                     cache_count <= cache_count + 1;
                  end if;
               end if;

               -- Serve read hits during cache fill. If the hit targets the word being
               -- received this cycle (offset = count), forward directly from the master bus
               -- since cache_data hasn't been
               if cache_rd_hit_s = '1' and s_avm_waitrequest_o = '0' then
                  s_avm_readdata_o      <= cache_data(to_integer(cache_offset_s));
                  s_avm_readdatavalid_o <= '1';

                  if cache_offset_s = cache_count then
                     s_avm_readdata_o <= m_avm_readdata_i;
                  end if;
               end if;

            when others =>
               null;

         end case;

         if rst_i = '1' then
            s_avm_readdatavalid_o <= '0';
            m_avm_write_o         <= '0';
            m_avm_read_o          <= '0';
            cache_count           <= 0;
            cache_addr            <= (others => '0');
            rd_burstcount         <= (others => '0');
            state                 <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

end architecture synthesis;

