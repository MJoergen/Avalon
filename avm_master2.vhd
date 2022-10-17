-- This module is a simple kind of RAM test.
--
-- It generates first a sequence of WRITE operations (writing pseudo-random data),
-- and then a corresponding sequence of READ operations, verifying that the
-- correct values are read back again.
--
-- Created by Michael Jørgensen in 2022 (mjoergen.github.io/HyperRAM).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity avm_master2 is
   generic (
      G_ADDRESS_SIZE : integer; -- Number of bits
      G_DATA_SIZE    : integer  -- Number of bits
   );
   port (
      clk_i                 : in  std_logic;
      rst_i                 : in  std_logic;
      start_i               : in  std_logic;
      wait_o                : out std_logic;
      write_burstcount_i    : in  std_logic_vector(7 downto 0);
      read_burstcount_i     : in  std_logic_vector(7 downto 0);

      m_avm_write_o         : out std_logic;
      m_avm_read_o          : out std_logic;
      m_avm_address_o       : out std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      m_avm_writedata_o     : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_byteenable_o    : out std_logic_vector(G_DATA_SIZE/8-1 downto 0);
      m_avm_burstcount_o    : out std_logic_vector(7 downto 0);
      m_avm_readdata_i      : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      m_avm_readdatavalid_i : in  std_logic;
      m_avm_waitrequest_i   : in  std_logic;
      -- Debug output
      address_o             : out std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
      data_exp_o            : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      data_read_o           : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      error_o               : out std_logic
   );
end entity avm_master2;

architecture synthesis of avm_master2 is

   constant C_ALL_ONES : std_logic_vector(G_DATA_SIZE/8-1 downto 0) := (others => '1');

   type mem_t is array (0 to 2**G_ADDRESS_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);
   type t_state is (IDLE_ST, WORKING_ST, READING_ST, DONE_ST);

   signal mem           : mem_t := (others => (others => '0'));

   type be_t is array (0 to 2**G_ADDRESS_SIZE-1) of std_logic_vector(G_DATA_SIZE/8-1 downto 0);
   signal written       : be_t := (others => (others => '0'));
   signal lfsr_output   : std_logic_vector(31 downto 0);
   signal lfsr_reverse  : std_logic_vector(31 downto 0);
   signal lfsr_random   : std_logic_vector(31 downto 0);
   signal state         : t_state := IDLE_ST;
   signal num_read      : natural;

   -- Combinatorial signals
   signal address_s     : std_logic_vector(G_ADDRESS_SIZE-1 downto 0);
   signal data_s        : std_logic_vector(G_DATA_SIZE-1 downto 0);
   signal byteenable_s  : std_logic_vector(G_DATA_SIZE/8-1 downto 0);
   signal write_s       : std_logic;
   signal lfsr_update_s : std_logic;

   subtype R_ADDRESS    is natural range G_ADDRESS_SIZE-1 downto 0;
   subtype R_DATA       is natural range G_DATA_SIZE + R_ADDRESS'left downto R_ADDRESS'left + 1;
   subtype R_BYTEENABLE is natural range G_DATA_SIZE/8 + R_DATA'left  downto R_DATA'left + 1;
   subtype R_WRITE      is natural range 4 + R_BYTEENABLE'left  downto R_BYTEENABLE'left + 1;

begin

   lfsr_update_s <= (m_avm_write_o or m_avm_read_o) and not m_avm_waitrequest_i;

   address_s    <= lfsr_random(R_ADDRESS);
   data_s       <= lfsr_random(R_DATA);
   byteenable_s <= lfsr_random(R_BYTEENABLE);
   write_s      <= and(lfsr_random(R_WRITE));

   p_master : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_waitrequest_i = '0' then
            m_avm_write_o      <= '0';
            m_avm_read_o       <= '0';
         end if;

         case state is
            when IDLE_ST =>
               if start_i = '1' then
                  wait_o <= '1';
                  state  <= WORKING_ST;
                  report "Starting";
               end if;

            when WORKING_ST | READING_ST =>
               if m_avm_readdatavalid_i = '1' then
                  if data_exp_o /= m_avm_readdata_i then
                     report "Read 0x" & to_hstring(m_avm_readdata_i) & ", but expected 0x" & to_hstring(data_exp_o) severity failure;
                     error_o <= '1';
                  end if;
                  data_read_o <= m_avm_readdata_i;
                  state       <= WORKING_ST;
                  num_read    <= num_read + 1;
               end if;

               if (m_avm_waitrequest_i = '0' or (m_avm_write_o = '0' and m_avm_read_o = '0')) and
                  (state = WORKING_ST or m_avm_readdatavalid_i = '1') then
                  if written(to_integer(address_s)) /= C_ALL_ONES or write_s = '1' or byteenable_s = 0 then
                     m_avm_write_o      <= '1';
                     m_avm_read_o       <= '0';
                     m_avm_address_o    <= address_s;
                     m_avm_writedata_o  <= data_s;
                     m_avm_byteenable_o <= byteenable_s;
                     m_avm_burstcount_o <= write_burstcount_i;
                     written(to_integer(address_s)) <= written(to_integer(address_s)) or byteenable_s;
                     if byteenable_s = 0 then
                        m_avm_byteenable_o <= (others => '1');
                        written(to_integer(address_s)) <= (others => '1');
                     end if;
                  else
                     m_avm_write_o      <= '0';
                     m_avm_read_o       <= '1';
                     m_avm_address_o    <= address_s;
                     m_avm_burstcount_o <= read_burstcount_i;
                     state              <= READING_ST;
                  end if;
               end if;

               if num_read = 2**(G_ADDRESS_SIZE + 4) then
                  m_avm_write_o <= '0';
                  m_avm_read_o  <= '0';
                  state <= DONE_ST;
                  report "Done";
               end if;

            when DONE_ST =>
               wait_o <= '0';

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
            address_o          <= (others => '0');
            data_read_o        <= (others => '0');
            error_o            <= '0';
            written            <= (others => (others => '0'));
            num_read           <= 0;
            state              <= IDLE_ST;
         end if;

      end if;
   end process p_master;

   p_mem : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_avm_write_o = '1' then
            for i in 0 to G_DATA_SIZE/8-1 loop
               if m_avm_byteenable_o(i) then
                  mem(to_integer(m_avm_address_o))(8*i+7 downto 8*i) <= m_avm_writedata_o(8*i+7 downto 8*i);
               end if;
            end loop;
         end if;
         if m_avm_read_o = '1' then
            data_exp_o <= mem(to_integer(m_avm_address_o));
         end if;
      end if;
   end process p_mem;


   --------------------------------------
   -- Instantiate randon number generator
   --------------------------------------

   i_lfsr : entity work.lfsr
      generic map (
         G_WIDTH => 32,
         G_TAPS  => X"0000000080000EA6" -- See https://users.ece.cmu.edu/~koopman/lfsr/32.txt
      )
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         update_i   => lfsr_update_s,
         load_i     => '0',
         load_val_i => (others => '1'),
         output_o   => lfsr_output
      ); -- i_lfsr

   p_reverse : process(all)
   begin
      for i in lfsr_output'low to lfsr_output'high loop
         lfsr_reverse(lfsr_output'high - i) <= lfsr_output(i);
      end loop;
   end process p_reverse;

   lfsr_random <= std_logic_vector(unsigned(lfsr_output) + unsigned(lfsr_reverse));

end architecture synthesis;

