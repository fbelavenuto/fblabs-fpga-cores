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
use work.vdp_package.all;

entity tb is
end tb;

architecture testbench of tb is

	signal tb_end				: std_logic;
	signal clock_s				: std_logic;
	signal reset_s				: std_logic;
	signal req_s				: std_logic;
	signal ack_s				: std_logic;
	signal wrt_s				: std_logic;
	signal mode_s				: std_logic_vector( 1 downto 0);
	signal addr_s				: std_logic_vector(15 downto 0);
	signal int_n_s				: std_logic;
	signal data_i_s				: std_logic_vector( 7 downto 0);
	signal data_o_s				: std_logic_vector( 7 downto 0);
	signal wait_n_s				: std_logic;
	signal vram_oe_n_s			: std_logic;
	signal vram_we_n_s			: std_logic;
	signal vram_addr_s			: std_logic_vector(16 downto 0);	-- 128K
	signal vram_data_i_s		: std_logic_vector(15 downto 0);
	signal vram_data_o_s		: std_logic_vector( 7 downto 0);
	signal rgb_r_s				: std_logic_vector( 5 downto 0);
	signal rgb_g_s				: std_logic_vector( 5 downto 0);
	signal rgb_b_s				: std_logic_vector( 5 downto 0);
	signal hsync_n_s			: std_logic;
	signal vsync_n_s			: std_logic;
	signal videocs_n_s			: std_logic;
	signal video_dhclk_s		: std_logic;
	signal video_dlclk_s		: std_logic;
	signal blank_s				: std_logic;

	procedure write_p(
		mode_i			: in  std_logic_vector( 1 downto 0);
		value_i			: in  std_logic_vector( 7 downto 0);
		signal data_i_s	: out std_logic_vector( 7 downto 0);
		signal mode_s	: out std_logic_vector( 1 downto 0);
		signal req_s	: out std_logic;
		signal wrt_s	: out std_logic
	) is
	begin
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
		mode_s		<= mode_i;
		data_i_s	<= value_i;
		wait until rising_edge(clock_s);
		wrt_s		<= '1';
		wait until rising_edge(clock_s);
		req_s		<= '1';
		wait until rising_edge(clock_s);
		if wait_n_s = '0' then
			wait until wait_n_s='1';
		end if;
		req_s		<= '0';
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
		wrt_s		<= '0';
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
	end procedure;

	procedure read_p(
		mode_i			: in  std_logic_vector( 1 downto 0);
		signal data_i_s	: out std_logic_vector( 7 downto 0);
		signal mode_s	: out std_logic_vector( 1 downto 0);
		signal req_s	: out std_logic;
		signal wrt_s	: out std_logic
	) is
	begin
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
		mode_s		<= mode_i;
		wrt_s		<= '0';
		wait until rising_edge(clock_s);
		req_s		<= '1';
		wait until rising_edge(clock_s);
		req_s		<= '0';
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
		wait until rising_edge(clock_s);
	end procedure;

begin

	--  instance
	addr_s <= "00000000000000" & mode_s;
	
	u_target: entity work.vdp
	generic map (
		start_on_g			=> true
	)
	port map (
        CLK21M              => clock_s,				-- : IN    STD_LOGIC;
        RESET               => reset_s,				-- : IN    STD_LOGIC;
        REQ                 => req_s,				-- : IN    STD_LOGIC;
        ACK                 => ack_s,				-- : OUT   STD_LOGIC;
        WRT                 => wrt_s,				-- : IN    STD_LOGIC;
        ADR                 => addr_s,				-- : IN    STD_LOGIC_VECTOR( 15 DOWNTO 0 );
        DBI                 => data_o_s,			-- : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        DBO                 => data_i_s,			-- : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
		wait_n_o			=> wait_n_s,
        INT_N               => int_n_s,				-- : OUT   STD_LOGIC;
        PRAMOE_N            => vram_oe_n_s,			-- : OUT   STD_LOGIC;
        PRAMWE_N            => vram_we_n_s,			-- : OUT   STD_LOGIC;
        PRAMADR             => vram_addr_s,			-- : OUT   STD_LOGIC_VECTOR( 16 DOWNTO 0 );
        PRAMDBI             => vram_data_i_s,		-- : IN    STD_LOGIC_VECTOR( 15 DOWNTO 0 );
        PRAMDBO             => vram_data_o_s,		-- : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        VDPSPEEDMODE        => '0',					-- : IN    STD_LOGIC;
        RATIOMODE           => (others => '0'),		-- : IN    STD_LOGIC_VECTOR(  2 DOWNTO 0 );
        CENTERYJK_R25_N     => '0',					-- : IN    STD_LOGIC;
        PVIDEOR             => rgb_r_s,				-- : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        PVIDEOG             => rgb_g_s,				-- : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        PVIDEOB             => rgb_b_s,				-- : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        PVIDEOHS_N          => hsync_n_s,			-- : OUT   STD_LOGIC;
        PVIDEOVS_N          => vsync_n_s,			-- : OUT   STD_LOGIC;
        PVIDEOCS_N          => videocs_n_s,			-- : OUT   STD_LOGIC;
        PVIDEODHCLK         => video_dhclk_s,		-- : OUT   STD_LOGIC;
        PVIDEODLCLK         => video_dlclk_s,		-- : OUT   STD_LOGIC;
        BLANK_O             => blank_s,				-- : OUT   STD_LOGIC;
        DISPRESO            => '0',					-- : IN    STD_LOGIC;
        NTSC_PAL_TYPE       => '0',					-- : IN    STD_LOGIC;
        FORCED_V_MODE       => '0',					-- : IN    STD_LOGIC;
        LEGACY_VGA          => '0',					-- : IN    STD_LOGIC;
        VDP_ID              => "00010",				-- : IN    STD_LOGIC_VECTOR(  4 DOWNTO 0 );
        OFFSET_Y            => (others => '0')		-- : IN    STD_LOGIC_VECTOR(  6 DOWNTO 0 )
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
		wait for 23.364 ns;		-- 21 MHz
		clock_s <= '1';
		wait for 23.364 ns;
	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	testbench: process
	begin
		-- init
		req_s			<= '0';
		wrt_s			<= '0';
		mode_s			<= "00";
		data_i_s		<= (others => '0');
		vram_data_i_s	<= (others => '0');

		-- reset
		reset_s			<= '1';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		reset_s			<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );

		wait for 1442 us;

		write_p("01", X"00", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		write_p("01", X"40", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		write_p("00", X"AA", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		for i in 0 to 5 loop
			wait until( rising_edge(clock_s) );
		end loop;
		write_p("00", X"55", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		for i in 0 to 19 loop
			wait until( rising_edge(clock_s) );
		end loop;
		write_p("01", X"00", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		write_p("01", X"40", data_i_s, mode_s, req_s, wrt_s);
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		read_p("00",         data_i_s, mode_s, req_s, wrt_s);

		wait for 1 ms;

		-- wait
		tb_end <= '1';
		wait;
	end process;

end architecture;
