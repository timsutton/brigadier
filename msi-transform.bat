@echo off
setlocal enableDelayedExpansion

REM Setup initial vars
set "script_path=msi-transform"
set "script_name=WiUseXfm.vbs"
set "mst_file=set_nocheck.mst"
set "bc_path=BootCamp\Drivers\Apple\BootCamp.msi"
set "this_dir=%~dp0"
set "script=!this_dir!\!script_path!\!script_name!"
set "mst=!this_dir!\!script_path!\!mst_file!"

cls
echo ###           ###
echo # MSI Transform #
echo ###           ###
echo.
if "%~1"=="" (
    echo No file given.  You must drop the Boot Camp folder onto this script.
    echo.
    echo Press [enter] to exit...
    pause > nul
    exit /b
)
echo Got "%~1"
if not exist "%~1\!bc_path!" (
    echo Could not locate "!bc_path!" in the dropped folder.
    echo.
    echo Press [enter] to exit...
    pause > nul
    exit /b
)
echo Located BootCamp.msi
if not exist "!script!" (
    echo Could not locate "!script!".
    echo.
    echo Press [enter] to exit...
    pause > nul
    exit /b
)
if not exist "!mst!" (
    echo Could not locate "!mst!".
    echo.
    echo Press [enter] to exit...
    pause > nul
    exit /b
)
echo Located script and mst.
echo Applying changes...
echo "%WINDIR%\System32\cscript.exe" "!script!" "%~1\!bc_path!" "!mst!"
"%WINDIR%\System32\cscript.exe" "!script!" "%~1\!bc_path!" "!mst!"
echo.
echo Launching with admin privs...
echo.
powershell -Command "Start-Process cmd -Verb RunAs -ArgumentList '/c """%~1\!bc_path!"""'"
echo Done.
echo.
echo Press [enter] to exit...
pause > nul
exit /b