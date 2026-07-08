@echo off
chcp 65001 >nul
setlocal
    %~dp0\bin\luajit "%~dp0plume-data\cli\init.lua" "%~dp0\" %*
endlocal
exit /b %errorlevel%