@echo off
chcp 65001 > nul
setlocal

echo --- Starting Invoice Helper Build ---

REM --- 0. Определяем пути и версии ---
set "REPO_ROOT=%~dp0.."
set "RELEASE_DIR=%REPO_ROOT%\release"
set "FRONTEND_DIR=%REPO_ROOT%\frontend"
set "BACKEND_DIR=%REPO_ROOT%\backend"

REM --- Настройки внешних зависимостей ---
set "TESSERACT_DIR=C:\Program Files\Tesseract-OCR"
set "POPPLER_VERSION=25.07.0"
set "POPPLER_ZIP_FILE=Release-%POPPLER_VERSION%-0.zip"
set "POPPLER_URL=https://github.com/oschwartz10612/poppler-windows/releases/download/v%POPPLER_VERSION%-0/%POPPLER_ZIP_FILE%"
set "POPPLER_EXTRACTED_DIR_NAME=poppler-%POPPLER_VERSION%"

REM --- 1. Проверка зависимостей (Tesseract) ---
echo.
echo [1/6] Checking Tesseract dependency...
if not exist "%TESSERACT_DIR%\tesseract.exe" (
    echo Tesseract not found at "%TESSERACT_DIR%"
    echo Please install Tesseract OCR and update the path in this script if necessary.
    pause
    exit /b 1
)
echo Tesseract found.

REM --- 2. Очистка старой сборки ---
echo.
echo [2/6] Cleaning up old release directory...
if exist "%RELEASE_DIR%" (
    rmdir /s /q "%RELEASE_DIR%"
)
mkdir "%RELEASE_DIR%"
mkdir "%RELEASE_DIR%\backend"
echo Cleanup complete.

REM --- 3. Подготовка Backend зависимостей (Poppler) ---
echo.
echo [3/6] Preparing Poppler dependency...
set "POPPLER_TARGET_DIR=%BACKEND_DIR%\%POPPLER_EXTRACTED_DIR_NAME%"

if exist "%POPPLER_TARGET_DIR%\Library\bin\pdftotext.exe" (
    echo Poppler is already downloaded and extracted in the source folder.
) else (
    echo Poppler not found in source. Downloading...
    curl -L -o "%BACKEND_DIR%\%POPPLER_ZIP_FILE%" "%POPPLER_URL%"
    if errorlevel 1 (
        echo Failed to download Poppler. Please check the URL and your internet connection.
        pause
        exit /b 1
    )
    
    echo Unpacking Poppler...
    powershell -Command "Expand-Archive -Path '%BACKEND_DIR%\%POPPLER_ZIP_FILE%' -DestinationPath '%BACKEND_DIR%' -Force"
    if errorlevel 1 (
        echo Failed to unpack Poppler.
        pause
        exit /b 1
    )
    
    del "%BACKEND_DIR%\%POPPLER_ZIP_FILE%"
    echo Poppler prepared successfully in the backend source folder.
)

REM --- 4. Сборка Backend (Python) ---
echo.
echo [4/6] Building Backend...
cd /d "%BACKEND_DIR%"
if errorlevel 1 ( echo Failed to change directory to %BACKEND_DIR% & pause & exit /b 1 )

echo Creating virtual environment...
py -3.9 -m venv venv
if not exist "venv\Scripts\activate.bat" ( echo Failed to create Python virtual environment. & pause & exit /b 1 )

echo Activating venv and installing requirements...
call venv\Scripts\activate.bat
pip install -r requirements.txt

echo Running PyInstaller using parser.spec...
REM ***** ГЛАВНОЕ ИСПРАВЛЕНИЕ ЗДЕСЬ *****
REM Используем .spec файл, который уже знает, где лежит parser.py
pyinstaller parser.spec
if not exist "dist\parser.exe" ( echo PyInstaller failed to create parser.exe & pause & exit /b 1 )
call deactivate
echo Backend build complete.

REM --- 5. Сборка Frontend (Flutter) ---
echo.
echo [5/6] Building Frontend...
cd /d "%FRONTEND_DIR%"
if errorlevel 1 ( echo Failed to change directory to %FRONTEND_DIR% & pause & exit /b 1 )
call flutter build windows

REM --- 6. Компоновка релизной папки ---
echo.
echo [6/6] Assembling release files...
echo Copying Flutter binaries...
xcopy "%FRONTEND_DIR%\build\windows\x64\runner\Release\*" "%RELEASE_DIR%\" /E /I /Y /Q

echo Copying Backend executable...
copy "%BACKEND_DIR%\dist\parser.exe" "%RELEASE_DIR%\backend\parser.exe"

echo Copying Tesseract files...
mkdir "%RELEASE_DIR%\backend\tesseract"
xcopy "%TESSERACT_DIR%\*" "%RELEASE_DIR%\backend\tesseract\" /E /I /Y /Q

echo Copying Poppler files from source to release...
xcopy "%BACKEND_DIR%\%POPPLER_EXTRACTED_DIR_NAME%\*" "%RELEASE_DIR%\backend\%POPPLER_EXTRACTED_DIR_NAME%\" /E /I /Y /Q

echo.
echo --- Build Complete! ---
echo The application is ready in the 'release' folder.
pause
endlocal