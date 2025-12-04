@echo off
REM ============================================================================
REM FMRTE to Excel Automation - Import Player Data from FMRTE
REM ============================================================================
REM This batch file auto-elevates to Administrator if needed
REM ============================================================================

REM Check for admin rights and self-elevate if needed
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM Set working directory to the batch file's location (fixes admin mode)
cd /d "%~dp0"

echo.
echo ============================================================================
echo FM26 Lineup Optimizer - FMRTE Data Import
echo ============================================================================
echo.
echo IMPORTANT: Before running this script, make sure:
echo   - FMRTE is open with Brixham squads loaded
echo   - FM26 Players.xlsx is closed (not open in Excel)
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
    echo   - Verify the window title contains "FMRTE"
    echo   - Ensure Python dependencies are installed: pip install -r requirements.txt
    echo   - Check that FM26 Players.xlsx exists and is not open in Excel
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
