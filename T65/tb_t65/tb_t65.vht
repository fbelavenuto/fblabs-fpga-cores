--
-- Copyright (c) 2015 - FBLabs
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
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
-- You are responsible for any legal issues arising from your use of this code.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.T65_Pack.all;

entity tb is
end tb;

architecture testbench of tb is

	-- test target
	component T65
	port (
		Mode    : in  std_logic_vector(1 downto 0); -- "00" => 6502, "01" => 65C02, "10" => 65C816
		BCD_en  : in  std_logic := '1';             -- '0' => 2A03/2A07, '1' => others
		
		Res_n   : in  std_logic;
		Clk     : in  std_logic;
		Enable  : in  std_logic := '1';
		
		A       : out std_logic_vector(23 downto 0);
		DI      : in  std_logic_vector(7 downto 0);
		DO      : out std_logic_vector(7 downto 0);
		
		Rdy     : in  std_logic := '1';
		Abort_n : in  std_logic := '1';
		IRQ_n   : in  std_logic := '1';
		NMI_n   : in  std_logic := '1';
		SO_n    : in  std_logic := '1';
		R_W_n   : out std_logic;
		Sync    : out std_logic;
		EF      : out std_logic;
		MF      : out std_logic;
		XF      : out std_logic;
		ML_n    : out std_logic;
		VP_n    : out std_logic;
		VDA     : out std_logic;
		VPA     : out std_logic;
		
		DEBUG   : out T_t65_dbg;
		NMI_ack : out std_logic
	);
	end component;

	signal tb_end				: std_logic := '0';
	signal clock_s				: std_logic;
	signal reset_n_s			: std_logic;
	signal cpu_addr_s			: std_logic_vector(23 downto 0);
	signal cpu_di_s			: std_logic_vector( 7 downto 0);
	signal cpu_do_s			: std_logic_vector( 7 downto 0);
	signal cpu_we_n_s			: std_logic;
	signal sync_s				: std_logic;
	
begin

	--  instance
	u_target: T65
	port map (
		Mode    => "00",
		BCD_en  => '1',
		
		Res_n   => reset_n_s,
		Clk     => clock_s,
		Enable  => '1',
		
		A       => cpu_addr_s,
		DI      => cpu_di_s,
		DO      => cpu_do_s,
		
		Rdy     => '1',
		Abort_n => '1',
		IRQ_n   => '1',
		NMI_n   => '1',
		SO_n    => '1',
		R_W_n   => cpu_we_n_s,
		Sync    => sync_s,
		EF      => open,
		MF      => open,
		XF      => open,
		ML_n    => open,
		VP_n    => open,
		VDA     => open,
		VPA     => open,
		
		DEBUG   => open,
		NMI_ack => open
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
		wait for 1000 ns;		-- 1 MHz
		clock_s <= '1';
		wait for 1000 ns;
	end process;

	--
	--
	--
	process (cpu_addr_s, cpu_we_n_s)
	begin
		if cpu_we_n_s = '1' then
			case cpu_addr_s(15 downto 0) is
				when X"0000" => cpu_di_s <= X"A9";		-- LDA #00
				when X"0001" => cpu_di_s <= X"00";		-- 
				when X"0002" => cpu_di_s <= X"8D";		-- STA $2000
				when X"0003" => cpu_di_s <= X"00";		-- 
				when X"0004" => cpu_di_s <= X"20";		-- 
				when X"0005" => cpu_di_s <= X"C8";		-- INY
				when X"0006" => cpu_di_s <= X"EA";		-- NOP
				when X"0007" => cpu_di_s <= X"EA";		-- 
				when X"0008" => cpu_di_s <= X"EA";		-- 
				when X"0009" => cpu_di_s <= X"EA";		-- 
				when X"000A" => cpu_di_s <= X"EA";		-- 
				when X"000B" => cpu_di_s <= X"EA";		-- 
				when X"000C" => cpu_di_s <= X"EA";		-- 
				when X"000D" => cpu_di_s <= X"EA";		-- 
				when X"000E" => cpu_di_s <= X"EA";		-- 
				when X"000F" => cpu_di_s <= X"EA";		-- 

				when X"FFFC" => cpu_di_s <= X"00";		-- 
				when X"FFFD" => cpu_di_s <= X"00";		-- 

				when others  => cpu_di_s <= X"EA";		-- 
			end case;
		else
			cpu_di_s <= (others => 'Z');
		end if;

	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	process
	begin
		-- init

		-- reset
		reset_n_s	<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		reset_n_s	<= '1';
		wait until( rising_edge(clock_s) );

		for i in 0 to 19 loop
			wait until( rising_edge(clock_s) );
		end loop;

		-- wait
		tb_end <= '1';
		wait;
	end process;

end architecture;
