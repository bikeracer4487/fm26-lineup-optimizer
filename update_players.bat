@echo off
REM ============================================================================
REM Update Player Data from FM26 Players.xlsx
REM ============================================================================
REM This batch file:
REM 1. Extracts data from FM26 Players.xlsx to CSV files
REM 2. Runs the match-ready team selector
REM ============================================================================

echo.
echo ============================================================================
echo FM26 Lineup Optimizer - Player Data Update
echo ============================================================================
echo.

REM Step 1: Update CSV files from Excel
echo Updating player CSV files from FM26 Players.xlsx...
echo.

python update_player_data.py

REM Check if the Python script succeeded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================================================
    echo ERROR: Failed to update player data!
    echo ============================================================================
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo Process Complete
echo ============================================================================
echo.
pause
