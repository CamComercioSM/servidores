@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Nombre: clonar-bases-sicam-produccion-local.bat
rem Estado: experimental
rem Proposito: Reemplazar las bases SICAM locales por una copia logica de produccion.
rem Alcance: Bases sicam_* definidas en DATABASES. No modifica bases de sistema MariaDB/MySQL.
rem Requisitos: mariadb.exe, mariadb-dump.exe y archivos de configuracion externos al repositorio.
rem Parametros: --dry-run, --validate, --schema-only, --full, --yes, --prod-config RUTA, --local-config RUTA.
rem Impacto: Destructivo sobre las bases locales listadas; el dump contiene DROP DATABASE y CREATE DATABASE.
rem Tolerancia: Si falla una tabla durante la importacion, continua con las siguientes sentencias; si falla una base, continua con la siguiente base.
rem Reversion: Restaurar un respaldo local previo si se requiere recuperar el estado anterior.
rem Evidencia: Salida de consola y resumen final de bases correctas, parciales y fallidas.
rem Responsable: Gestion de TI - Camara de Comercio de Santa Marta para el Magdalena.
rem Jira: CE-746

set "SCRIPT_NAME=%~nx0"
set "CONFIG_DIR=%APPDATA%\SICAM\database-clone"
set "PROD_CONFIG=%CONFIG_DIR%\produccion.cnf"
set "LOCAL_CONFIG=%CONFIG_DIR%\local.cnf"
set "DB_CLIENT=mariadb"
set "DB_DUMP=mariadb-dump"
set "PROD_TLS_OPTION=--disable-ssl-verify-server-cert"
set "DRY_RUN=0"
set "VALIDATE_ONLY=0"
set "AUTO_YES=0"
set "CLONE_MODE=full"
set "DUMP_DATA_OPTION="
set /a TOTAL_DATABASES=0
set /a SUCCESS_DATABASES=0
set /a PARTIAL_DATABASES=0
set /a FAILED_DATABASES=0
set "PARTIAL_LIST="
set "FAILED_LIST="

set "DATABASES=sicam_aplicaciones sicam_apps sicam_citurcam sicam_comercial sicam_datospersonales sicam_historia sicam_logs sicam_maestras sicam_modelodatos sicam_planeador sicam_principal sicam_registros sicam_robots sicam_saladescanso sicam_seguridad sicam_servicios sicam_talentohumano sicam_tejidoempresarial sicam_warehouse"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto parse_args
)
if /I "%~1"=="--validate" (
    set "VALIDATE_ONLY=1"
    shift
    goto parse_args
)
if /I "%~1"=="--schema-only" (
    set "CLONE_MODE=schema-only"
    set "DUMP_DATA_OPTION=--no-data"
    shift
    goto parse_args
)
if /I "%~1"=="--full" (
    set "CLONE_MODE=full"
    set "DUMP_DATA_OPTION="
    shift
    goto parse_args
)
if /I "%~1"=="--yes" (
    set "AUTO_YES=1"
    shift
    goto parse_args
)
if /I "%~1"=="--prod-config" (
    if "%~2"=="" goto invalid_args
    set "PROD_CONFIG=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--local-config" (
    if "%~2"=="" goto invalid_args
    set "LOCAL_CONFIG=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
goto invalid_args

:args_done
call :resolve_commands
if errorlevel 1 exit /b 10

if not exist "%PROD_CONFIG%" (
    call :error "No existe el archivo de configuracion de produccion: %PROD_CONFIG%"
    exit /b 30
)
if not exist "%LOCAL_CONFIG%" (
    call :error "No existe el archivo de configuracion local: %LOCAL_CONFIG%"
    exit /b 30
)

call :log "Cliente MariaDB: %DB_CLIENT%"
call :log "Dump MariaDB: %DB_DUMP%"
call :log "Configuracion origen: %PROD_CONFIG%"
call :log "Configuracion destino: %LOCAL_CONFIG%"
call :log "Modo de clonacion: %CLONE_MODE%"
call :log "Bases que seran reemplazadas: %DATABASES%"

if "%DRY_RUN%"=="1" (
    call :log "Modo simulacion: no se conectara, exportara, eliminara ni importara ninguna base."
    exit /b 0
)

call :validate_connections
if errorlevel 1 exit /b 30

if "%VALIDATE_ONLY%"=="1" (
    call :log "Validacion finalizada correctamente. No se realizo ninguna clonacion."
    exit /b 0
)

if "%AUTO_YES%"=="1" goto confirmed

echo.
echo ADVERTENCIA: esta operacion reemplazara por completo las bases SICAM locales listadas.
if /I "%CLONE_MODE%"=="schema-only" (
    echo Se copiaran solamente estructuras, vistas, triggers, rutinas y eventos. NO se copiaran datos.
) else (
    echo Se copiaran estructuras, vistas, triggers, rutinas, eventos y TODOS los datos.
)
echo Si una tabla o sentencia falla durante la importacion, se registrara el error y se continuara.
echo Si una base no puede exportarse o importarse, se continuara con la siguiente base.
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

call :log "Inicio de clonacion en modo %CLONE_MODE%."

for %%D in (%DATABASES%) do (
    set /a TOTAL_DATABASES+=1
    call :clone_database "%%D"
    set "CLONE_RESULT=!ERRORLEVEL!"

    if "!CLONE_RESULT!"=="0" (
        set /a SUCCESS_DATABASES+=1
    ) else if "!CLONE_RESULT!"=="2" (
        set /a PARTIAL_DATABASES+=1
        set "PARTIAL_LIST=!PARTIAL_LIST! %%D"
    ) else (
        set /a FAILED_DATABASES+=1
        set "FAILED_LIST=!FAILED_LIST! %%D"
    )
)

call :print_summary
rd /s /q "%TEMP_DIR%" >nul 2>&1

if %FAILED_DATABASES% GTR 0 exit /b 40
if %PARTIAL_DATABASES% GTR 0 exit /b 41
exit /b 0

:resolve_commands
where mariadb >nul 2>&1
if not errorlevel 1 set "DB_CLIENT=mariadb"
where mariadb-dump >nul 2>&1
if not errorlevel 1 set "DB_DUMP=mariadb-dump"

if exist "%ProgramFiles%\MariaDB 12.3\bin\mariadb.exe" if exist "%ProgramFiles%\MariaDB 12.3\bin\mariadb-dump.exe" (
    if "%DB_CLIENT%"=="mariadb" (
        where mariadb >nul 2>&1
        if errorlevel 1 set "DB_CLIENT=%ProgramFiles%\MariaDB 12.3\bin\mariadb.exe"
    )
    if "%DB_DUMP%"=="mariadb-dump" (
        where mariadb-dump >nul 2>&1
        if errorlevel 1 set "DB_DUMP=%ProgramFiles%\MariaDB 12.3\bin\mariadb-dump.exe"
    )
)

if "%DB_CLIENT%"=="mariadb" (
    where mariadb >nul 2>&1
    if errorlevel 1 (
        call :error "No se encontro mariadb.exe en PATH ni en la ruta conocida de MariaDB 12.3."
        exit /b 1
    )
) else if not exist "%DB_CLIENT%" (
    call :error "No se encontro el cliente MariaDB: %DB_CLIENT%"
    exit /b 1
)

if "%DB_DUMP%"=="mariadb-dump" (
    where mariadb-dump >nul 2>&1
    if errorlevel 1 (
        call :error "No se encontro mariadb-dump.exe en PATH ni en la ruta conocida de MariaDB 12.3."
        exit /b 1
    )
) else if not exist "%DB_DUMP%" (
    call :error "No se encontro mariadb-dump: %DB_DUMP%"
    exit /b 1
)
exit /b 0

:validate_connections
call :log "Validando acceso al servidor de produccion."
"%DB_CLIENT%" --defaults-extra-file="%PROD_CONFIG%" %PROD_TLS_OPTION% --batch --skip-column-names -e "SELECT VERSION(), CURRENT_USER();" 2>&1
if errorlevel 1 (
    call :error "No fue posible conectar con la configuracion de produccion."
    exit /b 1
)

call :log "Validando acceso al servidor MariaDB local."
"%DB_CLIENT%" --defaults-extra-file="%LOCAL_CONFIG%" --batch --skip-column-names -e "SELECT VERSION(), CURRENT_USER();" 2>&1
if errorlevel 1 (
    call :error "No fue posible conectar con la configuracion local."
    exit /b 1
)

call :log "Validando existencia de las bases requeridas en produccion."
for %%D in (%DATABASES%) do (
    "%DB_CLIENT%" --defaults-extra-file="%PROD_CONFIG%" %PROD_TLS_OPTION% --batch --skip-column-names -e "USE `%%D`; SELECT DATABASE();" >nul 2>&1
    if errorlevel 1 (
        call :error "La base %%D no fue encontrada en produccion o no es accesible para el usuario configurado."
        exit /b 1
    )
    call :log "Base %%D disponible en produccion."
)
exit /b 0

:clone_database
set "DB_NAME=%~1"
set "DUMP_FILE=%TEMP_DIR%\%DB_NAME%.sql"
set "DUMP_ERROR_FILE=%TEMP_DIR%\%DB_NAME%-dump-errors.log"
set "IMPORT_ERROR_FILE=%TEMP_DIR%\%DB_NAME%-import-errors.log"

call :log "Exportando %DB_NAME% desde produccion en modo %CLONE_MODE%."
"%DB_DUMP%" --defaults-extra-file="%PROD_CONFIG%" %PROD_TLS_OPTION% --databases "%DB_NAME%" --add-drop-database --single-transaction --quick --routines --events --triggers --hex-blob --default-character-set=utf8mb4 --no-tablespaces %DUMP_DATA_OPTION% > "%DUMP_FILE%" 2> "%DUMP_ERROR_FILE%"
if errorlevel 1 (
    call :error "Fallo la exportacion de %DB_NAME%. Se omitira esta base y se continuara con la siguiente."
    if exist "%DUMP_ERROR_FILE%" type "%DUMP_ERROR_FILE%"
    del /q "%DUMP_FILE%" "%DUMP_ERROR_FILE%" >nul 2>&1
    exit /b 1
)

for %%F in ("%DUMP_FILE%") do if %%~zF LEQ 0 (
    call :error "El dump de %DB_NAME% fue generado vacio. Se omitira esta base y se continuara con la siguiente."
    del /q "%DUMP_FILE%" "%DUMP_ERROR_FILE%" >nul 2>&1
    exit /b 1
)

del /q "%DUMP_ERROR_FILE%" >nul 2>&1
call :log "Ejecutando automaticamente el SQL de %DB_NAME% sobre el servidor local."
"%DB_CLIENT%" --defaults-extra-file="%LOCAL_CONFIG%" --default-character-set=utf8mb4 --force < "%DUMP_FILE%" 2> "%IMPORT_ERROR_FILE%"
set "IMPORT_EXIT_CODE=!ERRORLEVEL!"

set "HAS_SQL_ERRORS=0"
if exist "%IMPORT_ERROR_FILE%" (
    findstr /B /C:"ERROR " "%IMPORT_ERROR_FILE%" >nul 2>&1
    if not errorlevel 1 set "HAS_SQL_ERRORS=1"
)

if not "!IMPORT_EXIT_CODE!"=="0" set "HAS_SQL_ERRORS=1"

if "!HAS_SQL_ERRORS!"=="1" (
    call :error "La base %DB_NAME% fue importada parcialmente. Se encontraron errores, pero se continuo con las siguientes tablas/sentencias."
    if exist "%IMPORT_ERROR_FILE%" type "%IMPORT_ERROR_FILE%"
    del /q "%DUMP_FILE%" "%IMPORT_ERROR_FILE%" >nul 2>&1
    exit /b 2
)

del /q "%DUMP_FILE%" "%IMPORT_ERROR_FILE%" >nul 2>&1
call :log "Base %DB_NAME% clonada correctamente en modo %CLONE_MODE%."
exit /b 0

:print_summary
echo.
echo ============================================================
echo RESUMEN DE CLONACION
echo ============================================================
echo Modo:                %CLONE_MODE%
echo Bases procesadas:    !TOTAL_DATABASES!
echo Correctas:           !SUCCESS_DATABASES!
echo Parciales:           !PARTIAL_DATABASES!
echo Fallidas/omitidas:   !FAILED_DATABASES!
if !PARTIAL_DATABASES! GTR 0 echo Bases parciales:      !PARTIAL_LIST!
if !FAILED_DATABASES! GTR 0 echo Bases fallidas:       !FAILED_LIST!
echo ============================================================
if !FAILED_DATABASES! GTR 0 call :error "La clonacion termino con bases fallidas u omitidas."
if !PARTIAL_DATABASES! GTR 0 call :error "La clonacion termino con bases importadas parcialmente."
if !FAILED_DATABASES! EQU 0 if !PARTIAL_DATABASES! EQU 0 call :log "Clonacion finalizada correctamente en modo %CLONE_MODE%."
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
echo   %SCRIPT_NAME% [--schema-only ^| --full] [--dry-run ^| --validate] [--yes] [--prod-config RUTA] [--local-config RUTA]
echo.
echo Modos de clonacion:
echo   --schema-only  Reemplaza las bases locales copiando solo estructuras y objetos, sin filas de datos.
echo   --full         Reemplaza las bases locales copiando estructuras, objetos y datos. Es el modo por defecto.
echo.
echo Tolerancia a errores:
echo   Si falla una tabla o sentencia durante la importacion, mariadb --force continua con las siguientes.
echo   Si falla el dump de una base, esa base se omite y el proceso continua con la siguiente.
echo   Al terminar se muestra un resumen de bases correctas, parciales y fallidas.
echo.
echo Modos de comprobacion:
echo   --dry-run      Solo muestra configuracion y alcance. No conecta ni modifica nada.
echo   --validate     Valida conexiones y acceso a las bases. No modifica nada.
echo.
echo Valores por defecto:
echo   Produccion: %%APPDATA%%\SICAM\database-clone\produccion.cnf
echo   Local:      %%APPDATA%%\SICAM\database-clone\local.cnf
exit /b 2
