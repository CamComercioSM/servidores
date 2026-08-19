@echo off
setlocal EnableExtensions

rem Nombre: clonar-bases-sicam-produccion-local.bat
rem Estado: experimental
rem Proposito: Reemplazar las bases SICAM locales por una copia logica exacta de produccion.
rem Alcance: Bases sicam_* definidas en DATABASES. No modifica bases de sistema MySQL.
rem Requisitos: mysql.exe, mysqldump.exe y dos login-path configurados con mysql_config_editor.
rem Parametros: --dry-run, --yes, --prod-login-path NOMBRE, --local-login-path NOMBRE.
rem Impacto: Destructivo sobre las bases locales listadas; el dump contiene DROP DATABASE y CREATE DATABASE.
rem Reversion: Restaurar un respaldo local previo si se requiere recuperar el estado anterior.
rem Evidencia: Salida de consola por base y codigo de salida 0 al finalizar.
rem Responsable: Gestion de TI - Camara de Comercio de Santa Marta para el Magdalena.
rem Jira: CE-746

set "SCRIPT_NAME=%~nx0"
set "PROD_LOGIN_PATH=sicam_prod"
set "LOCAL_LOGIN_PATH=sicam_local"
set "MYSQL_EXE=mysql"
set "MYSQLDUMP_EXE=mysqldump"
set "DRY_RUN=0"
set "AUTO_YES=0"

set "DATABASES=sicam_aplicaciones sicam_apps sicam_citurcam sicam_comercial sicam_datospersonales sicam_historia sicam_logs sicam_maestras sicam_modelodatos sicam_planeador sicam_principal sicam_registros sicam_robots sicam_saladescanso sicam_seguridad sicam_servicios sicam_talentohumano sicam_tejidoempresarial sicam_warehouse"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto parse_args
)
if /I "%~1"=="--yes" (
    set "AUTO_YES=1"
    shift
    goto parse_args
)
if /I "%~1"=="--prod-login-path" (
    if "%~2"=="" goto invalid_args
    set "PROD_LOGIN_PATH=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--local-login-path" (
    if "%~2"=="" goto invalid_args
    set "LOCAL_LOGIN_PATH=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
goto invalid_args

:args_done
call :require_command "%MYSQL_EXE%"
if errorlevel 1 exit /b 10
call :require_command "%MYSQLDUMP_EXE%"
if errorlevel 1 exit /b 10

call :log "Perfil origen: %PROD_LOGIN_PATH%"
call :log "Perfil destino: %LOCAL_LOGIN_PATH%"
call :log "Bases que seran reemplazadas: %DATABASES%"

if "%DRY_RUN%"=="1" (
    call :log "Modo simulacion: no se exportara, eliminara ni importara ninguna base."
    exit /b 0
)

call :log "Validando acceso al servidor de produccion."
"%MYSQL_EXE%" --login-path="%PROD_LOGIN_PATH%" --batch --skip-column-names -e "SELECT 1;" >nul 2>&1
if errorlevel 1 (
    call :error "No fue posible conectar con el login-path de produccion."
    exit /b 30
)

call :log "Validando acceso al servidor MySQL local."
"%MYSQL_EXE%" --login-path="%LOCAL_LOGIN_PATH%" --batch --skip-column-names -e "SELECT 1;" >nul 2>&1
if errorlevel 1 (
    call :error "No fue posible conectar con el login-path local."
    exit /b 30
)

if "%AUTO_YES%"=="1" goto confirmed

echo.
echo ADVERTENCIA: esta operacion reemplazara por completo las bases SICAM locales listadas.
echo No se compara el estado actual del destino y no se crea respaldo local automaticamente.
set "CONFIRMACION="
set /p "CONFIRMACION=Escriba CLONAR SICAM para continuar: "
if /I not "%CONFIRMACION%"=="CLONAR SICAM" (
    call :error "Operacion cancelada por el usuario."
    exit /b 30
)

:confirmed
set "TEMP_DIR=%TEMP%\sicam-clone-%RANDOM%-%RANDOM%"
mkdir "%TEMP_DIR%" >nul 2>&1
if errorlevel 1 (
    call :error "No fue posible crear el directorio temporal: %TEMP_DIR%"
    exit /b 40
)

call :log "Inicio de clonacion."

for %%D in (%DATABASES%) do (
    call :clone_database "%%D"
    if errorlevel 1 (
        rd /s /q "%TEMP_DIR%" >nul 2>&1
        exit /b 40
    )
)

rd /s /q "%TEMP_DIR%" >nul 2>&1
call :log "Clonacion finalizada correctamente."
exit /b 0

:clone_database
set "DB_NAME=%~1"
set "DUMP_FILE=%TEMP_DIR%\%DB_NAME%.sql"

call :log "Exportando %DB_NAME% desde produccion."
"%MYSQLDUMP_EXE%" --login-path="%PROD_LOGIN_PATH%" --databases "%DB_NAME%" --add-drop-database --single-transaction --quick --routines --events --triggers --hex-blob --default-character-set=utf8mb4 --set-gtid-purged=OFF --no-tablespaces > "%DUMP_FILE%"
if errorlevel 1 (
    del /q "%DUMP_FILE%" >nul 2>&1
    call :error "Fallo la exportacion de %DB_NAME%. El destino local no fue modificado para esta base."
    exit /b 1
)

call :log "Reemplazando %DB_NAME% en el servidor local."
"%MYSQL_EXE%" --login-path="%LOCAL_LOGIN_PATH%" --default-character-set=utf8mb4 < "%DUMP_FILE%"
if errorlevel 1 (
    del /q "%DUMP_FILE%" >nul 2>&1
    call :error "Fallo la importacion de %DB_NAME%. La base local puede haber quedado parcialmente restaurada."
    exit /b 1
)

del /q "%DUMP_FILE%" >nul 2>&1
call :log "Base %DB_NAME% clonada correctamente."
exit /b 0

:require_command
where "%~1" >nul 2>&1
if errorlevel 1 (
    call :error "No se encontro el comando requerido: %~1"
    exit /b 1
)
exit /b 0

:log
echo [%date% %time%] [%SCRIPT_NAME%] %~1
exit /b 0

:error
echo [%date% %time%] [%SCRIPT_NAME%] ERROR: %~1 1>&2
exit /b 0

:invalid_args
call :error "Parametros invalidos."

:usage
echo Uso:
echo   %SCRIPT_NAME% [--dry-run] [--yes] [--prod-login-path NOMBRE] [--local-login-path NOMBRE]
echo.
echo Valores por defecto:
echo   Produccion: sicam_prod
echo   Local:      sicam_local
exit /b 2
