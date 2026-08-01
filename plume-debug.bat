@echo off
chcp 65001 >nul
setlocal
    if /i "%1"=="profile-quick" (
        luajit "%~dp0debug-tools\cli.lua" "%~dp0\" %*
    ) else (
        %~dp0\bin\luajit "%~dp0debug-tools\cli.lua" "%~dp0\" %*
    )
endlocal
exit /b %errorlevel%
