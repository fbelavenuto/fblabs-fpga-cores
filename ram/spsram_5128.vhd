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

entity spsram_5128 is
	port (
		clock_i			:  in    std_logic;
		clock_en_i		:  in    std_logic						:= '1';
		-- Port 0
		sync_addr_i	    :  in    std_logic_vector(18 downto 0);
		sync_ce_n_i	    :  in    std_logic;
		sync_oe_n_i	    :  in    std_logic;
		sync_we_n_i	    :  in    std_logic;
		sync_data_i	    :  in    std_logic_vector(7 downto 0);
		sync_data_o	    :  out   std_logic_vector(7 downto 0);
		-- SRAM in board
		sram_addr_o		:  out   std_logic_vector(18 downto 0);
		sram_data_io	:  inout std_logic_vector(7 downto 0);
		sram_ce_n_o		:  out   std_logic						:= '1';
		sram_oe_n_o		:  out   std_logic						:= '1';
		sram_we_n_o		:  out   std_logic						:= '1'
	);
end entity;

architecture Behavior of spSRAM_5128 is

	signal sram_we_n_s	: std_logic;
	signal sram_oe_n_s	: std_logic;

begin

	sram_ce_n_o	<= '0';		-- sempre ativa
	sram_we_n_o	<= sram_we_n_s;
	sram_oe_n_o	<= sram_oe_n_s;

	process (clock_i, clock_en_i)

		variable state_v		: std_logic	:= '0';
		variable p0_ce_v		: std_logic_vector(1 downto 0);
		variable acesso0_v  	: std_logic;
		variable p0_req_v		: std_logic									:= '0';
		variable p0_we_v		: std_logic									:= '0';
		variable p0_addr_v  	: std_logic_vector(18 downto 0);
		variable p0_data_v  	: std_logic_vector(7 downto 0);

	begin
		if rising_edge(clock_i) and clock_en_i = '1' then
			acesso0_v	:= sync_ce_n_i or (sync_oe_n_i and sync_we_n_i);
			p0_ce_v		:= p0_ce_v(0) & acesso0_v;

			if p0_ce_v = "10" then							-- detecta rising edge do pedido da sync
				p0_req_v		:= '1';						-- marca que sync pediu acesso
				p0_we_v			:= '0';						-- por enquanto eh leitura
				p0_addr_v		:= sync_addr_i;			-- pegamos endereco
				if sync_we_n_i = '0' then					-- se foi gravacao que a sync pediu
					p0_we_v		:= '1';						-- marcamos que eh gravacao
					p0_data_v	:= sync_data_i;			-- pegamos dado
				end if;
			end if;

			if state_v = '0' then							-- Estado 0
				sram_data_io	<= (others => 'Z');			-- desconectar bus da SRAM
				if p0_req_v = '1' then						-- pedido da sync pendente
					sram_addr_o		<= p0_addr_v;			-- colocamos o endereco pedido na SRAM
					sram_we_n_s		<= '1';
					sram_oe_n_s		<= '0';
					if p0_we_v = '1' then					-- se for gravacao
						sram_data_io	<= p0_data_v;		-- damos o dado para a SRAM
						sram_we_n_s		<= '0';				-- e dizemos para ela gravar
						sram_oe_n_s		<= '1';
					end if;
					state_v	:= '1';
				end if;
			elsif state_v = '1' then						-- Estado 1
				if p0_req_v = '1' then						-- pedido da sync pendente
					sram_we_n_s		<= '1';
					sram_data_io	<= (others => 'Z');		-- desconectar bus da SRAM
					if p0_we_v = '0' then					-- se for leitura
						sync_data_o	<= sram_data_io;	-- pegamos o dado que a SRAM devolveu
					end if;
					p0_req_v	:= '0';						-- limpamos a flag de requisicao da sync
					state_v		:= '0';						-- voltar para estado 0
					sram_oe_n_s	<= '1';
				end if;
			end if;
		end if;
	end process;
end;
