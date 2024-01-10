-------------------------------------------------------------------------------
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

entity fifo is
	generic (
		constant data_width_g	: integer := 8;
		constant fifo_depth_g	: integer := 32
	);
	port (
		clock_i		: in  std_logic;
		clock_en_i	: in  std_logic										:= '1';
		reset_i		: in  std_logic;
		write_en_i	: in  std_logic;
		data_i		: in  std_logic_vector(data_width_g - 1 downto 0);
		read_en_i	: in  std_logic;
		data_o		: out std_logic_vector(data_width_g - 1 downto 0);
		empty_o		: out std_logic;
		half_o		: out std_logic;
		full_o		: out std_logic
	);
end entity;

architecture Behavioral of fifo is

begin

	-- Memory Pointer Process
	fifo_proc : process (clock_i, clock_en_i)
		type fifomem_t is array (0 to fifo_depth_g - 1) of std_logic_vector(data_width_g - 1 downto 0);
		variable memory_v	: fifomem_t;
		variable head_v		: natural range 0 to fifo_depth_g - 1;
		variable tail_v		: natural range 0 to fifo_depth_g - 1;
		variable size_v		: natural range 0 to fifo_depth_g;
		variable looped_v	: boolean;
	begin
		if rising_edge(clock_i) and clock_en_i = '1' then
			if reset_i = '1' then
				head_v		:= 0;
				tail_v		:= 0;
				size_v		:= 0;
				looped_v	:= false;
				half_o		<= '0';
				full_o		<= '0';
				empty_o		<= '1';
				data_o		<= (others => '0');
			else
				if read_en_i = '1' then
					if looped_v = true or head_v /= tail_v then
						-- Update data output
						data_o <= memory_v(tail_v);
						size_v := size_v - 1;

						-- Update Tail pointer as needed
						if tail_v = fifo_depth_g - 1 then
							tail_v := 0;
							looped_v := false;
						else
							tail_v := tail_v + 1;
						end if;
					end if;
				end if;
				
				if write_en_i = '1' then
					if looped_v = false or head_v /= tail_v then
						-- Write Data to Memory
						memory_v(head_v) := data_i;
						size_v := size_v + 1;
						
						-- Increment Head pointer as needed
						if head_v = fifo_depth_g - 1 then
							head_v := 0;
							looped_v := true;
						else
							head_v := head_v + 1;
						end if;
					end if;
				end if;
				
				-- Update Empty and Full flags
				if head_v = tail_v then
					if looped_v then
						full_o <= '1';
					else
						empty_o <= '1';
					end if;
				else
					empty_o	<= '0';
					full_o	<= '0';
				end if;
				half_o <= '0';
				if size_v > (fifo_depth_g / 2) then
					half_o <= '1';
				end if;
			end if;
		end if;
	end process;
		
end architecture;