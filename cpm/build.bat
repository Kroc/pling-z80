@ECHO OFF
CLS & TITLE Building ezOS CP/M...
CD %~dp0
ECHO:

SET "BIN_DIR=bin"

REM # the assembler and linker is WLA-DX
SET WLA_Z80="%BIN_DIR%\wla-dx\wla-z80.exe"  -x -I "src"
SET WLA_LINK="%BIN_DIR%\wla-dx\wlalink.exe" -A -S

REM # RunCPM "emulator"
SET "CPM_DIR=%BIN_DIR%\RunCPM"
SET RUN_CPM="%CPM_DIR%\RunCPM.exe"

%WLA_Z80% -v ^
    -o "build\ezos.o" ^
       "boot.wla"

IF ERRORLEVEL 1 EXIT /B 1

%WLA_LINK% -v -b ^
    "link_cpm.ini" ^
    "build\ez80.com"

IF ERRORLEVEL 1 EXIT /B 1

REM # copy the COM file into the CP/M disk directory
REM # "/N" forces an 8.3 filename in the destination
COPY /N /Y "build\ez80.com" /B "%CPM_DIR%\A\0" /B

START "RunCPM" /D "%CPM_DIR%" %RUN_CPM%