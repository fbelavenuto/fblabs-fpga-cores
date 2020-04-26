--
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mc6847 is
	port (
		clock_i				: in  std_logic;
		clock_en_i			: in  std_logic;
		reset_i				: in  std_logic;
		da0_o					: out std_logic;
		vr_addr_o			: out std_logic_vector(12 downto 0);
		vr_data_from_i		: in  std_logic_vector( 7 downto 0);
		vr_oe_o				: out std_logic;
		hs_n_o				: out std_logic;
		fs_n_o				: out std_logic;
		an_g_i				: in  std_logic;
		an_s_i				: in  std_logic;
		intn_ext_i			: in  std_logic;
		gm_i					: in  std_logic_vector( 2 downto 0);
		css_i					: in  std_logic;
		inv_i					: in  std_logic;
		video_col_idx_o	: out std_logic_vector( 3 downto 0);
		video_r_o			: out std_logic_vector( 7 downto 0);
		video_g_o			: out std_logic_vector( 7 downto 0);
		video_b_o			: out std_logic_vector( 7 downto 0);
		video_hs_o			: out std_logic;
		video_vs_o			: out std_logic;
		video_hb_o			: out std_logic;
		video_vb_o			: out std_logic
	);
end entity;

use work.mc6847_col_pack.all;

architecture SYN of mc6847 is


	-- H_TOTAL_PER_LINE must be divisible by 16
	-- so that sys_count is the same on each line when
	-- the video comes out of hblank
	-- so the phase relationship between char_d_o from the 6847 and character timing is maintained
	 
	-- 14.31818 MHz : 256 X 384 <---correto
	constant H_FRONT_PORCH			: integer := 11;
	constant H_HORIZ_SYNC			: integer := H_FRONT_PORCH + 37;
	constant H_BACK_PORCH			: integer := H_HORIZ_SYNC + 55;
	constant H_LEFT_BORDER			: integer := H_BACK_PORCH + 48;
	constant H_VIDEO					: integer := H_LEFT_BORDER + 258;
	constant H_RIGHT_BORDER			: integer := H_VIDEO + 55;
	constant H_TOTAL_PER_LINE		: integer := H_RIGHT_BORDER;

	constant V2_FRONT_PORCH			: integer := 2;
	constant V2_VERTICAL_SYNC		: integer := V2_FRONT_PORCH + 2;
	constant V2_BACK_PORCH			: integer := V2_VERTICAL_SYNC + 12;
	constant V2_TOP_BORDER			: integer := V2_BACK_PORCH + 27;			-- + 25;  -- +25 for PAL
	constant V2_VIDEO					: integer := V2_TOP_BORDER + 192;
	constant V2_BOTTOM_BORDER		: integer := V2_VIDEO + 27;				-- + 25;       -- +25 for PAL
	constant V2_TOTAL_PER_FIELD	: integer := V2_BOTTOM_BORDER;

	-- CVBS signals
	signal cvbs_clk_ena				: std_logic;  -- PAL/NTSC*2
	signal cvbs_hsync_s				: std_logic;
	signal cvbs_vsync_s				: std_logic;
	signal cvbs_hblank_s				: std_logic;
	signal cvbs_vblank_s				: std_logic;
	 alias hs_int						: std_logic is cvbs_hblank_s;
	 alias fs_int						: std_logic is cvbs_vblank_s;
	signal cvbs_hborder_s			: std_logic;
	signal cvbs_vborder_s			: std_logic;

	signal active_h_start_s			: std_logic := '0';
	signal row_v						: std_logic_vector(3 downto 0);
	signal an_s_r						: std_logic;
	signal inv_r						: std_logic;
	signal intn_ext_r					: std_logic;
	signal dd_r							: std_logic_vector(7 downto 0);
	signal pixel_char_d_o			: std_logic_vector(6 downto 0);
	signal da0_int						: std_logic_vector(4 downto 0);

	-- character rom signals
	signal char_a						: std_logic_vector(10 downto 0);
	signal char_d_o					: std_logic_vector(7 downto 0);
	signal lookup						: std_logic_vector(5 downto 0);
	signal tripletaddr				: std_logic_vector(7 downto 0);
	signal tripletcnt					: std_logic_vector(3 downto 0);

begin

	-- generate the clocks
	PROC_CLOCKS : process (clock_i, reset_i)
		variable toggle : std_logic := '0';
	begin
		if reset_i = '1' then
			toggle       := '0';
			cvbs_clk_ena <= '0';
		elsif rising_edge(clock_i) then
			cvbs_clk_ena	<= '0';        -- default
			vr_oe_o			<= '0';
			if clock_en_i = '1' then
				cvbs_clk_ena	<= toggle;
				vr_oe_o			<= not toggle;
				toggle			:= not toggle;
			end if;
		end if;
	end process PROC_CLOCKS;

	-- generate horizontal timing for CVBS
	-- generate line buffer address for writing CVBS char_d_o
	PROC_CVBS : process (clock_i, cvbs_clk_ena, reset_i)
		variable h_count_v			: integer range 0 to H_TOTAL_PER_LINE;
		variable v_count_v			: std_logic_vector(8 downto 0);
		variable active_h_count_v	: std_logic_vector(7 downto 0);
		variable active_v_count_v	: std_logic_vector(v_count_v'range);
		variable cvbs_hblank_r		: std_logic := '0';
	begin
		if reset_i = '1' then
			h_count_v			:= H_TOTAL_PER_LINE;
			v_count_v			:= std_logic_vector(to_unsigned(V2_TOTAL_PER_FIELD, v_count_v'length));
			active_h_count_v	:= (others => '0');
			active_h_start_s	<= '0';
			cvbs_hsync_s		<= '0';
			cvbs_vsync_s		<= '0';
			cvbs_hblank_s		<= '0';
			cvbs_vblank_s		<= '1';
			da0_int				<= (others => '0');
			cvbs_hblank_r		:= '0';
			row_v					<= (others => '0');   
		elsif rising_edge (clock_i) and cvbs_clk_ena = '1' then
			active_h_start_s <= '0';
			if h_count_v = H_TOTAL_PER_LINE then
				h_count_v := 0;
				if v_count_v = V2_TOTAL_PER_FIELD then
					v_count_v := (others => '0');
				else
					v_count_v := v_count_v + 1;
				end if;

				if v_count_v = V2_FRONT_PORCH then
					cvbs_vsync_s <= '1';
				elsif v_count_v = V2_VERTICAL_SYNC then
					cvbs_vsync_s <= '0';
				elsif v_count_v = V2_BACK_PORCH then
					cvbs_vborder_s <= '1';
				elsif v_count_v = V2_TOP_BORDER then
					cvbs_vblank_s    <= '0';
					row_v          <= (others => '0');
					active_v_count_v := (others => '0');
					tripletaddr    <= (others => '0');
					tripletcnt     <= (others => '0');
				elsif v_count_v = V2_VIDEO then
					cvbs_vblank_s <= '1';
				elsif v_count_v = V2_BOTTOM_BORDER then
					cvbs_vborder_s <= '0';
				else
					if row_v = 11 then
						row_v <= (others => '0');
						if an_g_i = '0' then
							active_v_count_v := active_v_count_v + 5;  -- step for alphas
						else
							active_v_count_v := active_v_count_v + 1;  -- mode 4,4a
						end if;
					else
						row_v          <= row_v + 1;
						active_v_count_v := active_v_count_v + 1;
					end if;

					if tripletcnt = 2 then  -- mode 1,1a,2a
						tripletcnt  <= (others => '0');
						tripletaddr <= tripletaddr + 1;
					else
						tripletcnt <= tripletcnt + 1;
					end if;
				end if;
			else	-- if h_count_v = H_TOTAL_PER_LINE 
				h_count_v := h_count_v + 1;

				if h_count_v = H_FRONT_PORCH then			-- start hsync
					cvbs_hsync_s <= '1';
				elsif h_count_v = H_HORIZ_SYNC then			-- end hsync
					cvbs_hsync_s <= '0';
				elsif h_count_v = H_BACK_PORCH then			-- start border
					cvbs_hborder_s <= '1';
				elsif h_count_v = H_LEFT_BORDER - 8 then
					active_h_count_v	:= std_logic_vector(to_unsigned(256-8, 8));
				elsif h_count_v = H_LEFT_BORDER then		-- end border and start video (and end hblank?)
					active_h_start_s	<= '1';
				elsif h_count_v = H_LEFT_BORDER+1 then		-- end border and start video (and end hblank?)
					cvbs_hblank_s	<= '0';
				elsif h_count_v = H_VIDEO then				-- start border and start hblank
					active_h_count_v := active_h_count_v + 1;
					cvbs_hblank_s    <= '1';
				elsif h_count_v = H_RIGHT_BORDER then		-- end border
					cvbs_hborder_s <= '0';
				else
					active_h_count_v := active_h_count_v + 1;
				end if;
			end if;

			-- generate character rom address
			char_a <= vr_data_from_i(6 downto 0) & row_v(3 downto 0);

			-- DA0 high during FS
			if cvbs_vblank_s = '1' then
				da0_int <= (others => '1');
			elsif cvbs_hblank_s = '1' then
				da0_int <= (others => '0');
			elsif cvbs_hblank_r = '1' and cvbs_hblank_s = '0' then
				da0_int <= "01000";
			else
				da0_int <= da0_int + 1;
			end if;

			cvbs_hblank_r        := cvbs_hblank_s;

			if an_g_i = '0' then																						-- alphanumeric
				lookup(4 downto 0) <= active_h_count_v(7 downto 3) + 1;
				vr_addr_o          <= "000" & active_v_count_v(8 downto 4) & lookup(4 downto 0);
			else
				case gm_i is              --lookupaddr
					when "000" =>
						lookup(3 downto 0) <= active_h_count_v(7 downto 4) + 1;
						vr_addr_o          <= "0" & tripletaddr(7 downto 0) & lookup(3 downto 0);
					when "001" =>
						lookup(3 downto 0) <= active_h_count_v(7 downto 4) + 1;
						vr_addr_o          <= "0" & tripletaddr(7 downto 0) & lookup(3 downto 0);
					when "010" =>
						lookup(4 downto 0) <= active_h_count_v(7 downto 3) + 1;
						vr_addr_o          <= tripletaddr(7 downto 0) & lookup(4 downto 0);
					when "011" =>
						lookup(3 downto 0) <= active_h_count_v(7 downto 4) + 1;
						vr_addr_o          <= "00" &active_v_count_v(7 downto 1) & lookup(3 downto 0);
					when "100" =>
						lookup(4 downto 0) <= active_h_count_v(7 downto 3) + 1;
						vr_addr_o          <= "0" & active_v_count_v(7 downto 1) & lookup(4 downto 0);
					when "101" =>
						lookup(3 downto 0) <= active_h_count_v(7 downto 4) + 1;
						vr_addr_o          <= "0" &active_v_count_v(7 downto 0) & lookup(3 downto 0);
					when "110" =>
						lookup(4 downto 0) <= active_h_count_v(7 downto 3) + 1;
						vr_addr_o          <= active_v_count_v(7 downto 0) & lookup(4 downto 0);
					when "111" =>
						lookup(4 downto 0) <= active_h_count_v(7 downto 3) + 1;
						vr_addr_o          <= active_v_count_v(7 downto 0) & lookup(4 downto 0);
					when others =>
						null;
				end case;
			end if;
		end if;  -- cvbs_clk_ena
	end process;

	-- handle latching & shifting of character, graphics char_d_o
	process (clock_i, cvbs_clk_ena, reset_i)
		variable count : std_logic_vector(3 downto 0) := (others => '0');
	begin
		if reset_i = '1' then
			count := (others => '0');
		elsif rising_edge(clock_i) and cvbs_clk_ena = '1' then
			if active_h_start_s = '1' then
				count := (others => '0');
			end if;
			if an_g_i = '0' then
				-- alpha-semi modes
				if count(2 downto 0) = 0 then
					-- handle alpha-semi latching
					an_s_r <= an_s_i;
					inv_r  <= inv_i;
					intn_ext_r  <= intn_ext_i;
					if an_s_i = '0' then
						dd_r <= char_d_o;                  -- alpha mode
					else
						-- store luma,chroma(2..0),luma,chroma(2..0)
						if intn_ext_i = '0' then           -- semi-4
							if row_v < 6 then
								dd_r <= vr_data_from_i(3) & vr_data_from_i(6) & vr_data_from_i(5) & vr_data_from_i(4) &
											vr_data_from_i(2) & vr_data_from_i(6) & vr_data_from_i(5) & vr_data_from_i(4);
							else
								dd_r <= vr_data_from_i(1) & vr_data_from_i(6) & vr_data_from_i(5) & vr_data_from_i(4) &
											vr_data_from_i(0) & vr_data_from_i(6) & vr_data_from_i(5) & vr_data_from_i(4);
							end if;
						else            -- semi-6
							if row_v < 4 then
								dd_r <= vr_data_from_i(5) & css_i & vr_data_from_i(7) & vr_data_from_i(6) &
											vr_data_from_i(4) & css_i & vr_data_from_i(7) & vr_data_from_i(6);
							elsif row_v < 8 then
								dd_r <= vr_data_from_i(3) & css_i & vr_data_from_i(7) & vr_data_from_i(6) &
											vr_data_from_i(2) & css_i & vr_data_from_i(7) & vr_data_from_i(6);
							else
								dd_r <= vr_data_from_i(1) & css_i & vr_data_from_i(7) & vr_data_from_i(6) &
											vr_data_from_i(0) & css_i & vr_data_from_i(7) & vr_data_from_i(6);
							end if;
						end if;
					end if;
				else
					-- handle alpha-semi shifting
					if an_s_r = '0' then
						dd_r <= dd_r(dd_r'left-1 downto 0) & '0';  -- alpha mode
					else
						if count(1 downto 0) = 0 then
							dd_r <= dd_r(dd_r'left-4 downto 0) & "0000";  -- semi mode
						end if;
					end if;
				end if;
			else
				-- graphics modes
				an_s_r <= '0';
				case gm_i is
					when "000" | "001" | "011" | "101" =>  -- CG1/RG1/RG2/RG3
						if count(3 downto 0) = 0 then
							-- handle graphics latching
							dd_r <= vr_data_from_i;
						else
							-- handle graphics shifting
							if gm_i = "000" then
								if count(1 downto 0) = 0 then
									dd_r <= dd_r(dd_r'left-2 downto 0) & "00";  -- CG1
								end if;
							else
								if count(0) = '0' then
									dd_r <= dd_r(dd_r'left-1 downto 0) & '0';  -- RG1/RG2/RG3
								end if;
							end if;
						end if;
					when others =>      -- CG2/CG3/CG6/RG6
						if count(2 downto 0) = 0 then
							-- handle graphics latching
							dd_r <= vr_data_from_i;
						else
							-- handle graphics shifting
							if gm_i = "111" then
								dd_r <= dd_r(dd_r'left-1 downto 0) & '0';  -- RG6
							else
								if count(0) = '0' then
									dd_r <= dd_r(dd_r'left-2 downto 0) & "00";  -- CG2/CG3/CG6
								end if;
							end if;
						end if;
				end case;
			end if;
			count := count + 1;
		end if;
	end process;

    -- generate pixel char_d_o
    process (clock_i, cvbs_clk_ena, reset_i)
        variable luma   : std_logic;
        variable chroma : std_logic_vector(2 downto 0);
    begin
        if reset_i = '1' then
        elsif rising_edge(clock_i) and cvbs_clk_ena = '1' then
            -- alpha/graphics mode
            if an_g_i = '0' then
                -- alphanumeric & semi-graphics mode
                luma := dd_r(dd_r'left);
                if an_s_r = '0' then
                    -- alphanumeric
                    if intn_ext_r = '0' then
                        -- internal rom
                        chroma := (others => css_i);
                        if inv_r = '1' then
                            luma := not luma;
                        end if;  -- normal/inverse
                    else
                        -- external ROM?!?
                    end if;  -- internal/external
                else
                    chroma := dd_r(dd_r'left-1 downto dd_r'left-3);
                end if;  -- alphanumeric/semi-graphics
            else
                -- graphics mode
                case gm_i is
                    when "000" =>                  -- CG1 64x64x4
                        luma   := '1';
                        chroma := css_i & dd_r(dd_r'left downto dd_r'left-1);
                    when "001" | "011" | "101" =>  -- RG1/2/3 128x64/96/192x2
                        luma   := dd_r(dd_r'left);
                        chroma := css_i & "00";    -- green/buff
                    when "010" | "100" | "110" =>  -- CG2/3/6 128x64/96/192x4
                        luma   := '1';
                        chroma := css_i & dd_r(dd_r'left downto dd_r'left-1);
                    when others =>                 -- RG6 256x192x2
                        luma   := dd_r(dd_r'left);
                        chroma := css_i & "00";    -- green/buff
                end case;
            end if;  -- alpha/graphics mode

            -- pack source char_d_o into line buffer
            -- - palette lookup on output
            pixel_char_d_o <= css_i & an_g_i & an_s_r & luma & chroma;

        end if;
    end process;

    -- only write to the linebuffer during active display
--    cvbs_linebuf_we <= not (cvbs_vblank_s or cvbs_hblank_s);


    -- assign outputs

	hs_n_o <= not hs_int;
	fs_n_o <= not fs_int;
	da0_o	<= da0_int(4) when (gm_i = "001" or gm_i = "011" or gm_i = "101") else
				da0_int(3);

	-- map the palette to the pixel char_d_o
	-- -  we do that at the output so we can use a 
	--    higher colour-resolution palette
	--    without using memory in the line buffer
	PROC_OUTPUT : process (clock_i)
		variable r_v	: std_logic_vector(video_r_o'range);
		variable g_v	: std_logic_vector(video_g_o'range);
		variable b_v	: std_logic_vector(video_b_o'range);
		variable idx_v	: std_logic_vector(3 downto 0);
	begin
		if rising_edge(clock_i) then
			if cvbs_clk_ena = '1' then
				if cvbs_hblank_s = '0' and cvbs_vblank_s = '0' then
					map_palette_p(pixel_char_d_o, r_v, g_v, b_v);
					map_color_index_p(pixel_char_d_o, idx_v);
				else
					r_v	:= (others => '0');
					g_v	:= (others => '0');
					b_v	:= (others => '0');
					idx_v	:= (others => '0');
				end if;
				video_r_o			<= r_v;
				video_g_o			<= g_v;
				video_b_o			<= b_v;
				video_col_idx_o	<= idx_v;
			end if;  -- rising_edge(clk)
			video_hs_o <= not cvbs_hsync_s;
			video_vs_o <= not cvbs_vsync_s;
			video_hb_o <= not cvbs_hborder_s;
			video_vb_o <= not cvbs_vborder_s;
		end if;

	end process PROC_OUTPUT;

	-- rom for char generator
	charrom_inst : entity work.mc6847_romchar
	port map (
		clk		=> clock_i,
		addr		=> char_a(9 downto 0),
		data		=> char_d_o
	);

end SYN;
