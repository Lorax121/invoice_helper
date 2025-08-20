@echo off

chcp 65001 > nul

setlocal

echo --- Starting Invoice Helper Build ---

REM --- 0. Определяем пути ---
REM %~dp0 - это путь к папке, где лежит САМ СКРИПТ (т.е. ...\invoice_helper\scripts\)

set "REPO_ROOT=%~dp0.."
set "RELEASE_DIR=%REPO_ROOT%\release"
set "FRONTEND_DIR=%REPO_ROOT%\frontend"
set "BACKEND_DIR=%REPO_ROOT%\backend"

REM Путь, куда вы установили Tesseract-OCR
set "TESSERACT_DIR=C:\Program Files\Tesseract-OCR"

REM --- 1. Проверка зависимостей ---
echo.
echo [1/5] Checking dependencies...
REM Всегда используем кавычки для путей в условиях
if not exist "%TESSERACT_DIR%\tesseract.exe" (
    echo Tesseract not found at "%TESSERACT_DIR%"
    echo Please install Tesseract OCR and update the path in this script if necessary.
    pause
    exit /b 1
)
echo Tesseract found.

REM --- 2. Очистка старой сборки ---
echo.
echo [2/5] Cleaning up old release directory...
if exist "%RELEASE_DIR%" (
    rmdir /s /q "%RELEASE_DIR%"
)
mkdir "%RELEASE_DIR%"
mkdir "%RELEASE_DIR%\backend"
mkdir "%RELEASE_DIR%\backend\tesseract"
echo Cleanup complete.

REM --- 3. Сборка Backend (Python) ---
echo.
echo [3/5] Building Backend...
cd /d "%BACKEND_DIR%"
if errorlevel 1 (
    echo Failed to change directory to %BACKEND_DIR%
    pause
    exit /b 1
)

echo Creating virtual environment...
py -3.9 -m venv venv
if not exist "venv\Scripts\activate.bat" (
    echo Failed to create Python virtual environment.
    pause
    exit /b 1
)

echo Activating venv and installing requirements...
call venv\Scripts\activate.bat
pip install -r requirements.txt

echo Running PyInstaller...
pyinstaller parser.spec
if not exist "dist\parser.exe" (
    echo PyInstaller failed to create parser.exe
    pause
    exit /b 1
)

call deactivate
echo Backend build complete.

REM --- 4. Сборка Frontend (Flutter) ---
echo.
echo [4/5] Building Frontend...
cd /d "%FRONTEND_DIR%"
if errorlevel 1 (
    echo Failed to change directory to %FRONTEND_DIR%
    pause
    exit /b 1
)

call flutter build windows

REM --- 5. Компоновка релизной папки ---
echo.
echo [5/5] Assembling release files...

REM Копируем бинарники Flutter
echo Copying Flutter binaries...
xcopy "%FRONTEND_DIR%\build\windows\x64\runner\Release\*" "%RELEASE_DIR%\" /E /I /Y /Q

REM Копируем скомпилированный Backend
echo Copying Backend executable...
copy "%BACKEND_DIR%\dist\parser.exe" "%RELEASE_DIR%\backend\parser.exe"

REM Копируем Tesseract
echo Copying Tesseract files...
xcopy "%TESSERACT_DIR%\*" "%RELEASE_DIR%\backend\tesseract\" /E /I /Y /Q

echo.
echo --- Build Complete! ---
echo The application is ready in the 'release' folder.
pause

endlocal