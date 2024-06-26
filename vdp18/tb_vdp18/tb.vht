-------------------------------------------------------------------------------
--
-- MSX1 FPGA project
--
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
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
use std.textio.all;
use work.vdp18_pack.all;

entity tb is
end tb;

architecture testbench of tb is

	signal tb_end				: std_logic;
	signal clock_s				: std_logic;
	signal clock_en_10m7_s		: std_logic;
	signal por_s				: std_logic;
	signal reset_s				: std_logic;
	signal csr_n_s				: std_logic;
	signal csw_n_s				: std_logic;
	signal mode_s				: std_logic_vector( 1 downto 0);
	signal int_n_s				: std_logic;
	signal cd_i_s				: std_logic_vector( 7 downto 0);
	signal cd_o_s				: std_logic_vector( 7 downto 0);
	signal wait_n_s				: std_logic;
	signal vram_ce_n_s			: std_logic;
	signal vram_oe_n_s			: std_logic;
	signal vram_we_n_s			: std_logic;
	signal vram_addr_s			: std_logic_vector(13 downto 0);	-- 16K
	signal vram_data_i_s		: std_logic_vector( 7 downto 0);
	signal vram_data_o_s		: std_logic_vector( 7 downto 0);
	signal rgb_r_s				: std_logic_vector( 3 downto 0);
	signal rgb_g_s				: std_logic_vector( 3 downto 0);
	signal rgb_b_s				: std_logic_vector( 3 downto 0);
	signal hsync_n_s			: std_logic;
	signal vsync_n_s			: std_logic;

begin

	--  instance
	u_target: entity work.vdp18_core
	generic map (
		video_opt_g	=> 0
	)
	port map (
		clock_i			=> clock_s,
		clk_en_10m7_i	=> clock_en_10m7_s,
		por_i			=> por_s,
		reset_i			=> reset_s,
		csr_n_i			=> csr_n_s,
		csw_n_i			=> csw_n_s,
		mode_i			=> mode_s,
		int_n_o			=> int_n_s,
		cd_i			=> cd_i_s,
		cd_o			=> cd_o_s,
		wait_n_o		=> wait_n_s,
		vram_ce_n_o		=> vram_ce_n_s,
		vram_oe_n_o		=> vram_oe_n_s,
		vram_we_n_o		=> vram_we_n_s,
		vram_a_o		=> vram_addr_s,
		vram_d_o		=> vram_data_o_s,
		vram_d_i		=> vram_data_i_s,
		vga_en_i		=> '0',
		scanline_en_i	=> '0',
		cnt_hor_o		=> open,
		cnt_ver_o		=> open,
		rgb_r_o			=> rgb_r_s,
		rgb_g_o			=> rgb_g_s,
		rgb_b_o			=> rgb_b_s,
		hsync_n_o		=> hsync_n_s,
		vsync_n_o		=> vsync_n_s,
		ntsc_pal_i		=> '0',
		vertfreq_csw_o	=> open,
		vertfreq_d_o	=> open
	);

	-- ----------------------------------------------------- --
	--  clock generator                                      --
	-- ----------------------------------------------------- --
	process
	begin
		if tb_end = '1' then
			wait;
		end if;
		clock_s <= '0';
		wait for 23.364 ns;		-- 21 MHz
		clock_s <= '1';
		wait for 23.364 ns;
	end process;

	process (clock_s)
		variable cnt_q	: std_logic_vector(1 downto 0)	:= (others => '0');
	begin
		if rising_edge(clock_s) then
			clock_en_10m7_s <= '0';
			if cnt_q = 0 then
				clock_en_10m7_s <= '1';
				cnt_q := "01";
			else
				cnt_q := cnt_q - 1;
			end if;
		end if;
	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	process
	begin
		-- init
		csr_n_s			<= '1';
		csw_n_s			<= '1';
		mode_s			<= "00";
		cd_i_s			<= (others => '0');
		vram_data_i_s	<= (others => '0');

		-- reset
		por_s			<= '1';
		reset_s			<= '1';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		por_s			<= '0';
		reset_s			<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );

		wait for 2569 us;

		mode_s			<= "01";				-- control port
		cd_i_s			<= X"00";
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '1';
		for i in 0 to 7 loop
			wait until( rising_edge(clock_s) );
		end loop;

		cd_i_s			<= X"40";				-- Write address 0000
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '1';
		for i in 0 to 7 loop
			wait until( rising_edge(clock_s) );
		end loop;

		mode_s			<= "00";				-- data port
		cd_i_s			<= X"AA";
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '0';
		wait until( rising_edge(clock_s) );
		if wait_n_s = '0' then
			wait until wait_n_s = '1';
		end if;
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '1';
		for i in 0 to 11 loop
			wait until( rising_edge(clock_s) );
		end loop;

		cd_i_s			<= X"55";
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		if wait_n_s = '0' then
			wait until wait_n_s = '1';
		end if;
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		csw_n_s			<= '1';
		for i in 0 to 9 loop
			wait until( rising_edge(clock_s) );
		end loop;


		wait for 5 ms;

		-- wait
		tb_end <= '1';
		wait;
	end process;

end architecture;
