@ECHO OFF
CLS & TITLE Building ezOS...
CD %~dp0

SET "SRC_DIR=%~dp0src"

REM # assemble!

SET "ZDS_PATH=C:\Zilog\ZDSII_eZ80Acclaim!_5.3.5"
SET "ZDS_BIN=%ZDS_PATH%\bin"
SET "ZDS_IDE=%ZDS_BIN%\Zds2Ide.exe"
SET "ZDS_ASM=%ZDS_BIN%\ez80asm.exe"
SET "ZDS_LNK=%ZDS_BIN%\ez80link.exe"

PUSHD "build"

SET ASM_FLAGS=-define:_EZ80ACCLAIM!=1 -define:_SIMULATE=1  ^
    -include:"..;%SRC_DIR%;%ZDS_PATH%\include\zilog"  ^
    -list -NOlistmac -name -pagelen:0 -pagewidth:80 -quiet -sdiopt  ^
    -warn -NOdebug -NOigcase -cpu:eZ80F92

"%ZDS_ASM%" %ASM_FLAGS% "%SRC_DIR%\init.asm"
"%ZDS_ASM%" %ASM_FLAGS% "%SRC_DIR%\main.asm"

REM # link!

IF NOT EXIST "make.linkcmd" (
    REM # use the IDE to generate the linker script
    "%ZDS_IDE%" @"%~dp0makefile.cmd
)
"%ZDS_LNK%" @make.linkcmd

"..\bin\hex2bin.exe" "hello.hex"

COPY /Y "hello.bin" /B "..\sdcard\mos\hello.bin" /B

POPD

REM # emulate!

SET EMU_BIN=agon-light-emulator.exe

PUSHD bin\emu
%EMU_BIN% --scale 1 --log-level error --sdcard ..\..\sdcard
POPD