@echo off
REM Set working directory to the batch file's location (fixes admin mode)
cd /d "%~dp0"

REM ============================================================================
REM FMRTE to Excel Automation - Import Player Data from FMRTE
REM ============================================================================
REM This batch file:
REM 1. Connects to FMRTE (Football Manager Real Time Editor)
REM 2. Copies data from Brixham, Brixham U21, and Brixham U18 tabs
REM 3. Pastes all data into FM26 Players.xlsx (Paste Full sheet)
REM 4. Automatically runs update_player_data.py to generate CSV files
REM 5. Your player data is now ready for the team selector scripts!
REM ============================================================================

echo.
echo ============================================================================
echo FM26 Lineup Optimizer - FMRTE Data Import
echo ============================================================================
echo.
echo IMPORTANT: Before running this script, make sure:
echo   - FMRTE is open with Brixham squads loaded
echo   - FM26 Players.xlsx is closed (not open in Excel)
echo   - Run this batch file AS ADMINISTRATOR (right-click ^> Run as administrator)
echo.
pause

echo.
echo ============================================================================
echo Automating FMRTE data copy to Excel...
echo ============================================================================
echo.

python fmrte_to_excel.py

REM Check if the Python script succeeded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================================================
    echo ERROR: FMRTE automation failed!
    echo ============================================================================
    echo.
    echo Troubleshooting tips:
    echo   - Make sure FMRTE window is open and visible
    echo   - RIGHT-CLICK this batch file and select "Run as administrator"
    echo   - Verify the window title contains "FMRTE"
    echo   - Ensure Python dependencies are installed: pip install -r requirements.txt
    echo   - Check that FM26 Players.xlsx exists and is not open in Excel
    echo   - Try: python fmrte_to_excel.py --debug
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo Process Complete - Player Data Updated!
echo ============================================================================
echo.
echo Next steps:
echo   - Run update_players_match.bat to select match-ready team
echo   - Run update_players_training.bat for training team selection
echo.
pause
