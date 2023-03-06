-- Copyright (c) 2008-2019, Silicom Denmark A/S
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
-- 1. Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
-- 
-- 2. Redistributions in binary form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
-- 
-- 3. Neither the name of the Silicom nor the names of its
-- contributors may be used to endorse or promote products derived from
-- this software without specific prior written permission.
-- 
-- 4. This software may only be redistributed and used in connection with a
--  Silicom network adapter product.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
-------------------------------------------------------------------------------
-- Title      : Skid Buffer
-- Project    : sub_axi_lib
-------------------------------------------------------------------------------
-- File       : axi_skid_buffer.vhd
-- Author     : Michael Finn Jorgensen  <mfj@silicom.dk>
-- Company    : Silicom Denmark A/S
-- Created    : 2020-03-12
-- Platform   : 
-- Standard   : VHDL-2008
-------------------------------------------------------------------------------
-- Description:
-- This module is used as a building block in axi_pipe, and axi_lite_pipe.
-- The functionality is described in this link: http://fpgacpu.ca/fpga/Pipeline_Skid_Buffer.html
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity axi_skid_buffer is
   generic (
      G_TDATA_SIZE : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      s_tvalid_i : in  std_logic;
      s_tready_o : out std_logic;
      s_tdata_i  : in  std_logic_vector(G_TDATA_SIZE-1 downto 0);
      s_fill_o   : out std_logic_vector(1 downto 0);
      m_tvalid_o : out std_logic;
      m_tready_i : in  std_logic;
      m_tdata_o  : out std_logic_vector(G_TDATA_SIZE-1 downto 0)
   );
end entity axi_skid_buffer;

architecture synthesis of axi_skid_buffer is

   -- Input registers
   signal s_tdata_r  : std_logic_vector(G_TDATA_SIZE-1 downto 0);

   -- Output registers
   signal m_tdata_r  : std_logic_vector(G_TDATA_SIZE-1 downto 0)   := (others => '0');

   -- Control signals
   signal s_tready_r : std_logic := '1';
   signal m_tvalid_r : std_logic := '0';

begin

   s_fill_o <= "00" when m_tvalid_o = '0' else
               "01" when m_tvalid_o = '1' and s_tready_o = '1' else
               "10"; --  when m_tvalid_o = '1' and s_tready_o = '0'


   p_s_tdata : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_tready_r = '1' then
            s_tdata_r  <= s_tdata_i;
         end if;
      end if;
   end process p_s_tdata;


   p_s_tready : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_tvalid_r = '1' then
            s_tready_r <= m_tready_i or (s_tready_r and not s_tvalid_i);
         end if;

         if rst_i = '1' then
            s_tready_r <= '1';
         end if;
      end if;
   end process p_s_tready;


   p_m : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if s_tready_r = '1' then
            if m_tvalid_r = '0' or m_tready_i = '1' then
               m_tvalid_r <= s_tvalid_i;
               m_tdata_r  <= s_tdata_i;
            end if;
         else
            if m_tready_i = '1' then
               m_tdata_r  <= s_tdata_r;
            end if;
         end if;

         if rst_i = '1' then
            m_tvalid_r <= '0';
         end if;
      end if;
   end process p_m;


   --------------------------
   -- Connect output signals
   --------------------------

   s_tready_o <= s_tready_r;
   m_tvalid_o <= m_tvalid_r;
   m_tdata_o  <= m_tdata_r;

end architecture synthesis;

