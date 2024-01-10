--
-- Copyright (c) 2016 - Fabio Belavenuto
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
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb is
end tb;

architecture testbench of tb is

	signal tb_end			: std_logic;
	signal clock_s			: std_logic;
	signal reset_s			: std_logic;
	signal write_en_s		: std_logic;
	signal data_i_s			: std_logic_vector( 7 downto 0);
	signal read_en_s		: std_logic;
	signal data_o_s			: std_logic_vector( 7 downto 0);
	signal empty_s			: std_logic;
	signal half_s			: std_logic;
	signal full_s			: std_logic;

	procedure write_p(
		value_i				: in  std_logic_vector( 7 downto 0);
		signal data_i_s		: out std_logic_vector( 7 downto 0);
		signal write_en_s	: out std_logic
	) is
	begin
		data_i_s	<= value_i;
		wait until( rising_edge(clock_s) );
		write_en_s	<= '1';
		wait until( rising_edge(clock_s) );
		write_en_s	<= '0';
		for i in 0 to 3 loop
			wait until( rising_edge(clock_s) );
		end loop;
	end procedure;

	procedure read_p(
		signal read_en_s	: out std_logic
	) is
	begin
		read_en_s	<= '1';
		wait until( rising_edge(clock_s) );
		read_en_s	<= '0';
		for i in 0 to 5 loop
			wait until( rising_edge(clock_s) );
		end loop;
	end procedure;

begin

	--  instance
	u_target: entity work.fifo
	generic map (
		data_width_g	=> 8,
		fifo_depth_g	=> 4
	)
	port map(
		clock_i		=> clock_s,
		clock_en_i	=> '1',
		reset_i		=> reset_s,
		write_en_i	=> write_en_s,
		data_i		=> data_i_s,
		read_en_i	=> read_en_s,
		data_o		=> data_o_s,
		empty_o		=> empty_s,
		half_o		=> half_s,
		full_o		=> full_s
	);

	-- ----------------------------------------------------- --
	--  clock generator                                      --
	-- ----------------------------------------------------- --
	clkgen: process
	begin
		if tb_end = '1' then
			wait;
		end if;
		clock_s <= '0';
		wait for 25 ns;
		clock_s <= '1';
		wait for 25 ns;
	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	testbench: process
	begin
		-- init
		write_en_s	<= '0';
		read_en_s	<= '0';
		data_i_s	<= (others => '0');
		-- reset
		reset_s		<= '1';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		reset_s		<= '0';
		for i in 0 to 19 loop
			wait until( rising_edge(clock_s) );
		end loop;

		-- write data
		write_p(X"5A", data_i_s, write_en_s);
		write_p(X"A5", data_i_s, write_en_s);
		write_p(X"99", data_i_s, write_en_s);
		-- read data
		read_p(read_en_s);
		-- write data
		write_p(X"11", data_i_s, write_en_s);
		write_p(X"33", data_i_s, write_en_s);
		-- read data
		read_p(read_en_s);
		-- write data
		write_p(X"55", data_i_s, write_en_s);
		-- read data
		read_p(read_en_s);
		read_p(read_en_s);
		read_p(read_en_s);
		read_p(read_en_s);

		-- wait
		tb_end <= '1';
		wait;
	end process;

end testbench;
