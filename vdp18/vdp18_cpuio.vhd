-------------------------------------------------------------------------------
--
-- Synthesizable model of TI's TMS9918A, TMS9928A, TMS9929A.
--
-- $Id: vdp18_cpuio.vhd,v 1.17 2006/06/18 10:47:01 arnim Exp $
--
-- CPU I/O Interface Module
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
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
--
-- 2023/12: FBLabs: ?
--
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vdp18_pack.all;

entity vdp18_cpuio is
	generic (
		start_on_g		: boolean		:= false	-- false = VDP starts off, true = VDP start showing video
	);
	port (
		clock_i			: in  std_logic;
		clk_en_10m7_i	: in  std_logic;
		clk_en_acc_i	: in  std_logic;
		reset_i			: in  std_logic;
		csr_n_i			: in  std_logic;
		csw_n_i			: in  std_logic;
		mode_i			: in  std_logic_vector(0 to  1);
		cd_i			: in  std_logic_vector(0 to  7);
		cd_o			: out std_logic_vector(0 to  7);
		wait_n_o		: out std_logic;
		access_type_i	: in  access_t;
		opmode_o		: out opmode_t;
		vram_read_o		: out std_logic;
		vram_write_o	: out std_logic;
		vram_we_n_o		: out std_logic;
		vram_a_o		: out std_logic_vector(0 to 13);
		vram_d_o		: out std_logic_vector(0 to  7);
		vram_d_i		: in  std_logic_vector(0 to  7);
		spr_coll_i		: in  std_logic;
		spr_5th_i		: in  std_logic;
		spr_5th_num_i	: in  std_logic_vector(0 to  4);
		reg_ev_o		: out std_logic;
		reg_16k_o		: out std_logic;
		reg_blank_o		: out std_logic;
		reg_size1_o		: out std_logic;
		reg_mag1_o		: out std_logic;
		reg_ntb_o		: out std_logic_vector(0 to  3);
		reg_ctb_o		: out std_logic_vector(0 to  7);
		reg_pgb_o		: out std_logic_vector(0 to  2);
		reg_satb_o		: out std_logic_vector(0 to  6);
		reg_spgb_o		: out std_logic_vector(0 to  2);
		reg_col1_o		: out std_logic_vector(0 to  3);
		reg_col0_o		: out std_logic_vector(0 to  3);
		palette_idx_o	: out std_logic_vector(0 to  3);
		palette_val_o	: out std_logic_vector(0 to 15);
		palette_wr_o	: out std_logic;
		irq_i			: in  std_logic;
		int_n_o			: out std_logic;
		vertfreq_csw_o	: out std_logic;
		vertfreq_d_o	: out std_logic
	);

end vdp18_cpuio;

architecture rtl of vdp18_cpuio is

	type state_t is (ST_IDLE,
					ST_RD_MODE0, ST_WR_MODE0,
					ST_RD_MODE1,
					ST_WR_MODE1_1ST, ST_WR_MODE1_1ST_IDLE,
					ST_WR_MODE1_2ND_VREAD, ST_WR_MODE1_2ND_VWRITE,
					ST_WR_MODE1_2ND_RWRITE,
					ST_WR_PALETTE);
	signal state_s, state_q		: state_t;

	signal buffer_q				: std_logic_vector(0 to 7);
	signal addr_q				: unsigned(0 to 13);
	signal incr_addr_s,
			load_addr_s			: std_logic;
	signal wrbuf_cpu_s			: std_logic;
	signal sched_rdvram_s,
			rdvram_sched_q,
			rdvram_q			: std_logic;
	signal abort_wrvram_s,
			sched_wrvram_s,
			wrvram_sched_q,
			wrvram_q			: std_logic;
	signal write_tmp_s			: std_logic;
	signal tmp_q				: std_logic_vector(0 to 7);
	signal write_reg_s			: std_logic;

	-- control register bits ----------------------------------------------------
	type   ctrl_reg_t is array (natural range 7 downto 0) of std_logic_vector(0 to 7);
	signal ctrl_reg_q : ctrl_reg_t;

	-- status register ----------------------------------------------------------
	signal status_reg_s			: std_logic_vector(0 to 7);
	signal destr_rd_status_s	: std_logic;
	signal sprite_5th_q			: std_logic;
	signal sprite_5th_num_q		: std_logic_vector(0 to 4);
	signal sprite_coll_q			: std_logic;
	signal int_n_q					: std_logic;
  
	type   read_mux_t is (RDMUX_STATUS, RDMUX_READAHEAD);
	signal read_mux_s				: read_mux_t;

	-- palette
	signal palette_idx_s		: unsigned(0 to 3);
	signal incr_palidx_s		: std_logic;
	signal palette_val_s		: std_logic_vector(0 to 15);
	signal write_pal_s			: std_logic;
	signal wrpal_byte2_s		: std_logic;
	signal wait_n_s				: std_logic;
	type transfer_mode_t is (TM_NONE,
							TM_RD_MODE0, TM_WR_MODE0,
							TM_RD_MODE1, TM_WR_MODE1,
							TM_WR_PALETTE);
begin

	-----------------------------------------------------------------------------
	-- Process seq
	--
	-- Purpose:
	--   Implements the sequential elements.
	--
	seq: process (clock_i, reset_i)
		variable incr_addr_v	: std_logic;
		variable write_pal_v	: std_logic;
	begin
		if reset_i = '1' then
			state_q        <= ST_IDLE;
			buffer_q       <= (others => '0');
			addr_q         <= (others => '0');
			rdvram_sched_q <= '0';
			rdvram_q       <= '0';
			wrvram_sched_q <= '0';
			wrvram_q       <= '0';
			palette_idx_o	<= (others => '0');
			wrpal_byte2_s	<= '0';
			write_pal_v		:= '0';
		elsif rising_edge(clock_i) then
			-- default assignments
			incr_addr_v  := incr_addr_s;

			if clk_en_10m7_i = '1' then

				incr_palidx_s	<= '0';

				-- update state vector ------------------------------------------------
				state_q <= state_s;

				-- buffer and flag control --------------------------------------------
				if wrbuf_cpu_s = '1' then
					-- write read-ahead buffer from CPU bus
					buffer_q       <= cd_i;
					-- immediately stop read-ahead
					rdvram_sched_q <= '0';
					rdvram_q       <= '0';
				elsif clk_en_acc_i = '1' and rdvram_q = '1' and access_type_i = AC_CPU then
					-- write read-ahead buffer from VRAM during CPU access slot
					buffer_q    <= vram_d_i;
					-- stop scanning for CPU data
					rdvram_q    <= '0';
					-- increment read-ahead address
					incr_addr_v := '1';
				end if;

				if sched_rdvram_s = '1' then
					-- immediately stop write-back
					wrvram_sched_q <= '0';
					wrvram_q       <= '0';
					-- schedule read-ahead
					rdvram_sched_q <= '1';
				end if;

				if sched_wrvram_s = '1' then
					-- schedule write-back
					wrvram_sched_q <= '1';
				end if;

				if abort_wrvram_s = '1' then
					-- stop scanning for write-back
					wrvram_q <= '0';
				end if;

				if rdvram_sched_q = '1' and clk_en_acc_i = '1' then
					-- align scheduled read-ahead with access slot phase
					rdvram_sched_q <= '0';
					rdvram_q       <= '1';
				end if;
				if wrvram_sched_q = '1' and clk_en_acc_i = '1' then
					-- align scheduled write-back with access slot phase
					wrvram_sched_q <= '0';
					wrvram_q       <= '1';
				end if;

				-- manage address -----------------------------------------------------
				if load_addr_s = '1' then
					addr_q(6 to 13)	<= unsigned(tmp_q);
					addr_q(0 to  5)	<= unsigned(cd_i(2 to 7));
				elsif incr_addr_v = '1' then
					addr_q			<= addr_q + 1;
				end if;

				-- palette
				if write_pal_s = '1' then
					if wrpal_byte2_s = '1' then
						palette_val_s(8 to 15) <= cd_i;
						incr_palidx_s <= '1';
						palette_idx_o <= std_logic_vector(palette_idx_s);
					else
						palette_val_s(0 to 7)  <= cd_i;
					end if;
				end if;
				if write_pal_v = '1' and write_pal_s = '0' then
					wrpal_byte2_s <= not wrpal_byte2_s;
				end if;
				write_pal_v := write_pal_s;

			end if;
		end if;
	end process seq;
	--
	-----------------------------------------------------------------------------

	vram_read_o		<= rdvram_q;
	vram_write_o	<= wrvram_q;

	-----------------------------------------------------------------------------
	-- Process wback_ctrl
	--
	-- Purpose:
	--   Write-back control.
	--
	wback_ctrl: process (clk_en_acc_i, access_type_i, wrvram_q)
	begin
		-- default assignments
		abort_wrvram_s     <= '0';
		incr_addr_s        <= '0';
		vram_we_n_o        <= '1';

		if wrvram_q = '1' then
			if access_type_i = AC_CPU then
				-- signal write access to VRAM
				vram_we_n_o	<= '0';

				if clk_en_acc_i = '1' then
					-- clear write-back flag and increment address
					abort_wrvram_s <= '1';
					incr_addr_s    <= '1';
				end if;
			end if;
		end if;
	end process wback_ctrl;
	--
	-----------------------------------------------------------------------------


	-----------------------------------------------------------------------------
	-- Process reg_if
	--
	-- Purpose:
	--   Implements the register interface.
	--
	reg_if: process (clock_i, reset_i)
		variable reg_addr_v		: unsigned(0 to 2);
		variable incr_palidx_v	: std_logic := '0';
	begin
		if reset_i = '1' then
			tmp_q            <= (others => '0');
			ctrl_reg_q       <= (others => (others => '0'));
			sprite_coll_q    <= '0';
			sprite_5th_q     <= '0';
			sprite_5th_num_q <= (others => '0');
			int_n_q          <= '1';
			if start_on_g then
				ctrl_reg_q(1) <= X"C0";
				ctrl_reg_q(2) <= X"02";
				ctrl_reg_q(3) <= X"2C";
				ctrl_reg_q(7) <= X"F7";
				palette_idx_s	<= X"0";
			end if;
		elsif rising_edge(clock_i) then
			vertfreq_csw_o		<= '0';
			if clk_en_10m7_i = '1' then
				-- Temporary register -------------------------------------------------
				if write_tmp_s = '1' then
					tmp_q      <= cd_i;
				end if;

				-- Registers 0 to 7, 9 and 16 ---------------------------------------------------
				if write_reg_s = '1' then
					if    cd_i(3 to 7) = "10000" then				-- 16
						palette_idx_s <= unsigned(tmp_q(4 to 7));
					elsif cd_i(3 to 7) = "01001" then				-- 9
						vertfreq_d_o	<= tmp_q(6);
						vertfreq_csw_o	<= '1';
					else
						reg_addr_v := unsigned(cd_i(5 to 7));
						ctrl_reg_q(to_integer(reg_addr_v)) <= tmp_q;
					end if;
				end if;
				if incr_palidx_s = '0' and incr_palidx_v = '1' then
					palette_idx_s <= palette_idx_s + 1;
				end if;
				incr_palidx_v := incr_palidx_s;

			end if;

			-- Fifth sprite handling ------------------------------------------------
			if    spr_5th_i = '1' and sprite_5th_q = '0' then
				sprite_5th_q     <= '1';
				sprite_5th_num_q <= spr_5th_num_i;
			elsif destr_rd_status_s = '1' then
				sprite_5th_q     <= '0';
			end if;

			-- Sprite collision flag ------------------------------------------------
			if    spr_coll_i = '1' then
				sprite_coll_q <= '1';
			elsif destr_rd_status_s = '1' then
				sprite_coll_q <= '0';
			end if;

			-- Interrupt ------------------------------------------------------------
			if    irq_i = '1' then
				int_n_q <= '0';
			elsif destr_rd_status_s = '1' then
				int_n_q <= '1';
			end if;
		end if;
	end process reg_if;
	--
	-----------------------------------------------------------------------------


	-----------------------------------------------------------------------------
	-- Process access_ctrl
	--
	-- Purpose:
	--   Implements the combinational logic for the CPU I/F FSM.
	--   Decodes the CPU I/F FSM state and generates the control signals for the
	--   register and VRAM logic.
	--
	access_ctrl: process (clock_i, state_q, csr_n_i, csw_n_i, mode_i, cd_i, rdvram_q, wrvram_q)
		variable transfer_mode_v : transfer_mode_t;
	begin
		-- default assignments
		state_s           <= state_q;
		sched_rdvram_s    <= '0';
		sched_wrvram_s    <= '0';
		wrbuf_cpu_s			<= '0';
		write_tmp_s			<= '0';
		write_reg_s			<= '0';
		load_addr_s			<= '0';
		read_mux_s			<= RDMUX_STATUS;
		destr_rd_status_s	<= '0';
		write_pal_s			<= '0';
		wait_n_s			<= '1';

		-- determine transfer mode
		transfer_mode_v     := TM_NONE;
		case mode_i is
			when "00" =>								-- port 00 (write or read VRAM)
				if csr_n_i = '0' then
					transfer_mode_v := TM_RD_MODE0;
				end if;
				if csw_n_i = '0' then
					transfer_mode_v := TM_WR_MODE0;
				end if;
			when "01" =>								-- port 01 (write or read registers)
				if csr_n_i = '0' then
					transfer_mode_v := TM_RD_MODE1;
				end if;
				if csw_n_i = '0' then
					transfer_mode_v := TM_WR_MODE1;
				end if;
			when "10" =>								-- port 02 (write palette)
				if csw_n_i = '0' then
					transfer_mode_v := TM_WR_PALETTE;
				end if;
			when others =>
				null;
		end case;

		-- FSM state transitions
		case state_q is
			-- ST_IDLE: waiting for CPU access --------------------------------------
			when ST_IDLE =>
				case transfer_mode_v is
					when TM_RD_MODE0 =>
						state_s <= ST_RD_MODE0;
					when TM_WR_MODE0 =>
						state_s <= ST_WR_MODE0;
					when TM_RD_MODE1 =>
						state_s <= ST_RD_MODE1;
					when TM_WR_MODE1 =>
						state_s <= ST_WR_MODE1_1ST;
					when TM_WR_PALETTE =>
						state_s <= ST_WR_PALETTE;
					when others =>
						null;
				end case;

			-- ST_RD_MODE0: read from VRAM ------------------------------------------
			when ST_RD_MODE0 =>
				-- set read mux
				read_mux_s       <= RDMUX_READAHEAD;

				if transfer_mode_v = TM_NONE then
					-- CPU finished read access:
					-- schedule new read-ahead and return to idle
					state_s        <= ST_IDLE;
					sched_rdvram_s <= '1';
				end if;

			-- ST_WR_MODE0: write to VRAM -------------------------------------------
			when ST_WR_MODE0 =>
				-- write data from CPU to write-back/read-ahead buffer
				if wrvram_q = '1' then
					wait_n_s	<= '0';
				else
					wrbuf_cpu_s      <= '1';

					if transfer_mode_v = TM_NONE then
						-- CPU finished write access:
						-- schedule new write-back and return to idle
						state_s        <= ST_IDLE;
						sched_wrvram_s <= '1';
					end if;
				end if;

			-- ST_RD_MODE1: read from status register -------------------------------
			when ST_RD_MODE1 =>
				-- set read mux
				read_mux_s          <= RDMUX_STATUS;

				if transfer_mode_v = TM_NONE then
					-- CPU finished read access:
					-- destructive read of status register and return to IDLE
					destr_rd_status_s <= '1';
					state_s           <= ST_IDLE;
				end if;

			-- ST_WR_MODE1_1ST: save first byte -------------------------------------
			when ST_WR_MODE1_1ST =>
				-- update temp register
				write_tmp_s <= '1';

				if transfer_mode_v = TM_NONE then
					-- CPU finished write access:
					-- become idle but remember that the first byte of a paired write
					-- has been written
					state_s   <= ST_WR_MODE1_1ST_IDLE;
				end if;

			-- ST_WR_MODE1_1ST_IDLE: wait for next access ---------------------------
			when ST_WR_MODE1_1ST_IDLE =>
				-- determine type of next access
				case transfer_mode_v is
					when TM_RD_MODE0 =>
						state_s <= ST_RD_MODE0;
					when TM_WR_MODE0 =>
						state_s <= ST_WR_MODE0;
					when TM_RD_MODE1 =>
						state_s <= ST_RD_MODE1;
					when TM_WR_MODE1 =>
						case cd_i(0 to 1) is
							when "00" =>
								state_s <= ST_WR_MODE1_2ND_VREAD;
							when "01" =>
								state_s <= ST_WR_MODE1_2ND_VWRITE;
							when "10" | "11" =>
								state_s <= ST_WR_MODE1_2ND_RWRITE;
							when others =>
								null;
						end case;
					when others =>
						null;
				end case;

			-- ST_WR_MODE1_2ND_VREAD: write second byte of address, then read ahead -
			when ST_WR_MODE1_2ND_VREAD =>
				load_addr_s      <= '1';

				if transfer_mode_v = TM_NONE then
					-- CPU finished write access:
					-- schedule new read-ahead and return to idle
					sched_rdvram_s <= '1';
					state_s        <= ST_IDLE;
				end if;

			-- ST_WR_MODE1_2ND_VWRITE: write second byte of address
			when ST_WR_MODE1_2ND_VWRITE =>
				load_addr_s      <= '1';

				if transfer_mode_v = TM_NONE then
					-- CPU finished write access:
					-- return to idle
					state_s        <= ST_IDLE;
				end if;

			-- ST_WR_MODE1_2ND_RWRITE: write to register ----------------------------
			when ST_WR_MODE1_2ND_RWRITE =>
				write_reg_s <= '1';

				if transfer_mode_v = TM_NONE then
					-- CPU finished write access:
					-- return to idle
					state_s   <= ST_IDLE;
				end if;

			when ST_WR_PALETTE =>
				write_pal_s <= '1';
				if transfer_mode_v = TM_NONE then
					-- CPU finished write access:
					-- prepare to second byte
					state_s   <= ST_IDLE;
				end if;

			when others =>
				null;

		end case;

	end process access_ctrl;
	--
	-----------------------------------------------------------------------------


	-----------------------------------------------------------------------------
	-- Process mode_decode
	--
	-- Purpose:
	--   Decodes the display mode from the M1, M2, M3 bits.
	--
	mode_decode: process (ctrl_reg_q)
		variable mode_v : std_logic_vector(0 to 2);
	begin
		mode_v := ctrl_reg_q(1)(3) &			-- M1
					ctrl_reg_q(1)(4) &			-- M2
					ctrl_reg_q(0)(6);				-- M3

		case mode_v is
			when "000" =>
				opmode_o <= OPMODE_GRAPH1;
			when "001" =>
				opmode_o <= OPMODE_GRAPH2;
			when "010" =>
				opmode_o <= OPMODE_MULTIC;
			when "100" =>
				opmode_o <= OPMODE_TEXTM;
			when others =>
				opmode_o <= OPMODE_TEXTM;
		end case;
	end process mode_decode;
	--
	-----------------------------------------------------------------------------


	-----------------------------------------------------------------------------
	-- Build status register
	-----------------------------------------------------------------------------
	status_reg_s <= not int_n_q			&
						sprite_5th_q	&
						sprite_coll_q	&
						sprite_5th_num_q;

	-----------------------------------------------------------------------------
	-- Output mapping
	-----------------------------------------------------------------------------
	vram_a_o <= std_logic_vector(addr_q);
	vram_d_o <= buffer_q;

	cd_o		<= buffer_q	when read_mux_s = RDMUX_READAHEAD else	status_reg_s;

	reg_ev_o    <= ctrl_reg_q(0)(7);
	reg_16k_o   <= ctrl_reg_q(1)(0);
	reg_blank_o <= not ctrl_reg_q(1)(1);
	reg_size1_o <= ctrl_reg_q(1)(6);
	reg_mag1_o  <= ctrl_reg_q(1)(7);
	reg_ntb_o   <= ctrl_reg_q(2)(4 to 7);
	reg_ctb_o   <= ctrl_reg_q(3);
	reg_pgb_o   <= ctrl_reg_q(4)(5 to 7);
	reg_satb_o  <= ctrl_reg_q(5)(1 to 7);
	reg_spgb_o  <= ctrl_reg_q(6)(5 to 7);
	reg_col1_o  <= ctrl_reg_q(7)(0 to 3);
	reg_col0_o  <= ctrl_reg_q(7)(4 to 7);
	int_n_o     <= int_n_q or not ctrl_reg_q(1)(2);
	palette_val_o	<= palette_val_s;
	palette_wr_o	<= incr_palidx_s when palette_idx_s /= 0 else '0';
	wait_n_o		<= wait_n_s;

end rtl;
