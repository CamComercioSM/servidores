@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Iniciador generico de proyectos Laravel para Windows
rem
rem Uso normal:
rem   - Copiar este BAT a la raiz del proyecto y ejecutarlo.
rem
rem Uso centralizado:
rem   iniciar-repo-serve-yarn.bat --project "C:\ruta\proyecto" --port 8030
rem
rem Por defecto Laravel y Vite escuchan en 0.0.0.0 para permitir acceso desde
rem otros equipos de la LAN. El navegador local se abre usando 127.0.0.1.
rem ============================================================================

set "PROJECT_DIR=%~dp0"
set "APP_HOST=0.0.0.0"
set "OPEN_BROWSER=1"
set "CHECK_DATABASE=1"
set "STRICT_DB_CHECK=0"
set "HAS_FRONTEND=0"
set "FRONTEND_MANAGER="
set "FRONTEND_COMMAND="
set "FRONTEND_INSTALL_COMMAND="
set "APP_NAME="
set "APP_PORT="
set "APP_KEY_VALUE="
set "LARAVEL_VERSION="
set "LAN_IP="
set "LAN_URL="
set "LOCAL_URL="
set "RUNTIME_APP_URL="
set "NAME_FROM_ARGUMENT=0"
set "PORT_FROM_ARGUMENT=0"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--help" goto :help

if /I "%~1"=="--project" (
  if "%~2"=="" goto :usage_error
  for %%I in ("%~2") do set "PROJECT_DIR=%%~fI"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--name" (
  if "%~2"=="" goto :usage_error
  set "APP_NAME=%~2"
  set "NAME_FROM_ARGUMENT=1"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--host" (
  if "%~2"=="" goto :usage_error
  set "APP_HOST=%~2"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--port" (
  if "%~2"=="" goto :usage_error
  set "APP_PORT=%~2"
  set "PORT_FROM_ARGUMENT=1"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--no-browser" (
  set "OPEN_BROWSER=0"
  shift
  goto :parse_args
)

if /I "%~1"=="--skip-db-check" (
  set "CHECK_DATABASE=0"
  shift
  goto :parse_args
)

if /I "%~1"=="--strict-db-check" (
  set "CHECK_DATABASE=1"
  set "STRICT_DB_CHECK=1"
  shift
  goto :parse_args
)

echo [ERROR] Parametro no reconocido: %~1
goto :usage_error

:args_done
if not exist "%PROJECT_DIR%" (
  echo [ERROR] La ruta del proyecto no existe: "%PROJECT_DIR%"
  goto :error
)

cd /d "%PROJECT_DIR%"
if errorlevel 1 (
  echo [ERROR] No fue posible acceder al proyecto: "%PROJECT_DIR%"
  goto :error
)

rem ------------------------------------------------------------
rem 1. Estructura minima y .env
rem ------------------------------------------------------------
if not exist artisan (
  echo [ERROR] No se encontro artisan en %CD%.
  echo Ejecuta el BAT desde la raiz de Laravel o usa --project RUTA.
  goto :error
)

if not exist composer.json (
  echo [ERROR] No se encontro composer.json.
  goto :error
)

if not exist .env (
  if exist .env.example (
    echo [INFO] Creando .env desde .env.example...
    copy /y .env.example .env >nul
    if errorlevel 1 goto :error
  ) else (
    echo [ERROR] No existe .env ni .env.example.
    goto :error
  )
)

rem ------------------------------------------------------------
rem 2. Nombre y puerto del proyecto
rem ------------------------------------------------------------
if "%NAME_FROM_ARGUMENT%"=="0" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="APP_NAME" if not defined APP_NAME set "APP_NAME=%%B"
  )
)

if defined APP_NAME (
  set "APP_NAME=!APP_NAME:"=!"
  if "!APP_NAME:~0,1!"=="'" if "!APP_NAME:~-1!"=="'" set "APP_NAME=!APP_NAME:~1,-1!"
)

if not defined APP_NAME for %%I in ("%CD%") do set "APP_NAME=%%~nxI"

if "%PORT_FROM_ARGUMENT%"=="0" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="APP_PORT" if not defined APP_PORT set "APP_PORT=%%B"
  )
)

if not defined APP_PORT set "APP_PORT=8000"
set "APP_PORT=!APP_PORT:"=!"

where powershell >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PowerShell no esta disponible en el PATH.
  goto :error
)

powershell -NoProfile -Command "$p=0; if(-not [int]::TryParse('!APP_PORT!',[ref]$p)){exit 1}; if($p -lt 1 -or $p -gt 65535){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Puerto invalido: !APP_PORT!
  goto :error
)

title !APP_NAME! - Verificacion de entorno

echo ============================================
echo       !APP_NAME! - Inicio local/LAN
echo ============================================
echo Proyecto: %CD%
echo Bind:     !APP_HOST!
echo Puerto:   !APP_PORT!
echo.

rem ------------------------------------------------------------
rem 3. PHP, Composer y dependencias
rem ------------------------------------------------------------
where php >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PHP no esta disponible en el PATH.
  goto :error
)
for /f "delims=" %%V in ('php -r "echo PHP_VERSION;"') do set "PHP_VERSION=%%V"
echo [OK] PHP !PHP_VERSION!.

where composer >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Composer no esta disponible en el PATH.
  goto :error
)

if not exist vendor\autoload.php (
  echo [INFO] Instalando dependencias PHP con composer install...
  call composer install --no-interaction
  if errorlevel 1 (
    echo [ERROR] composer install fallo.
    echo No se ejecutara composer update automaticamente.
    goto :error
  )
)

call composer check-platform-reqs --no-interaction
if errorlevel 1 (
  echo [ERROR] El entorno no cumple los requisitos PHP del proyecto.
  goto :error
)
echo [OK] Dependencias PHP.

for /f "tokens=3" %%V in ('php artisan --version 2^>nul') do set "LARAVEL_VERSION=%%V"
if not defined LARAVEL_VERSION (
  echo [ERROR] Artisan no pudo inicializar Laravel.
  goto :error
)
echo [OK] Laravel !LARAVEL_VERSION!.

rem ------------------------------------------------------------
rem 4. APP_KEY y directorios runtime
rem ------------------------------------------------------------
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if /I "%%A"=="APP_KEY" set "APP_KEY_VALUE=%%B"
)
if not defined APP_KEY_VALUE (
  echo [INFO] Generando APP_KEY...
  php artisan key:generate --force
  if errorlevel 1 goto :error
)

if not exist storage\framework\cache mkdir storage\framework\cache >nul 2>nul
if not exist storage\framework\sessions mkdir storage\framework\sessions >nul 2>nul
if not exist storage\framework\views mkdir storage\framework\views >nul 2>nul
if not exist storage\logs mkdir storage\logs >nul 2>nul
if not exist bootstrap\cache mkdir bootstrap\cache >nul 2>nul

if not exist storage\framework\cache goto :storage_error
if not exist storage\framework\sessions goto :storage_error
if not exist storage\framework\views goto :storage_error
if not exist storage\logs goto :storage_error
if not exist bootstrap\cache goto :storage_error

echo [OK] Runtime Laravel preparado.

rem ------------------------------------------------------------
rem 5. Frontend opcional
rem ------------------------------------------------------------
if exist package.json (
  set "DEV_SCRIPT=0"
  for /f "delims=" %%V in ('powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $p=Get-Content 'package.json' -Raw ^| ConvertFrom-Json; if($p.scripts.dev){'1'}else{'0'}" 2^>nul') do set "DEV_SCRIPT=%%V"

  if "!DEV_SCRIPT!"=="1" (
    set "HAS_FRONTEND=1"

    where node >nul 2>nul
    if errorlevel 1 (
      echo [ERROR] Existe scripts.dev pero Node.js no esta disponible.
      goto :error
    )

    if exist pnpm-lock.yaml (
      set "FRONTEND_MANAGER=pnpm"
      set "FRONTEND_INSTALL_COMMAND=pnpm install"
      set "FRONTEND_COMMAND=pnpm run dev -- --host !APP_HOST!"
    ) else if exist yarn.lock (
      set "FRONTEND_MANAGER=yarn"
      set "FRONTEND_INSTALL_COMMAND=yarn install"
      set "FRONTEND_COMMAND=yarn dev --host !APP_HOST!"
    ) else if exist package-lock.json (
      set "FRONTEND_MANAGER=npm"
      set "FRONTEND_INSTALL_COMMAND=npm ci"
      set "FRONTEND_COMMAND=npm run dev -- --host !APP_HOST!"
    ) else (
      set "FRONTEND_MANAGER=npm"
      set "FRONTEND_INSTALL_COMMAND=npm install"
      set "FRONTEND_COMMAND=npm run dev -- --host !APP_HOST!"
    )

    where !FRONTEND_MANAGER! >nul 2>nul
    if errorlevel 1 (
      echo [ERROR] !FRONTEND_MANAGER! no esta disponible en el PATH.
      goto :error
    )

    if not exist node_modules (
      echo [INFO] Ejecutando !FRONTEND_INSTALL_COMMAND!...
      call !FRONTEND_INSTALL_COMMAND!
      if errorlevel 1 goto :error
    )

    echo [OK] Frontend: !FRONTEND_COMMAND!
  ) else (
    echo [INFO] package.json no tiene scripts.dev; se iniciara solo Laravel.
  )
) else (
  echo [INFO] Sin package.json; se iniciara solo Laravel.
)

rem ------------------------------------------------------------
rem 6. Cache y base de datos
rem ------------------------------------------------------------
php artisan optimize:clear >nul
if errorlevel 1 (
  echo [ERROR] No fue posible limpiar caches de Laravel.
  goto :error
)

if "!CHECK_DATABASE!"=="1" (
  php artisan migrate:status --no-interaction >nul 2>nul
  if errorlevel 1 (
    if "!STRICT_DB_CHECK!"=="1" (
      echo [ERROR] No fue posible validar la base de datos.
      goto :error
    ) else (
      echo [ADVERTENCIA] No fue posible validar la base de datos; el inicio continuara.
    )
  ) else (
    echo [OK] Base de datos disponible.
  )
)

rem ------------------------------------------------------------
rem 7. Seleccionar puerto libre
rem ------------------------------------------------------------
set /a "PORT_START=!APP_PORT!"
set /a "PORT_CANDIDATE=!APP_PORT!"
set /a "PORT_MAX=!APP_PORT!+99"
if !PORT_MAX! GTR 65535 set "PORT_MAX=65535"

:find_port
powershell -NoProfile -Command "if(Get-NetTCPConnection -LocalPort !PORT_CANDIDATE! -State Listen -ErrorAction SilentlyContinue){exit 1}else{exit 0}" >nul 2>nul
if not errorlevel 1 (
  set "APP_PORT=!PORT_CANDIDATE!"
  goto :port_ready
)
if !PORT_CANDIDATE! GEQ !PORT_MAX! goto :port_error
set /a "PORT_CANDIDATE+=1"
goto :find_port

:port_ready
if not "!APP_PORT!"=="!PORT_START!" echo [ADVERTENCIA] Puerto !PORT_START! ocupado; se utilizara !APP_PORT!.

rem ------------------------------------------------------------
rem 8. URLs local y LAN
rem ------------------------------------------------------------
if "!APP_HOST!"=="0.0.0.0" (
  set "LOCAL_URL=http://127.0.0.1:!APP_PORT!"

  for /f "delims=" %%I in ('powershell -NoProfile -Command "$c=Get-NetIPConfiguration ^| Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.IPv4Address -ne $null} ^| Select-Object -First 1; if($c){$c.IPv4Address.IPAddress}" 2^>nul') do if not defined LAN_IP set "LAN_IP=%%I"

  if defined LAN_IP (
    set "LAN_URL=http://!LAN_IP!:!APP_PORT!"
    set "RUNTIME_APP_URL=!LAN_URL!"
  ) else (
    set "RUNTIME_APP_URL=!LOCAL_URL!"
  )
) else (
  set "LOCAL_URL=http://!APP_HOST!:!APP_PORT!"
  set "RUNTIME_APP_URL=!LOCAL_URL!"
)

echo.
echo ============================================
echo       Entorno validado correctamente
echo ============================================
echo Proyecto: !APP_NAME!
echo Laravel:  !LARAVEL_VERSION!
echo Escucha:  http://!APP_HOST!:!APP_PORT!
echo Local:    !LOCAL_URL!
if defined LAN_URL echo LAN:      !LAN_URL!
if "!HAS_FRONTEND!"=="1" echo Frontend: !FRONTEND_COMMAND!
echo.

rem ------------------------------------------------------------
rem 9. Iniciar Laravel y frontend
rem ------------------------------------------------------------
echo [INFO] Iniciando Laravel en !APP_HOST!:!APP_PORT!...
start "!APP_NAME! Laravel" cmd /k "cd /d ""%CD%"" && set ""APP_PORT=!APP_PORT!"" && set ""APP_URL=!RUNTIME_APP_URL!"" && php artisan serve --host=!APP_HOST! --port=!APP_PORT!"

if "!HAS_FRONTEND!"=="1" (
  echo [INFO] Iniciando frontend accesible desde la LAN...
  start "!APP_NAME! Frontend" cmd /k "cd /d ""%CD%"" && set ""APP_PORT=!APP_PORT!"" && set ""APP_URL=!RUNTIME_APP_URL!"" && !FRONTEND_COMMAND!"
)

powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 20; $i++){ if(Get-NetTCPConnection -LocalPort !APP_PORT! -State Listen -ErrorAction SilentlyContinue){$ok=$true; break}; Start-Sleep -Seconds 1 }; if(-not $ok){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Laravel no confirmo escucha en el puerto !APP_PORT!.
  goto :error
)

echo [OK] Laravel iniciado.
if defined LAN_URL echo [INFO] Otros equipos de la LAN pueden usar: !LAN_URL!
if defined LAN_URL echo [INFO] Si no responde, revisa el Firewall de Windows para el puerto !APP_PORT!.

if "!OPEN_BROWSER!"=="1" start "" "!LOCAL_URL!"

echo.
echo !APP_NAME! disponible localmente en !LOCAL_URL!.
if defined LAN_URL echo !APP_NAME! disponible en la LAN en !LAN_URL!.
endlocal
exit /b 0

:port_error
echo [ERROR] No se encontro un puerto libre entre !PORT_START! y !PORT_MAX!.
goto :error

:storage_error
echo [ERROR] No fue posible preparar storage o bootstrap\cache.
goto :error

:usage_error
echo [ERROR] Parametros incompletos o invalidos.
echo Usa %~nx0 --help para ver la ayuda.
goto :error

:help
echo Iniciador generico de proyectos Laravel para Windows
echo.
echo Uso:
echo   %~nx0 [opciones]
echo.
echo Opciones:
echo   --project RUTA       Ruta del proyecto Laravel.
echo   --name NOMBRE        Nombre mostrado en consola.
echo   --host HOST          Host de escucha. Predeterminado: 0.0.0.0.
echo   --port PUERTO        Puerto preferido. Predeterminado: APP_PORT o 8000.
echo   --no-browser         No abrir navegador local.
echo   --skip-db-check      Omitir validacion de base de datos.
echo   --strict-db-check    Fallar si migrate:status no funciona.
echo   --help               Mostrar esta ayuda.
echo.
echo Ejemplo COPMAR:
echo   %~nx0 --project "C:\Desarrollo\COPMAR" --port 8030
echo.
echo Resultado predeterminado:
echo   Laravel: php artisan serve --host=0.0.0.0 --port=PUERTO
echo   Local:   http://127.0.0.1:PUERTO
echo   LAN:     http://IP_DEL_PC:PUERTO
echo.
endlocal
exit /b 0

:error
echo.
echo ============================================
echo        El proyecto NO fue iniciado
echo ============================================
echo Corrige el error indicado y vuelve a ejecutar este archivo.
echo.
pause
endlocal
exit /b 1
