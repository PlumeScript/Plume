@echo off
chcp 65001 >nul
setlocal
    luajit "%~dp0plume-data\cli\init.lua" "%~dp0\" %*
endlocal
exit /b %errorlevel%