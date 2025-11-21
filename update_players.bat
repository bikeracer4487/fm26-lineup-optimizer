@echo off
REM ============================================================================
REM Update Player Data from FM26 Players.xlsx
REM ============================================================================
REM This batch file:
REM 1. Extracts data from FM26 Players.xlsx to CSV files using data_manager.py
REM 2. Runs the match-ready team selector (optional/informational)
REM ============================================================================

echo.
echo ============================================================================
echo FM26 Lineup Optimizer - Player Data Update
echo ============================================================================
echo.

REM Step 1: Update CSV files from Excel using new Data Manager
echo Updating player data using data_manager.py...
echo.

python data_manager.py

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
