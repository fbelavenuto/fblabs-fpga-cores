--
-- T80 testbench
-- Copyright (c) 2023 - Fabio Belavenuto
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
use ieee.std_logic_unsigned.all;
use work.T80_Pack.all;

entity tb is
end tb;

architecture testbench of tb is

    signal tb_end             : std_logic := '0';
    signal clock              : std_logic;                                -- CLOCK
    signal clock_enable       : std_logic;
    signal clock_enable_n     : std_logic;
    signal reset_n            : std_logic;                                -- /RESET
    signal cpu_wait_n         : std_logic;                                -- /WAIT
    signal cpu_irq_n          : std_logic;                                -- /IRQ
    signal cpu_nmi_n          : std_logic;                                -- /NMI
    signal cpu_busreq_n       : std_logic;                                -- /BUSREQ
    signal cpu_m1_n           : std_logic;                                -- /M1
    signal cpu_mreq_n         : std_logic;                                -- /MREQ
    signal cpu_ioreq_n        : std_logic;                                -- /IOREQ
    signal cpu_rd_n           : std_logic;                                -- /RD
    signal cpu_wr_n           : std_logic;                                -- /WR
    signal cpu_rfsh_n         : std_logic;                                -- /REFRESH
    signal cpu_halt_n         : std_logic;                                -- /HALT
    signal cpu_busak_n        : std_logic;                                -- /BUSAK
    signal cpu_a              : std_logic_vector(15 downto 0);            -- A
    signal cpu_di             : std_logic_vector(7 downto 0);
    signal cpu_do             : std_logic_vector(7 downto 0);
    
begin

    --  instance
--    u_target: t80s
--    generic map(
--        Mode    => 0, -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
--        T2Write => 1, -- 0 => WR_n active in T3, /=0 => WR_n active in T2
--        IOWait  => 1  -- 0 => Single cycle I/O, 1 => Std I/O cycle
--    )
--    port map(
--        OUT0        => '0', -- 0 => OUT(C),0, 1 => OUT(C),255
--        RESET_n     => reset_n,
--        CLK         => clock,
--        CEN         => clock_enable,
--        A           => cpu_a,
--        DI          => cpu_di,
--        DO          => cpu_do,
--        WAIT_n      => cpu_wait_n,
--        INT_n       => cpu_irq_n,
--        NMI_n       => cpu_nmi_n,
--        M1_n        => cpu_m1_n,
--        MREQ_n      => cpu_mreq_n,
--        IORQ_n      => cpu_ioreq_n,
--        RD_n        => cpu_rd_n,
--        WR_n        => cpu_wr_n,
--        RFSH_n      => cpu_rfsh_n,
--        HALT_n      => cpu_halt_n,
--        BUSRQ_n     => cpu_busreq_n,
--        BUSAK_n     => cpu_busak_n
--    );

    u_target: t80pa
    generic map(
        Mode    => 0 -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
    )
    port map(
        RESET_n     => reset_n,
        CLK         => clock,
        CEN_p       => clock_enable,
        CEN_n       => clock_enable_n,
        WAIT_n      => cpu_wait_n,
        INT_n       => cpu_irq_n,
        NMI_n       => cpu_nmi_n,
        M1_n        => cpu_m1_n,
        MREQ_n      => cpu_mreq_n,
        IORQ_n      => cpu_ioreq_n,
        RD_n        => cpu_rd_n,
        WR_n        => cpu_wr_n,
        RFSH_n      => cpu_rfsh_n,
        HALT_n      => cpu_halt_n,
        BUSRQ_n     => cpu_busreq_n,
        BUSAK_n     => cpu_busak_n,
        A           => cpu_a,
        DI          => cpu_di,
        DO          => cpu_do
    );

    -- ----------------------------------------------------- --
    --  clock generator                                      --
    -- ----------------------------------------------------- --
    process
    begin
        if tb_end = '1' then
            wait;
        end if;
        clock <= '1';
        wait for 20 ns;
        clock <= '0';
        wait for 20 ns;
    end process;

    -- CEN_p
    process
    begin
        if tb_end = '1' then
            wait;
        end if;
        clock_enable <= '1';
        wait for 40 ns;
        clock_enable <= '0';
        wait for 120 ns;
    end process;

    -- CEN_n
    process
    begin
        if tb_end = '1' then
            wait;
        end if;
        clock_enable_n <= '1';
        wait for 40 ns;
        clock_enable_n <= '0';
        wait for 120 ns;
    end process;

    --
    --
    --
	process (cpu_a)
    begin
        case cpu_a is
            when X"0000" => cpu_di <= X"21";        -- LD HL, $1000     CYCLE = 10
            when X"0001" => cpu_di <= X"00";        -- 
            when X"0002" => cpu_di <= X"10";        -- 
            when X"0003" => cpu_di <= X"11";		-- LD DE, $0000     CYCLE = 10
            when X"0004" => cpu_di <= X"00";		-- 
            when X"0005" => cpu_di <= X"00";		-- 
            when X"0006" => cpu_di <= X"01";		-- LD BC, $FFFF     CYCLE = 10
            when X"0007" => cpu_di <= X"FF";		-- 
            when X"0008" => cpu_di <= X"FF";		-- 
            when X"0009" => cpu_di <= X"36";        -- LD (HL), $34     CYCLE = 14
            when X"000A" => cpu_di <= X"34";        -- 
            when X"000B" => cpu_di <= X"DB";        -- in a,(0)         CYCLE = 24
            when X"000C" => cpu_di <= X"00";        --
            when X"000D" => cpu_di <= X"D3";        -- out (0), a       CYCLE = 11
            when X"000E" => cpu_di <= X"00";        -- 
            when X"000F" => cpu_di <= X"ED";        -- LDI              CYCLE = 16
            when X"0010" => cpu_di <= X"A0";        -- 
            when X"0011" => cpu_di <= X"ED";        -- LDI              CYCLE = 16
            when X"0012" => cpu_di <= X"A0";        -- 

            when others  => cpu_di <= X"00";        -- NOP              CYCLE = 8
        end case;

    end process;

    -- ----------------------------------------------------- --
    --  test bench                                           --
    -- ----------------------------------------------------- --
    process
    begin
        -- init
        cpu_wait_n      <= '1';
        cpu_irq_n       <= '1';
        cpu_nmi_n       <= '1';
        cpu_busreq_n    <= '1';

        -- reset
        reset_n    <= '0';
        wait until( rising_edge(clock_enable) );
        wait until( rising_edge(clock_enable) );
        reset_n    <= '1';
        wait until( rising_edge(clock_enable) );

        for i in 0 to 95 loop
            wait until( rising_edge(clock_enable) );
        end loop;

        cpu_busreq_n <= '0';
        wait until( rising_edge(clock_enable) );
        wait until( rising_edge(clock_enable) );
        wait until( rising_edge(clock_enable) );
        cpu_busreq_n <= '1';

        for i in 0 to 8 loop
            wait until( rising_edge(clock_enable) );
        end loop;

        -- wait
        tb_end <= '1';
        wait;
    end process;

end architecture;
