--
-- Z80 compatible microprocessor core, asynchronous top level
--
-- Version : 0250
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
--  http://opencores.org/project,T80
--      http://www.opencores.org/cvsweb.shtml/t80/
--
-- Limitations :
--
-- File history :
--
--  0208 : First complete release
--
--  0211 : Fixed interrupt cycle
--
--  0235 : Updated for T80 interface change
--
--  0238 : Updated for T80 interface change
--
--  0240 : Updated for T80 interface change
--
--  0242 : Updated for T80 interface change
--
--  0247 : Fixed bus req/ack cycle
--
--  0250 : Added R800 Multiplier by TobiFlex 2017.10.15
--
-- Bus signal logic changes from the ZX Spectrum Next were made by:
--
-- Fabio Belavenuto, Charlie Ingley
--
-------------------------------------------------------------------------------
--
--  2016.08 by Fabio Belavenuto: Refactoring signal names
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.t80_pack.all;

entity T80a is
	generic(
	  	mode_g		: integer		:= 0;		-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
	  	iowait_g	: integer		:= 1;		-- 0 => Single I/O cycle, 1 => Std I/O cycle
		nmos_g		: boolean		:= true		-- false => OUT(C),255; true => OUT(C),0
	);
	port(
		r800_mode_i : in    std_logic;
		reset_n_i   : in    std_logic;
		clock_i     : in    std_logic;
		address_o   : out   std_logic_vector(15 downto 0);
		data_i      : in    std_logic_vector(7 downto 0);
		data_o      : out   std_logic_vector(7 downto 0);
		wait_n_i    : in    std_logic;
		int_n_i     : in    std_logic;
		nmi_n_i     : in    std_logic;
		m1_n_o      : out   std_logic;
		mreq_n_o    : out   std_logic;
		iorq_n_o    : out   std_logic;
		rd_n_o      : out   std_logic;
		wr_n_o      : out   std_logic;
		refresh_n_o : out   std_logic;
		halt_n_o    : out   std_logic;
		busrq_n_i   : in    std_logic;
		busak_n_o   : out   std_logic
   );
end T80a;

architecture rtl of T80a is

	signal reset_s              : std_logic;
	signal int_cycle_n_s        : std_logic;
	signal iorq_s               : std_logic;
	signal noread_s             : std_logic;
	signal write_s              : std_logic;
	signal mreq_s               : std_logic;
	signal mreq_inhibit_s       : std_logic;
	signal req_inhibit_s        : std_logic;
	signal rd_s                 : std_logic;
	signal mreq_n_s             : std_logic;
	signal mreq_rw_s            : std_logic;   -- 30/10/19 Charlie Ingley-- add MREQ control
	signal iorq_n_s             : std_logic;
	signal iorq_t1_s            : std_logic;   -- 30/10/19 Charlie Ingley-- add IORQ control
	signal iorq_t2_s            : std_logic;   -- 30/10/19 Charlie Ingley-- add IORQ control
	signal iorq_rw_s            : std_logic;   -- 30/10/19 Charlie Ingley-- add IORQ control
	signal iorq_int_s           : std_logic;   -- 30/10/19 Charlie Ingley-- add IORQ interrupt control
	signal iorq_int_inhibit_s   : std_logic_vector(2 downto 0);
	signal rd_n_s               : std_logic;
	signal wr_n_s               : std_logic;
	signal wr_t2_s              : std_logic;   -- 30/10/19 Charlie Ingley-- add WR control
	signal rfsh_n_s             : std_logic;
	signal busak_n_s            : std_logic;
	signal address_s            : std_logic_vector(15 downto 0);
	signal data_out_s           : std_logic_vector( 7 downto 0);
	signal data_r               : std_logic_vector( 7 downto 0);               -- Input synchroniser
	signal wait_s               : std_logic;
	signal m_cycle_s            : std_logic_vector( 2 downto 0);
	signal t_state_s            : std_logic_vector( 2 downto 0);

begin

	busak_n_o   <= busak_n_s;                                                       -- 30/10/19 Charlie Ingley - IORQ/RD/WR changes
	mreq_rw_s   <= mreq_s and (req_inhibit_s or mreq_inhibit_s);                    -- added MREQ timing control
	mreq_n_s    <= not mreq_rw_s;                                                   -- changed MREQ generation 
	iorq_rw_s   <= iorq_s and not (iorq_t1_s or iorq_t2_s);                         -- added IORQ generation timing control
	iorq_n_s    <= not ((iorq_int_s and not iorq_int_inhibit_s(2)) or iorq_rw_s);   -- changed IORQ generation
	rd_n_s      <= not (rd_s and (mreq_rw_s or iorq_rw_s));                         -- changed RD/IORQ generation
	wr_n_s      <= not (write_s and ((wr_t2_s and mreq_rw_s) or iorq_rw_s));        -- added WR/IORQ timing control

	mreq_n_o    <= mreq_n_s		when busak_n_s = '1' else 'Z';
	iorq_n_o    <= iorq_n_s		when busak_n_s = '1' else 'Z';              -- 0247a
	rd_n_o      <= rd_n_s		when busak_n_s = '1' else 'Z';
	wr_n_o      <= wr_n_s		when busak_n_s = '1' else 'Z';              -- 0247a
	refresh_n_o <= rfsh_n_s		when busak_n_s = '1' else 'Z';
	address_o   <= address_s	when busak_n_s = '1' else (others => 'Z');
	data_o      <= data_out_s	when busak_n_s = '1' else (others => 'Z');

	-- Synchronous reset
	process (reset_n_i, clock_i)
	begin
		if reset_n_i = '0' then
			reset_s <= '0';
		elsif rising_edge(clock_i) then
			reset_s <= '1';
		end if;
	end process;

	u0 : entity work.T80
	generic map(
		Mode		=> mode_g,
		IOWait		=> iowait_g,
		NMOS_g		=> nmos_g
	)
	port map(
		R800_mode	=> r800_mode_i,
		CEN			=> '1',
		M1_n		=> m1_n_o,
		IORQ		=> iorq_s,
		NoRead		=> noread_s,
		Write		=> write_s,
		RFSH_n		=> rfsh_n_s,
		HALT_n		=> halt_n_o,
		WAIT_n		=> wait_s,
		INT_n		=> int_n_i,
		NMI_n		=> nmi_n_i,
		RESET_n		=> reset_s,
		BUSRQ_n		=> busrq_n_i,
		BUSAK_n		=> busak_n_s,
		CLK_n		=> clock_i,
		A			=> address_s,
		DInst		=> data_i,
		DI			=> data_r,
		DO			=> data_out_s,
		MC			=> m_cycle_s,
		TS			=> t_state_s,
		IntCycle_n	=> int_cycle_n_s
	  );

	process (clock_i)
	begin
		if falling_edge(clock_i) then
			wait_s <= wait_n_i;
			if t_state_s = 3 and busak_n_s = '1' then
				data_r <= data_i;
			end if;
		end if;
	end process;

-- 30/10/19 Charlie Ingley - Generate WR_t2 to correct MREQ/WR timing
	process (reset_s, clock_i)
	begin
		if reset_s = '0' then
			wr_t2_s <= '0';
		elsif falling_edge(clock_i) then
			if m_cycle_s /= 1 then
				if t_state_s = 2 then		-- WR starts on falling edge of T2 for MREQ
					wr_t2_s <=  write_s;
				end if;
			end if;
			if t_state_s = 3 then			-- end WR
				wr_t2_s <= '0';
			end if;
		end if;
	end process;

-- Generate Req_Inhibit
	process (reset_s, clock_i)				-- 0247a
	begin
		if reset_s = '0' then
			req_inhibit_s <= '1';										-- Charlie Ingley 30/10/19 - changed Req_Inhibit polarity
		elsif rising_edge(clock_i) then
			if m_cycle_s = 1 and t_state_s = 2 and wait_s = '1' then	-- by Fabio Belavenuto - fix behavior of Wait_n
				req_inhibit_s <= '0';
			else
				req_inhibit_s <= '1';
			end if;
		end if;
	end process;

-- Generate MReq_Inhibit
	process (reset_s, clock_i)
	begin
		if reset_s = '0' then
			mreq_inhibit_s <= '1';										-- Charlie Ingley 30/10/19 - changed Req_Inhibit polarity
		elsif falling_edge(clock_i) then
			if m_cycle_s = 1 and t_state_s = 2 and wait_n_i = '1' then	-- by Fabio Belavenuto - fix behavior of Wait_n
				mreq_inhibit_s <= '0';
			else
				mreq_inhibit_s <= '1';
			end if;
		end if;
	end process;

-- Generate RD for MREQ
	process(reset_s, clock_i)			-- 0247a
	begin
		if reset_s = '0' then
			rd_s      <= '0';
			mreq_s   <= '0';
		elsif falling_edge(clock_i) then
			if m_cycle_s = 1 then
				if t_state_s = 1 then
					rd_s      <= int_cycle_n_s;
					mreq_s   <= int_cycle_n_s;
				end if;
				if t_state_s = 3 then
					rd_s      <= '0';
					mreq_s   <= '1';
				end if;
				if t_state_s = 4 then
					mreq_s   <= '0';
				end if;
			else
				if t_state_s = 1 and noread_s = '0' then
					rd_s <= not write_s;
					mreq_s <= not iorq_s;
				end if;
				if t_state_s = 3 then
					rd_s      <= '0';
					mreq_s   <= '0';
				end if;
			end if;
		end if;
	end process;

 -- 30/10/19 Charlie Ingley - Generate IORQ_int for IORQ interrupt timing control
	process(reset_s, clock_i)
	begin
		if reset_s = '0' then
			iorq_int_s <= '0';
		elsif rising_edge(clock_i) then
			if m_cycle_s = 1 then
				if t_state_s = 1 then
					iorq_int_s <= not int_cycle_n_s;
				end if;
				if t_state_s = 2 and wait_s = '1' then
					iorq_int_s <= '0';
				end if;
			end if;
		end if;
	end process;

	process(reset_s, clock_i)
	begin
		if reset_s = '0' then
			iorq_int_inhibit_s <= "111";
		elsif falling_edge(clock_i) then
			if int_cycle_n_s = '0' then
				if m_cycle_s = 1 then
					iorq_int_inhibit_s <= iorq_int_inhibit_s(1 downto 0) & '0';
				end if;
				if m_cycle_s = 2 then
					iorq_int_inhibit_s <= "111";
				end if;
			end if;
		end if;
	end process;

-- 30/10/19 Charlie Ingley - Generate IORQ_t1 for IORQ timing control
	process(reset_s, clock_i)
	begin
		if reset_s = '0' then
			iorq_t1_s <= '1';
		elsif falling_edge(clock_i) then
			if t_state_s = 1 then
				iorq_t1_s <= not int_cycle_n_s;
			end if;
			if t_state_s = 3 then
				iorq_t1_s <= '1';
			end if;
		end if;
	end process;

-- 30/10/19 Charlie Ingley - Generate IORQ_t2 for IORQ timing control
	process (reset_s, clock_i)
	begin
		if reset_n_i = '0' then
			iorq_t2_s <= '1';
		elsif rising_edge(clock_i) then
			iorq_t2_s <= iorq_t1_s;
		end if;
	end process;

end;
