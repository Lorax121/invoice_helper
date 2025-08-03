@echo off
echo --- Starting Invoice Helper Build ---

REM --- 0. Определяем пути ---
set "REPO_ROOT=%~dp0.."
set "RELEASE_DIR=%REPO_ROOT%\release"
set "FRONTEND_DIR=%REPO_ROOT%\frontend"
set "BACKEND_DIR=%REPO_ROOT%\backend"
set "TESSERACT_DIR=C:\Program Files\Tesseract-OCR"  Путь, куда вы установили Tesseract-OCR

REM --- 1. Проверка зависимостей ---
echo Checking for Tesseract...
if not exist "%TESSERACT_DIR%\tesseract.exe" (
    echo Tesseract not found at %TESSERACT_DIR%
    echo Please install Tesseract OCR and update the path in this script if necessary.
    pause
    exit /b 1
)

REM --- 2. Очистка старой сборки ---
if exist "%RELEASE_DIR%" (
    echo Cleaning up old release directory...
    rmdir /s /q "%RELEASE_DIR%"
)
mkdir "%RELEASE_DIR%"
mkdir "%RELEASE_DIR%\backend"
mkdir "%RELEASE_DIR%\backend\tesseract"

REM --- 3. Сборка Backend (Python) ---
echo Building Backend...
cd "%BACKEND_DIR%"
py -3.9 -m venv venv
call venv\Scripts\activate.bat
pip install -r requirements.txt
pyinstaller parser.spec
deactivate

REM --- 4. Сборка Frontend (Flutter) ---
echo Building Frontend...
cd "%FRONTEND_DIR%"
flutter build windows

REM --- 5. Компоновка релизной папки ---
echo Assembling release files...

REM Копируем бинарники Flutter
xcopy "%FRONTEND_DIR%\build\windows\x64\runner\Release\*" "%RELEASE_DIR%\" /E /I /Y

REM Копируем скомпилированный Backend
copy "%BACKEND_DIR%\dist\parser.exe" "%RELEASE_DIR%\backend\parser.exe"

REM Копируем Tesseract
echo Copying Tesseract files...
xcopy "%TESSERACT_DIR%\*" "%RELEASE_DIR%\backend\tesseract\" /E /I /Y

echo --- Build Complete! ---
echo The application is ready in the 'release' folder.
pause