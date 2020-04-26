vlib work
IF ERRORLEVEL 1 GOTO error

vcom ..\T65_Pack.vhd
IF ERRORLEVEL 1 GOTO error

vcom ..\T65_MCode.vhd
IF ERRORLEVEL 1 GOTO error

vcom ..\T65_ALU.vhd
IF ERRORLEVEL 1 GOTO error

vcom ..\T65.vhd
IF ERRORLEVEL 1 GOTO error

vcom tb_T65.vht
IF ERRORLEVEL 1 GOTO error

vsim -t ns tb -do all.do
IF ERRORLEVEL 1 GOTO error

goto ok

:error
echo Error!
pause

:ok
