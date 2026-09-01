@echo off
chcp 65001 >nul
setlocal
    luajit "%~dp0debug-tools\cli.lua" "%~dp0\" %*
endlocal
exit /b %errorlevel%
