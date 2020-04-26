--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mc6847_col_pack is

	constant r_c : natural := 0;
	constant g_c : natural := 1;
	constant b_c : natural := 2;

	subtype rgb_val_t    is natural range 0 to 255;
	type    rgb_triple_t is array (natural range 0 to  2) of rgb_val_t;
	type    rgb_table_t  is array (natural range 0 to 15) of rgb_triple_t;

	-----------------------------------------------------------------------------
	-- Full RGB Value Array

	constant rgb_table_c : rgb_table_t := (
	--    R    G    B
		(  0,   0,   0),                    -- Black
		(  0,   0,   0),                    -- Black
		(  0, 124,   0),                    -- Dark green
		(145,   0,   0),                    -- Dark orange
		(  0,   0,   0),                    -- Black
		(  0,   0,   0),                    -- Black
		(  0,   0,   0),                    -- Black
		(  0,   0,   0),                    -- Black
		(  7, 255,   0),                    -- Green
		(255, 255,   0),                    -- Yellow
		( 59,   8, 255),                    -- Blue
		(204,   0,  59),                    -- Red
		(255, 255, 255),                    -- White
		(  7, 227, 153),                    -- Cyan
		(255,  28, 255),                    -- Magenta
		(255, 129,   0)                     -- Orange
	);

	procedure map_color_index_p (
		params_i			: in  std_logic_vector(6 downto 0);
		color_index_o	: out std_logic_vector(3 downto 0)
	);

	procedure map_palette_p (
		params_i	: in  std_logic_vector(6 downto 0);
		r			: out std_logic_vector(7 downto 0);
		g			: out std_logic_vector(7 downto 0);
		b			: out std_logic_vector(7 downto 0)
	);

end package;

package body mc6847_col_pack is

	procedure map_color_index_p (
		params_i			: in  std_logic_vector(6 downto 0);
		color_index_o	: out std_logic_vector(3 downto 0)
	) is
		alias css_v		: std_logic is params_i(6);
		alias an_g_v	: std_logic is params_i(5);
		alias an_s_v	: std_logic is params_i(4);
		alias luma		: std_logic is params_i(3);
		alias chroma	: std_logic_vector(2 downto 0) is params_i(2 downto 0);
	begin
		if luma = '1' then
			color_index_o	:= luma & chroma;
		else
			color_index_o	:= '0' & an_g_v & not an_s_v & css_v;
		end if;
	end procedure;

	procedure map_palette_p (
		params_i	: in  std_logic_vector(6 downto 0);
		r			: out std_logic_vector(7 downto 0);
		g			: out std_logic_vector(7 downto 0);
		b			: out std_logic_vector(7 downto 0)
	) is
		alias css_v		: std_logic is params_i(6);
		alias an_g_v	: std_logic is params_i(5);
		alias an_s_v	: std_logic is params_i(4);
		alias luma		: std_logic is params_i(3);
		alias chroma	: std_logic_vector(2 downto 0) is params_i(2 downto 0);
		variable idx_v	: std_logic_vector(3 downto 0);
	begin
		if luma = '1' then
			idx_v := luma & chroma;
		else
			idx_v := '0' & an_g_v & not an_s_v & css_v;
		end if;
		r := std_logic_vector(to_unsigned(rgb_table_c(to_integer(unsigned(idx_v)))(r_c),8));
		g := std_logic_vector(to_unsigned(rgb_table_c(to_integer(unsigned(idx_v)))(g_c),8));
		b := std_logic_vector(to_unsigned(rgb_table_c(to_integer(unsigned(idx_v)))(b_c),8));
	end procedure;

end;