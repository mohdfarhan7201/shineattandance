@echo off
echo ==============================================
echo    Building Shine Attendance APK...
echo ==============================================
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
cd /d "%~dp0android"
call gradlew.bat assembleDebug
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==============================================
    echo    BUILD SUCCESSFUL!
    echo ==============================================
    copy /y "app\build\outputs\apk\debug\app-debug.apk" "..\ShineAttendance.apk"
    echo APK has been updated at: ShineAttendance.apk
) else (
    echo.
    echo [ERROR] Build failed.
)
pause
