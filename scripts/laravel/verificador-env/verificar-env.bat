@echo off
setlocal

chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"

where php >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se encontro PHP en el PATH.
    echo Instale PHP CLI o agregue su carpeta al PATH y vuelva a intentar.
    exit /b 2
)

php "%SCRIPT_DIR%verificar-env.php" %*
set "EXIT_CODE=%ERRORLEVEL%"

exit /b %EXIT_CODE%
