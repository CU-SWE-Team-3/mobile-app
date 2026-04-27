@echo off
REM Flutter Fix Script for Windows
REM This script kills stuck processes and clears caches

echo.
echo ========== KILLING STUCK PROCESSES ==========
taskkill /F /IM java.exe 2>nul
taskkill /F /IM gradle.exe 2>nul
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter.exe 2>nul
timeout /t 2

echo.
echo ========== STOPPING GRADLE DAEMON ==========
cd /d "C:\Users\DELL\Downloads\mobile-app"
call gradlew --stop 2>nul

echo.
echo ========== CLEARING CACHES ==========
rmdir /s /q android\.gradle 2>nul
rmdir /s /q build 2>nul
call flutter clean

echo.
echo ========== SETTING ENVIRONMENT VARIABLES ==========
setx JAVA_HOME "C:\Program Files\Android\Android Studio\jbr"
setx ANDROID_HOME "C:\Users\DELL\AppData\Local\Android\Sdk"
setx ANDROID_SDK_ROOT "C:\Users\DELL\AppData\Local\Android\Sdk"

echo.
echo ========== DONE! ==========
echo Run these commands to verify:
echo   flutter doctor -v
echo   flutter pub get
echo   flutter run
echo.
pause
