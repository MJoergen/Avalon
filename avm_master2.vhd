
-------------------------------------------------------------------------------
-- avm_master2 — Randomised Avalon-MM Master Stimulus Generator (Testbench)
--
-- This module exercises an Avalon-MM slave (DUT) by generating a randomised
-- stream of single-word write and read transactions, verifying read-back
-- correctness against an internal shadow memory.
--
-- Test strategy:
--   A 64-bit LFSR ('random' entity) produces pseudo-random fields that are
--   sliced into address, data, byte-enable, and write/read selection signals
--   (see R_ADDRESS, R_DATA, R_BYTEENABLE, R_WRITE subtypes below).
--
--   1. For each LFSR sample, the module decides whether to WRITE or READ:
--        - WRITE if any byte-lane of the target address has not yet been
--          written (tracked by the 'written' byte-enable accumulator), OR
--        - WRITE if the random 'write_s' flag is asserted (~1/16 chance),
--          which provides occasional overwrites of already-complete
--          addresses to exercise write-after-read sequences, OR
--        - WRITE if the random byte-enable is all-zero (forced to all-ones
--          to avoid a no-op that would never complete the address), OR
--        - READ  otherwise (all bytes written; shadow memory holds a valid
--          reference for comparison).
--
--   2. On a READ, the returned data is compared against the shadow memory
--      ('mem'), which mirrors every accepted write with byte-enable
--      granularity.  A mismatch asserts error_o (sticky) and reports the
--      expected and actual values.
--
--   3. The test terminates after 2**(G_ADDRESS_SIZE + 4) read responses
--      have been verified.
--
-- Limitations / assumptions:
--   - Only SINGLE-WORD (burstcount = 1) transactions are generated and
--     verified.  The write_burstcount_i and read_burstcount_i ports are
--     forwarded to the DUT's burstcount input but the stimulus and
--     verification logic does NOT produce multi-beat write bursts or
--     track multi-word read responses.  Using values other than X"01"
--     causes Avalon-MM protocol violations (writes) or incorrect
--     verification (reads).
--
--   - The shadow memory is 2**G_ADDRESS_SIZE words.  Keep G_ADDRESS_SIZE
--     small (typically 4–8) to avoid excessive simulation memory.
--
-- Debug outputs:
--   address_o   — address of the most recently accepted read
--   data_exp_o  — expected data from shadow memory for that read
--   data_read_o — actual data returned by the DUT
--   error_o     — sticky flag, asserted on first mismatch (cleared by reset)
--
-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/HyperRAM).
-------------------------------------------------------------------------------

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.numeric_std_unsigned.all;

entity avm_master2 is
   generic (
      G_BURST_WIDTH  : natural; -- Width of burstcount
      G_ADDRESS_SIZE : natural; -- Address width in bits (shadow RAM = 2**G_ADDRESS_SIZE words)
      G_DATA_SIZE    : natural  -- Data word width in bits (must be a multiple of 8)
   );
   port (
      clk_i                 : in    std_logic;
      rst_i                 : in    std_logic;
      start_i               : in    std_logic;                                      -- Pulse high to begin the test
      wait_o                : out   std_logic;                                      -- High while the test is running
      write_burstcount_i    : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);   -- Burstcount forwarded on writes (must be X"01")
      read_burstcount_i     : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);   -- Burstcount forwarded on reads  (must be X"01")

      -- Avalon-MM master interface (directly drives the DUT's slave port)
      m_avm_write_o         : out   std_logic;
      m_avm_read_o          : out   std_logic;
      m_avm_address_o       : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      m_avm_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
      m_avm_burstcount_o    : out   std_logic_vector(G_BURST_WIDTH - 1 downto 0);
      m_avm_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_readdatavalid_i : in    std_logic;
      m_avm_waitrequest_i   : in    std_logic;

      -- Debug / verification outputs
      address_o             : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);  -- Address of the most recently accepted read
      data_exp_o            : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);     -- Expected read data (from shadow memory)
      data_read_o           : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);     -- Actual read data (from DUT)
      error_o               : out   std_logic                                       -- Sticky mismatch flag
   );
end entity avm_master2;

architecture synthesis of avm_master2 is

   -- Byte-enable vector with every bit set: used to test whether all byte-
   -- lanes of a given address have been written at least once.
   constant C_ALL_ONES : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0) := (others => '1');

   ---------------------------------------------------------------------------
   -- Shadow memory: mirrors the DUT's memory contents, updated on every
   -- accepted write with byte-enable granularity.
   ---------------------------------------------------------------------------
   type     mem_type is array (0 to 2 ** G_ADDRESS_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal   mem : mem_type := (others => (others => '0'));

   ---------------------------------------------------------------------------
   -- Per-address byte-enable accumulator: tracks which byte-lanes have been
   -- written.  A read is only issued once written(addr) = C_ALL_ONES, so the
   -- shadow memory holds a complete reference value for the full word.
   ---------------------------------------------------------------------------
   type     be_type is array (0 to 2 ** G_ADDRESS_SIZE - 1) of std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
   signal   written : be_type := (others => (others => '0'));

   type     state_type is (
      IDLE_ST,     -- Waiting for start_i pulse
      WORKING_ST,  -- Issuing transactions; bus is idle or a write is pending acceptance
      READING_ST,  -- A read has been issued; waiting for readdatavalid
      DONE_ST      -- Test complete; wait_o deasserted
   );

   signal   lfsr_random_s : std_logic_vector(63 downto 0);
   signal   state         : state_type := IDLE_ST;
   signal   num_read      : natural    := 0;

   ---------------------------------------------------------------------------
   -- LFSR field mapping
   --
   -- The 64-bit LFSR output is carved into non-overlapping bit-fields that
   -- drive the randomised transaction parameters.  Each subtype defines one
   -- field's bit range.
   --
   --   [R_ADDRESS]    → random target address     (G_ADDRESS_SIZE bits)
   --   [R_DATA]       → random write data         (G_DATA_SIZE    bits)
   --   [R_BYTEENABLE] → random byte-enable mask   (G_DATA_SIZE/8  bits)
   --   [R_WRITE]      → write-override flag field (4 bits, AND-reduced
   --                    to a single bit → '1' with ~1/16 probability)
   --
   -- Total LFSR bits consumed:
   --   G_ADDRESS_SIZE + G_DATA_SIZE + G_DATA_SIZE/8 + 4    (must be <= 64)
   ---------------------------------------------------------------------------
   signal   address_s     : std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
   signal   data_s        : std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal   byteenable_s  : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
   signal   write_s       : std_logic;
   signal   lfsr_update_s : std_logic;

   subtype  R_ADDRESS    is natural range G_ADDRESS_SIZE - 1 downto 0;
   subtype  R_DATA       is natural range G_DATA_SIZE + R_ADDRESS'left downto R_ADDRESS'left + 1;
   subtype  R_BYTEENABLE is natural range G_DATA_SIZE / 8 + R_DATA'left downto R_DATA'left + 1;
   subtype  R_WRITE      is natural range 4 + R_BYTEENABLE'left downto R_BYTEENABLE'left + 1;

begin

   -- Compile-time validation
   assert G_DATA_SIZE >= 8
      report "G_DATA_SIZE must be >= 8"
         severity failure;
   assert G_DATA_SIZE mod 8 = 0
      report "G_DATA_SIZE must be a multiple of 8"
         severity failure;
   assert R_WRITE'left <= 63
      report "LFSR field mapping exceeds 64-bit LFSR width; reduce G_ADDRESS_SIZE or G_DATA_SIZE"
         severity failure;
   assert G_BURST_WIDTH <= 2**G_ADDRESS_SIZE
      report "G_BURST_WIDTH must be <= 2**G_ADDRESS_SIZE"
         severity failure;

   ---------------------------------------------------------------------------
   -- Combinatorial decode of LFSR fields into transaction parameters.
   ---------------------------------------------------------------------------
   address_s    <= lfsr_random_s(R_ADDRESS);
   data_s       <= lfsr_random_s(R_DATA);
   byteenable_s <= lfsr_random_s(R_BYTEENABLE);

   -- write_s is the AND-reduction of 4 LFSR bits: '1' with ~1/16
   -- probability, providing occasional overwrites of already-complete
   -- addresses to exercise write-after-read sequences.
   write_s      <= and(lfsr_random_s(R_WRITE));


   ---------------------------------------------------------------------------
   -- Main FSM process
   ---------------------------------------------------------------------------
   master_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         lfsr_update_s <= '0';

         -- Default: deassert master bus request once accepted by the slave
         if m_avm_waitrequest_i = '0' then
            m_avm_write_o <= '0';
            m_avm_read_o  <= '0';
         end if;

         case state is

            ---------------------------------------------------------------
            -- IDLE_ST: Wait for the external start pulse.
            ---------------------------------------------------------------
            when IDLE_ST =>
               if start_i = '1' then
                  wait_o <= '1';
                  state  <= WORKING_ST;
                  report "Starting";
               end if;

            ---------------------------------------------------------------
            -- WORKING_ST / READING_ST: Active test phase.
            --
            --   WORKING_ST — bus is idle (or a write is pending acceptance).
            --                A new transaction may be issued immediately.
            --   READING_ST — a read has been issued; the module waits for
            --                readdatavalid before issuing the next one.
            --
            -- Both states share the readdatavalid handler (verification)
            -- and the termination check.
            ---------------------------------------------------------------
            when WORKING_ST | READING_ST =>

               -- --------------------------------------------------------
               -- Read-data verification
               -- --------------------------------------------------------
               if m_avm_readdatavalid_i = '1' then
                  if data_exp_o /= m_avm_readdata_i then
                     report "Read 0x" & to_hstring(m_avm_readdata_i) &
                            ", but expected 0x" & to_hstring(data_exp_o)
                        severity failure;
                     error_o <= '1';
                  end if;
                  data_read_o <= m_avm_readdata_i;
                  state       <= WORKING_ST;
                  num_read    <= num_read + 1;
               end if;

               -- --------------------------------------------------------
               -- Issue next transaction
               --
               -- Guard conditions:
               --   (a) Bus is free: either the previous transaction was
               --       accepted (waitrequest low) or no transaction is
               --       pending (write_o and read_o both '0').
               --   (b) State permits: either we are in WORKING_ST (bus
               --       was already idle) or read data has just arrived
               --       this cycle (READING_ST → WORKING_ST transition),
               --       allowing back-to-back pipelining.
               -- --------------------------------------------------------
               if (m_avm_waitrequest_i = '0' or (m_avm_write_o = '0' and m_avm_read_o = '0')) and
                  (state = WORKING_ST or m_avm_readdatavalid_i = '1') then

                  if written(to_integer(address_s)) /= C_ALL_ONES or write_s = '1' or byteenable_s = 0 then
                     -- ---------------------------------------------------
                     -- WRITE transaction
                     --
                     -- Issued when:
                     --   - Target address not yet fully written (primary
                     --     reason: ensures every byte-lane is populated
                     --     before a read is attempted), OR
                     --   - Random overwrite flag (write_s = '1', ~1/16
                     --     probability), OR
                     --   - Byte-enable is all-zero (forced to all-ones
                     --     full-word write to avoid a no-op that would
                     --     never mark any byte-lane as written).
                     -- ---------------------------------------------------
                     lfsr_update_s                  <= '1';
                     m_avm_write_o                  <= '1';
                     m_avm_read_o                   <= '0';
                     m_avm_address_o                <= address_s;
                     m_avm_writedata_o              <= data_s;
                     m_avm_byteenable_o             <= byteenable_s;
                     m_avm_burstcount_o             <= write_burstcount_i;
                     written(to_integer(address_s)) <= written(to_integer(address_s)) or byteenable_s;

                     -- Force all-ones when the random byte-enable is zero
                     if byteenable_s = 0 then
                        m_avm_byteenable_o             <= (others => '1');
                        written(to_integer(address_s)) <= (others => '1');
                     end if;

                  else
                     -- ---------------------------------------------------
                     -- READ transaction
                     --
                     -- Issued only when every byte-lane of the target
                     -- address has been written (written = C_ALL_ONES), so
                     -- the shadow memory holds a valid full-word reference.
                     -- ---------------------------------------------------
                     lfsr_update_s      <= '1';
                     m_avm_write_o      <= '0';
                     m_avm_read_o       <= '1';
                     m_avm_address_o    <= address_s;
                     m_avm_burstcount_o <= read_burstcount_i;
                     state              <= READING_ST;
                  end if;
               end if;

               -- --------------------------------------------------------
               -- Termination check
               --
               -- Placed last so that its assignments (deassert write/read,
               -- transition to DONE_ST) take priority via last-assignment-
               -- wins over any transaction issued above on the same cycle.
               -- --------------------------------------------------------
               if num_read >= 2 ** (G_ADDRESS_SIZE + 4) then
                  m_avm_write_o <= '0';
                  m_avm_read_o  <= '0';
                  state         <= DONE_ST;
                  report "Done";
               end if;

            ---------------------------------------------------------------
            -- DONE_ST: Test complete.
            ---------------------------------------------------------------
            when DONE_ST =>
               wait_o <= '0';

            when others =>
               null;

         end case;

         -- ---------------------------------------------------------------
         -- Synchronous reset
         -- ---------------------------------------------------------------
         if rst_i = '1' then
            wait_o             <= '0';
            m_avm_write_o      <= '0';
            m_avm_read_o       <= '0';
            m_avm_address_o    <= (others => '0');
            m_avm_writedata_o  <= (others => '0');
            m_avm_byteenable_o <= (others => '0');
            m_avm_burstcount_o <= (others => '0');
            address_o          <= (others => '0');
            data_read_o        <= (others => '0');
            error_o            <= '0';
            written            <= (others => (others => '0'));
            num_read           <= 0;
            state              <= IDLE_ST;
         end if;
      end if;
   end process master_proc;

   mem_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_waitrequest_i = '0' and m_avm_write_o = '1' then
            for i in 0 to G_DATA_SIZE / 8 - 1 loop
               if m_avm_byteenable_o(i) = '1' then
                  mem(to_integer(m_avm_address_o))(8 * i + 7 downto 8 * i) <= m_avm_writedata_o(8 * i + 7 downto 8 * i);
               end if;
            end loop;
         end if;
         if m_avm_waitrequest_i = '0' and m_avm_read_o = '1' then
            address_o  <= m_avm_address_o;
            data_exp_o <= mem(to_integer(m_avm_address_o));
         end if;
         if rst_i = '1' then
           data_exp_o <= (others => '0');
         end if;
      end if;
   end process mem_proc;


   --------------------------------------
   -- Instantiate randon number generator
   --------------------------------------

   random_inst : entity work.random
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         update_i => lfsr_update_s,
         output_o => lfsr_random_s
      ); -- random_inst : entity work.random is

end architecture synthesis;

