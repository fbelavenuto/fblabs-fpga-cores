--
-- Z80 compatible microprocessor core, preudo-asynchronous top level (by Sorgelig)
--
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
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
-- The latest version of this file can be found at:
--  http://www.opencores.org/cvsweb.shtml/t80/
--
-- File history :
--
-- v1.0: convert to preudo-asynchronous model with original Z80 timings.
--
-- v2.0: rewritten for more precise timings.
--       support for both clock_en_n_i and clock_en_p_i set to 1. Effective clock will be CLK/2.
--
-- v2.1: Output Address 0 during non-bus mcycle_s (fix ZX contention)
--
-- v2.2: Interrupt acknowledge cycle has been corrected
--       WAIT_n is broken in T80.vhd. Simulate correct WAIT_n locally.
--
-- v2.3: Output last used Address during non-bus mcycle_s seems more correct.
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.T80_Pack.all;

entity T80pa is
	generic(
		mode_g		: integer	:= 0;		-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		nmos_g		: boolean	:= true		-- false => OUT(C),255; true => OUT(C),0
	);
	port(
		r800_mode_i		: in  std_logic			:= '0';
		reset_n_i		: in  std_logic;
		clock_i			: in  std_logic;
		clock_en_p_i	: in  std_logic 		:= '1';
		clock_en_n_i	: in  std_logic 		:= '1';
		address_o		: out std_logic_vector(15 downto 0);
		data_i			: in  std_logic_vector(7 downto 0);
		data_o			: out std_logic_vector(7 downto 0);
		wait_n_i		: in  std_logic 		:= '1';
		int_n_i			: in  std_logic 		:= '1';
		nmi_n_i			: in  std_logic 		:= '1';
		m1_n_o			: out std_logic;
		mreq_n_o		: out std_logic;
		iorq_n_o		: out std_logic;
		rd_n_o			: out std_logic;
		wr_n_o			: out std_logic;
		refresh_n_o		: out std_logic;
		halt_n_o		: out std_logic;
		busrq_n_i		: in  std_logic 		:= '1';
		busak_n_o		: out std_logic
	);
end T80pa;

architecture rtl of T80pa is

	signal intcycle_n_s		: std_logic;
	signal intcycled_n_s	: std_logic_vector(1 downto 0);
	signal iorq_s			: std_logic;
	signal noread_s			: std_logic;
	signal write_s			: std_logic;
	signal busak_s			: std_logic;
	signal data_r_s			: std_logic_vector (7 downto 0);    -- Input synchroniser
	signal mcycle_s			: std_logic_vector(2 downto 0);
	signal tstate_s			: std_logic_vector(2 downto 0);
	signal clock_en_pol_s	: std_logic;
	signal clock_en_s		: std_logic;
begin

	clock_en_s <= clock_en_p_i and not clock_en_pol_s;
	busak_n_o <= busak_s;

	u0 : entity work.T80
		generic map(
			Mode    => mode_g,
			IOWait  => 1,
			NMOS_g  => nmos_g
		)
		port map(
			CEN     => clock_en_s,
			M1_n    => m1_n_o,
			IORQ    => iorq_s,
			NoRead  => noread_s,
			Write   => write_s,
			RFSH_n  => refresh_n_o,
			HALT_n  => halt_n_o,
			WAIT_n  => wait_n_i,
			INT_n   => int_n_i,
			NMI_n   => nmi_n_i,
			RESET_n => reset_n_i,
			BUSRQ_n => busrq_n_i,
			BUSAK_n => busak_s,
			CLK_n   => clock_i,
			A       => address_o,
			DInst   => data_i,     -- valid   at beginning of T3
			DI      => data_r_s, -- latched at middle    of T3
			DO      => data_o,
			MC      => mcycle_s,
			TS      => tstate_s,
			IntCycle_n => intcycle_n_s
		);

	process(clock_i)
	begin
		if rising_edge(clock_i) then
			if reset_n_i = '0' then
				wr_n_o			<= '1';
				rd_n_o			<= '1';
				iorq_n_o		<= '1';
				mreq_n_o		<= '1';
				data_r_s		<= "00000000";
				clock_en_pol_s	<= '0';
			elsif clock_en_p_i = '1' and clock_en_pol_s = '0' then
				clock_en_pol_s	<= '1';
				if mcycle_s = 1 then
					if tstate_s = 2 then
						iorq_n_o	<= '1';
						mreq_n_o	<= '1';
						rd_n_o		<= '1';
					end if;
				else
					if tstate_s = 1 and iorq_s = '1' then
						wr_n_o		<= not write_s;
						rd_n_o		<= write_s;
						iorq_n_o	<= '0';
					end if;
				end if;
			elsif clock_en_n_i = '1' and clock_en_pol_s = '1' then
				if tstate_s = 2 then
					clock_en_pol_s	<= not wait_n_i;
				else
					clock_en_pol_s	<= '0';
				end if;
				if ((tstate_s = 3 and intcycle_n_s = '1') or (tstate_s = 2 and intcycle_n_s = '0'))  and busak_s = '1' then
					data_r_s	<= data_i;
				end if;
				if mcycle_s = 1 then
					if tstate_s = 1 then
						intcycled_n_s	<= intcycled_n_s(0) & intcycle_n_s;
						rd_n_o			<= not intcycle_n_s;
						mreq_n_o		<= not intcycle_n_s;
						iorq_n_o		<= intcycled_n_s(1);
					end if;
					if tstate_s = 3 then
						intcycled_n_s	<= "11";
						rd_n_o			<= '1';
						mreq_n_o		<= '0';
					end if;
					if tstate_s = 4 then
						mreq_n_o		<= '1';
					end if;
				else
					if noread_s = '0' and iorq_s = '0' then
						if tstate_s = 1 then
							rd_n_o		<= write_s;
							mreq_n_o	<= '0';
						end if;
					end if;
					if tstate_s = 2 then
						wr_n_o   <= not write_s;
					end if;
					if tstate_s = 3 then
						wr_n_o		<= '1';
						rd_n_o		<= '1';
						iorq_n_o	<= '1';
						mreq_n_o	<= '1';
					end if;
				end if;
			end if;
		end if;
	end process;
end;
