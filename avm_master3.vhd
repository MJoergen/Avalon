-- This module is a RAM test.
--
-- It generates a random sequence of WRITE and READ operations.
-- Burstcount is always 1, but byteenable varies randomly as well.
-- The module keeps a shadow copy of the memory, and uses that
-- to verify the values received during READ operations.
--
-- Created by Michael Jørgensen in 2023

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity avm_master3 is
   generic (
      G_ADDRESS_SIZE : integer; -- Number of bits
      G_DATA_SIZE    : integer  -- Number of bits
   );
   port (
      clk_i                 : in    std_logic;
      rst_i                 : in    std_logic;
      start_i               : in    std_logic;
      wait_o                : out   std_logic;

      m_avm_waitrequest_i   : in    std_logic;
      m_avm_write_o         : out   std_logic;
      m_avm_read_o          : out   std_logic;
      m_avm_address_o       : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      m_avm_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
      m_avm_burstcount_o    : out   std_logic_vector(7 downto 0);
      m_avm_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
      m_avm_readdatavalid_i : in    std_logic;

      -- Debug output
      count_error_o         : out   std_logic_vector(31 downto 0);
      address_o             : out   std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
      data_exp_o            : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
      data_read_o           : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
   );
end entity avm_master3;

architecture synthesis of avm_master3 is

   constant C_WRITE_SIZE : integer                                        := 1;
   constant C_ALL_ONES   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0) := (others => '1');

   -- Combinatorial signals
   signal   rand_update_s : std_logic;
   signal   random_s      : std_logic_vector(63 downto 0);

   subtype  R_ADDRESS    is natural range G_ADDRESS_SIZE - 1 downto 0;
   subtype  R_DATA       is natural range G_DATA_SIZE + R_ADDRESS'left downto R_ADDRESS'left + 1;
   subtype  R_BYTEENABLE is natural range G_DATA_SIZE / 8 + R_DATA'left  downto R_DATA'left + 1;
   subtype  R_WRITE      is natural range C_WRITE_SIZE + R_BYTEENABLE'left  downto R_BYTEENABLE'left + 1;

   signal   address_s    : std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
   signal   data_s       : std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal   byteenable_s : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
   signal   write_s      : std_logic_vector(C_WRITE_SIZE - 1 downto 0);

   type     state_type is (IDLE_ST, WORKING_ST, READING_ST, DONE_ST);

   signal   state    : state_type                                         := IDLE_ST;
   signal   count    : std_logic_vector(G_ADDRESS_SIZE + 2 downto 0);
   signal   mem_data : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

   random_inst : entity work.random
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         update_i => rand_update_s,
         output_o => random_s
      ); -- random_inst

   address_s     <= random_s(R_ADDRESS);
   data_s        <= random_s(R_DATA);
   byteenable_s  <= random_s(R_BYTEENABLE);
   write_s       <= random_s(R_WRITE);

   rand_update_s <= (m_avm_write_o or m_avm_read_o) and not m_avm_waitrequest_i;

   master_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_waitrequest_i = '0' then
            m_avm_write_o <= '0';
            m_avm_read_o  <= '0';
         end if;

         case state is

            when IDLE_ST =>
               if start_i = '1' then
                  report "Starting";
                  wait_o <= '1';
                  count  <= (others => '0');
                  state  <= WORKING_ST;
               end if;

            when WORKING_ST | READING_ST =>
               if (m_avm_waitrequest_i = '0' or (m_avm_write_o = '0' and m_avm_read_o = '0')) and
                  (state = WORKING_ST or m_avm_readdatavalid_i = '1') then
                  if and (write_s) = '1' or byteenable_s = 0 then
                     m_avm_write_o      <= '1';
                     m_avm_read_o       <= '0';
                     m_avm_address_o    <= address_s;
                     m_avm_writedata_o  <= data_s;
                     m_avm_byteenable_o <= byteenable_s;
                     m_avm_burstcount_o <= X"01";
                     if byteenable_s = 0 then
                        m_avm_byteenable_o <= (others => '1');
                     end if;
                     state <= WORKING_ST;
                  else
                     m_avm_write_o      <= '0';
                     m_avm_read_o       <= '1';
                     m_avm_address_o    <= address_s;
                     m_avm_burstcount_o <= X"01";
                     state              <= READING_ST;
                  end if;

                  count <= count + 1;
                  if count + 1 = 0 then
                     m_avm_write_o <= '0';
                     m_avm_read_o  <= '0';
                     state         <= DONE_ST;
                     report "Done";
                  end if;
               end if;

            when DONE_ST =>
               if start_i = '0' and m_avm_waitrequest_i = '0' then
                  wait_o <= '0';
                  state  <= IDLE_ST;
               end if;

            when others =>
               null;

         end case;

         if rst_i = '1' then
            wait_o             <= '0';
            m_avm_write_o      <= '0';
            m_avm_read_o       <= '0';
            m_avm_address_o    <= (others => '0');
            m_avm_writedata_o  <= (others => '0');
            m_avm_byteenable_o <= (others => '0');
            m_avm_burstcount_o <= (others => '0');
            count              <= (others => '0');
            state              <= IDLE_ST;
         end if;
      end if;
   end process master_proc;

   mem_proc : process (clk_i)
      -- This defines a type containing an array of bytes
      type     mem_type is array (0 to 2 ** G_ADDRESS_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
      variable mem_v : mem_type := (others => (others => '0'));
   begin
      if rising_edge(clk_i) then
         if m_avm_write_o = '1' and m_avm_waitrequest_i = '0' then

            for b in 0 to G_DATA_SIZE / 8 - 1 loop
               if m_avm_byteenable_o(b) = '1' then
                  mem_v(to_integer(m_avm_address_o))(8 * b + 7 downto 8 * b) := m_avm_writedata_o(8 * b + 7 downto 8 * b);
               end if;
            end loop;

         end if;

         if m_avm_read_o = '1' and m_avm_waitrequest_i = '0' then
            mem_data <= mem_v(to_integer(m_avm_address_o));
         end if;
      end if;
   end process mem_proc;

   verifier_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_readdatavalid_i = '1' then
            if m_avm_readdata_i /= mem_data then
               if count_error_o = 0 then
                  address_o   <= m_avm_address_o;
                  data_exp_o  <= mem_data;
                  data_read_o <= m_avm_readdata_i;
               end if;
               assert false
                  report "ERROR at Address " & to_hstring(m_avm_address_o) &
                         ". Expected " & to_hstring(mem_data) &
                         ", read " & to_hstring(m_avm_readdata_i)
                  severity failure;
               count_error_o <= count_error_o + 1;
            end if;
         end if;
         if rst_i = '1' then
            count_error_o <= (others => '0');
         end if;
      end if;
   end process verifier_proc;

end architecture synthesis;

