@echo off
chcp 65001 >nul
setlocal
    %~dp0luajit "%~dp0plume-data\cli\init.lua" "%~dp0\" %*
endlocal
exit /b %errorlevel%