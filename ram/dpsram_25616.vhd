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

entity dpsram_25616 is
	port (
		clock_i				: in    std_logic;
		clock_en_i			: in    std_logic						:= '1';
		-- port 0
		port0_addr_i		: in    std_logic_vector(18 downto 0);
		port0_ce_n_i		: in    std_logic;
		port0_oe_n_i		: in    std_logic;
		port0_we_n_i		: in    std_logic;
		port0_data_i		: in    std_logic_vector(7 downto 0);
		port0_data_o		: out   std_logic_vector(7 downto 0);
		-- port 1
		port1_addr_i		: in    std_logic_vector(18 downto 0);
		port1_ce_n_i		: in    std_logic;
		port1_oe_n_i		: in    std_logic;
		port1_we_n_i		: in    std_logic;
		port1_data_i		: in    std_logic_vector(7 downto 0);
		port1_data_o		: out   std_logic_vector(7 downto 0);
		-- Output to SRAM in board
		sram_addr_o			: out   std_logic_vector(17 downto 0);
		sram_data_io		: inout std_logic_vector(15 downto 0);
		sram_ub_n_o			: out   std_logic;
		sram_lb_n_o			: out   std_logic;
		sram_ce_n_o			: out   std_logic						:= '1';
		sram_oe_n_o			: out   std_logic						:= '1';
		sram_we_n_o			: out   std_logic						:= '1'
	);
end entity;

architecture Behavior of dpSRAM_25616 is

	signal sram_a		: std_logic_vector(18 downto 0);
	signal sram_d		: std_logic_vector(7 downto 0);
	signal sram_we		: std_logic;
	signal sram_oe		: std_logic;

begin

	sram_ce_n_o			<= '0';					-- sempre ativa
	sram_oe_n_o			<= sram_oe;
	sram_we_n_o			<= sram_we;
	sram_ub_n_o			<= not sram_a(0);		-- UB = 0 ativa bits 15..8
	sram_lb_n_o			<= sram_a(0);			-- LB = 0 ativa bits 7..0
	sram_addr_o			<= sram_a(18 downto 1);
	sram_data_io		<= "ZZZZZZZZ" & sram_d	when sram_a(0) = '0' else
							sram_d & "ZZZZZZZZ";

	process (clock_i, clock_en_i)

		variable state		: std_logic	:= '0';
		variable p0_ce		: std_logic_vector(1 downto 0);
		variable p1_ce		: std_logic_vector(1 downto 0);
		variable acesso0	: std_logic;
		variable acesso1	: std_logic;
		variable p0_req		: std_logic									:= '0';
		variable p1_req		: std_logic									:= '0';
		variable p0_we		: std_logic									:= '0';
		variable p1_we		: std_logic									:= '0';
		variable p0_addr	: std_logic_vector(18 downto 0);
		variable p1_addr	: std_logic_vector(18 downto 0);
		variable p0_data	: std_logic_vector(7 downto 0);
		variable p1_data	: std_logic_vector(7 downto 0);

	begin
		if rising_edge(clock_i) and clock_en_i = '1' then
			acesso0	:= port0_ce_n_i or (port0_oe_n_i and port0_we_n_i);
			acesso1	:= port1_ce_n_i or (port1_oe_n_i and port1_we_n_i);
			p0_ce		:= p0_ce(0) & acesso0;
			p1_ce		:= p1_ce(0) & acesso1;

			if p0_ce = "10" then							-- detecta rising edge do pedido da port0
				p0_req	:= '1';								-- marca que port0 pediu acesso
				p0_we		:= '0';							-- por enquanto eh leitura
				p0_addr	:= port0_addr_i;					-- pegamos endereco
				if port0_we_n_i = '0' then					-- se foi gravacao que a port0 pediu
					p0_we		:= '1';						-- marcamos que eh gravacao
					p0_data	:= port0_data_i;				-- pegamos dado
				end if;
			end if;

			if p1_ce = "10" then							-- detecta rising edge do pedido da port1
				p1_req	:= '1';								-- marca que port1 pediu acesso
				p1_we		:= '0';							-- por enquanto eh leitura
				p1_addr	:= port1_addr_i;					-- pegamos endereco
				if port1_we_n_i = '0' then					-- se foi gravacao que a port1 pediu
					p1_we		:= '1';						-- marcamos que eh gravacao
					p1_data	:= port1_data_i;				-- pegamos dado
				end if;
			end if;

			if state = '0' then								-- Estado 0
				sram_d		<= (others => 'Z');				-- desconectar bus da SRAM
				if p0_req = '1' then						-- pedido da port0 pendente
					sram_a	<= p0_addr;						-- colocamos o endereco pedido na SRAM
					sram_we	<= '1';
					sram_oe	<= '0';
					if p0_we = '1' then						-- se for gravacao
						sram_d	<= p0_data;					-- damos o dado para a SRAM
						sram_we	<= '0';						-- e dizemos para ela gravar
						sram_oe	<= '1';
					end if;
					state	:= '1';
				elsif p1_req = '1' then						-- pedido da port1 pendente
					sram_a	<= p1_addr;						-- colocamos o endereco pedido na SRAM
					sram_we	<= '1';
					sram_oe	<= '0';
					if p1_we = '1' then						-- se for gravacao
						sram_d	<= p1_data;					-- damos o dado para a SRAM
						sram_we	<= '0';						-- e dizemos para ela gravar
						sram_oe	<= '1';
					end if;
					state	:= '1';							-- proximo rising do clock vamos para segundo estado
				end if;
			elsif state = '1' then							-- Estado 1
				if p0_req = '1' then						-- pedido da port0 pendente
					sram_we		<= '1';
					sram_d		<= (others => 'Z');			-- desconectar bus da SRAM
					if p0_we = '0' then						-- se for leitura
						if sram_a(0) = '0' then				-- pegamos o dado que a SRAM devolveu
							port0_data_o	<= sram_data_io(7 downto 0);
						else
							port0_data_o	<= sram_data_io(15 downto 8);
						end if;
					end if;
					p0_req		:= '0';						-- limpamos a flag de requisicao da port0
					state		:= '0';						-- voltar para estado 0
					sram_oe		<= '1';
				elsif p1_req = '1' then						-- pedido da port1 pendente
					sram_we	<= '1';
					sram_d	<= (others => 'Z');				-- desconectar bus da SRAM
					if p1_we = '0' then						-- se for leitura
						if sram_a(0) = '0' then				-- pegamos o dado que a SRAM devolveu
							port1_data_o	<= sram_data_io(7 downto 0);
						else
							port1_data_o	<= sram_data_io(15 downto 8);
						end if;
					end if;
					p1_req		:= '0';						-- limpamos a flag de requisicao da port1
					state		:= '0';						-- voltar para estado 0
					sram_oe		<= '1';
				end if;
			end if;
		end if;
	end process;

end;