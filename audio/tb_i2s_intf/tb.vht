-------------------------------------------------------------------------------
--
-- Copyright (c) 2024, Fabio Belavenuto (belavenuto@gmail.com)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity tb is
end tb;

architecture testbench of tb is

	signal tb_end		: std_logic;
	signal clock_s		: std_logic;
	signal reset_s		: std_logic;
	signal pcm_li_s		: signed(15 downto 0);
	signal pcm_ri_s		: signed(15 downto 0);
	signal pcm_lo_s		: signed(15 downto 0);
	signal pcm_ro_s		: signed(15 downto 0);
	signal i2s_mclk_s	: std_logic;
	signal i2s_lrclk_s	: std_logic;
	signal i2s_bclk_s	: std_logic;
	signal i2s_di_s		: std_logic;
	signal i2s_do_s		: std_logic;

begin

	--  instance
	u_target: entity work.i2s_intf
	generic map (
		mclk_rate		=> 12000000,
		sample_rate		=> 48000,
		preamble		=> 1,
		word_length		=> 16
	)
	port map(
		clock_i			=> clock_s,
		reset_i			=> reset_s,
		pcm_inl_o		=> pcm_lo_s,
		pcm_inr_o		=> pcm_ro_s,
		pcm_outl_i		=> pcm_li_s,
		pcm_outr_i		=> pcm_ri_s,
		i2s_mclk_o		=> i2s_mclk_s,
		i2s_lrclk_o		=> i2s_lrclk_s,
		i2s_bclk_o		=> i2s_bclk_s,
		i2s_d_o			=> i2s_do_s,
		i2s_d_i			=> i2s_di_s
	);

	-- ----------------------------------------------------- --
	--  clock generator                                      --
	-- ----------------------------------------------------- --
	clock_gen: process
	begin
		if tb_end = '1' then
			wait;
		end if;
		clock_s <= '0';
		wait for 25 ns;
		clock_s <= '1';
		wait for 25 ns;
	end process;

	datain: process
	begin
		if tb_end = '1' then
			wait;
		end if;
		i2s_di_s	<= '0';
		wait for 211 ns;
		i2s_di_s	<= '1';
		wait for 237 ns;
	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	testbench: process
	begin
		-- init
		pcm_li_s <= "1100110011110011";
		pcm_ri_s <= "0110011001100110";

		-- reset
		reset_s	<= '1';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		reset_s	<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );

		wait for 10 ms;

		-- wait
		tb_end <= '1';
		wait;
	end process;

end testbench;
