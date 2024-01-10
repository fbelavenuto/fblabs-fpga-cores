-------------------------------------------------------------------------------
-- $Id: dpram.vhd,v 1.1 2006/02/23 21:46:45 arnim Exp $
-- 2024/01: by Fabio Belavenuto: renamed signals, added clock enable
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity dpram is
	generic (
		addr_width_g : integer := 8;
		data_width_g : integer := 8
	);
	port (
		clk_a_i		: in  std_logic;
		clk_en_a_i	: in  std_logic									:= '1';
		we_a_n_i	: in  std_logic									:= '1';
		addr_a_i	: in  std_logic_vector(addr_width_g-1 downto 0);
		data_a_i	: in  std_logic_vector(data_width_g-1 downto 0)	:= (others => '0');
		data_a_o	: out std_logic_vector(data_width_g-1 downto 0);
		clk_b_i		: in  std_logic;
		clk_en_b_i	: in  std_logic									:= '1';
		we_b_n_i	: in  std_logic									:= '1';
		addr_b_i	: in  std_logic_vector(addr_width_g-1 downto 0);
		data_b_i	: in  std_logic_vector(data_width_g-1 downto 0)	:= (others => '0');
		data_b_o	: out std_logic_vector(data_width_g-1 downto 0)
	);
end entity;

library ieee;
use ieee.numeric_std.all;

architecture rtl of dpram is

	type   ram_t	is array (natural range 2**addr_width_g-1 downto 0) of std_logic_vector(data_width_g-1 downto 0);
  	signal ram_q	: ram_t
		-- pragma translate_off
		:= (others => (others => '0'))
		-- pragma translate_on
	;

begin

	mem_a: process (clk_a_i, clk_en_a_i)
		variable addr_v	: unsigned(addr_width_g-1 downto 0);
	begin
		if rising_edge(clk_a_i) and clk_en_a_i = '1' then
			addr_v := unsigned(addr_a_i);
			if we_a_n_i = '0' then
				ram_q(to_integer(addr_v)) <= data_a_i;
			end if;
			data_a_o <= ram_q(to_integer(addr_v));
		end if;
	end process;

	mem_b: process (clk_b_i, clk_en_b_i)
		variable addr_v	: unsigned(addr_width_g-1 downto 0);
	begin
		if rising_edge(clk_b_i) and clk_en_b_i = '1' then
			addr_v := unsigned(addr_b_i);
			if we_b_n_i = '0' then
				ram_q(to_integer(addr_v)) <= data_b_i;
			end if;
			data_b_o <= ram_q(to_integer(addr_v));
		end if;
	end process;

end architecture;
