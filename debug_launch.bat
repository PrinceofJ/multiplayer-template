@echo off
REM Launches multiple Godot instances for local multiplayer testing.
REM Usage: debug_launch.bat [num_players]
REM   num_players: 2-4 (default: 2)
REM
REM Set GODOT_PATH environment variable if 'godot' is not in your PATH.

set NUM_PLAYERS=%1
if "%NUM_PLAYERS%"=="" set NUM_PLAYERS=2

if not defined GODOT_PATH set GODOT_PATH=godot

echo Launching %NUM_PLAYERS% instances...
echo Godot: %GODOT_PATH%
echo Project: %~dp0
echo.

REM Launch server (player 1)
echo Starting server (Player 1)...
start "" "%GODOT_PATH%" --path "%~dp0." -- --server

timeout /t 1 /nobreak >nul

REM Launch clients (players 2-N)
set /a CLIENTS=%NUM_PLAYERS%-1
for /L %%i in (1,1,%CLIENTS%) do (
    set /a PLAYER_NUM=%%i+1
    echo Starting client...
    start "" "%GODOT_PATH%" --path "%~dp0." -- --client
    timeout /t 1 /nobreak >nul
)

echo.
echo All %NUM_PLAYERS% instances launched.
