-- ----------------------------------------------------------------------------
-- Title      : Tx PREAmp Controller FPGA top module
-- Project    : RAST-2100
-- ----------------------------------------------------------------------------
-- File       : axi_merger.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2023-07-14
-- Platform   : Xilinx Spartan-7
-- ----------------------------------------------------------------------------
-- Description: Merge two generic AXI streams together.
-- Stream 1 has the highest priority.
-- This merger is not stateful; instead it has a combinatorial path from
-- s1_valid_i to s2_ready_o.
-- ----------------------------------------------------------------------------
-- Copyright (c) 2023
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity axi_merger is
  generic (
    G_DATA_SIZE : natural
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;
    s1_ready_o : out   std_logic;
    s1_valid_i : in    std_logic;
    s1_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s2_ready_o : out   std_logic;
    s2_valid_i : in    std_logic;
    s2_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_ready_i  : in    std_logic;
    m_valid_o  : out   std_logic;
    m_data_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axi_merger;

architecture rtl of axi_merger is

begin

  s1_ready_o <= (m_ready_i or not m_valid_o);
  s2_ready_o <= (m_ready_i or not m_valid_o) and not s1_valid_i;

  output_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' or m_valid_o = '0' then
        m_valid_o <= '0';

        if s1_valid_i = '1' then
          m_valid_o <= '1';
          m_data_o  <= s1_data_i;
        elsif s2_valid_i = '1' then
          m_valid_o <= '1';
          m_data_o  <= s2_data_i;
        end if;
      end if;

      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process output_proc;

end architecture rtl;

