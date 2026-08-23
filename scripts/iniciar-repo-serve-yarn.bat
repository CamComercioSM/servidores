@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Iniciador generico de proyectos Laravel para Windows
rem
rem Uso normal:
rem   - Copiar este BAT a la raiz del proyecto y ejecutarlo.
rem
rem Uso desde otra ubicacion:
rem   iniciar-repo-serve-yarn.bat --project "C:\ruta\proyecto" --port 8030
rem
rem Parametros opcionales:
rem   --project RUTA       Ruta de la raiz del proyecto Laravel.
rem   --name NOMBRE        Nombre mostrado en consola y ventanas.
rem   --host HOST          Host para php artisan serve. Predeterminado: 0.0.0.0.
rem   --port PUERTO        Puerto preferido. Predeterminado: APP_PORT del .env o 8000.
rem   --no-browser         No abrir el navegador al iniciar.
rem   --skip-db-check      Omitir validacion de acceso a base de datos.
rem   --strict-db-check    Detener el inicio si migrate:status falla.
rem   --help               Mostrar ayuda.
rem
rem Variables opcionales en .env:
rem   APP_NAME=Mi Proyecto
rem   APP_PORT=8030
rem
rem Si existe package.json, el frontend se inicia siempre con Yarn mediante
rem "yarn dev", igual que en la version original del script.
rem ============================================================================

set "PROJECT_DIR=%~dp0"
set "APP_HOST=0.0.0.0"
set "BROWSER_HOST=127.0.0.1"
set "OPEN_BROWSER=1"
set "CHECK_DATABASE=1"
set "STRICT_DB_CHECK=0"
set "HAS_FRONTEND=0"
set "FRONTEND_COMMAND="
set "APP_URL="
set "BROWSER_EXE="
set "BROWSER_NAME="
set "LARAVEL_VERSION="
set "APP_KEY_VALUE="
set "NAME_FROM_ARGUMENT=0"
set "PORT_FROM_ARGUMENT=0"

:parse_args
if "%~1"=="" goto :args_done

if /I "%~1"=="--help" goto :help

if /I "%~1"=="--project" (
  if "%~2"=="" (
    echo [ERROR] --project requiere una ruta.
    goto :usage_error
  )
  for %%I in ("%~2") do set "PROJECT_DIR=%%~fI"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--name" (
  if "%~2"=="" (
    echo [ERROR] --name requiere un valor.
    goto :usage_error
  )
  set "APP_NAME=%~2"
  set "NAME_FROM_ARGUMENT=1"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--host" (
  if "%~2"=="" (
    echo [ERROR] --host requiere un valor.
    goto :usage_error
  )
  set "APP_HOST=%~2"
  shift
  shift
  goto :parse_args
)

if /I "%~1"=="--port" (
  if "%~2"=="" (
    echo [ERROR] --port requiere un valor.
    goto :usage_error
  )
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
rem 1. Estructura minima y archivo de entorno
rem ------------------------------------------------------------
if not exist artisan (
  echo [ERROR] No se encontro artisan en:
  echo         %CD%
  goto :error
)

if not exist composer.json (
  echo [ERROR] No se encontro composer.json.
  goto :error
)

if not exist .env (
  if exist .env.example (
    echo [INFO] No existe .env. Creando desde .env.example...
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
if "%NAME_FROM_ARGUMENT%"=="0" if not defined APP_NAME (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="APP_NAME" set "APP_NAME=%%B"
  )
)

if defined APP_NAME (
  set "APP_NAME=!APP_NAME:\"=!"
  if "!APP_NAME:~0,1!"=="'" if "!APP_NAME:~-1!"=="'" set "APP_NAME=!APP_NAME:~1,-1!"
)

if not defined APP_NAME (
  for %%I in ("%CD%") do set "APP_NAME=%%~nxI"
)

if "%PORT_FROM_ARGUMENT%"=="0" if not defined APP_PORT (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="APP_PORT" set "APP_PORT=%%B"
  )
)

if not defined APP_PORT set "APP_PORT=8000"
set "APP_PORT=!APP_PORT:\"=!"

where powershell >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PowerShell no esta disponible en el PATH de Windows.
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
rem 3. PHP y Composer
rem ------------------------------------------------------------
where php >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PHP no esta disponible en el PATH de Windows.
  goto :error
)
for /f "delims=" %%V in ('php -r "echo PHP_VERSION;"') do set "PHP_VERSION=%%V"
echo [OK] PHP !PHP_VERSION!.

where composer >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Composer no esta disponible en el PATH de Windows.
  goto :error
)

if not exist vendor\autoload.php (
  echo [INFO] Ejecutando composer install...
  call composer install --no-interaction
  if errorlevel 1 (
    echo [ERROR] composer install fallo.
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
rem 4. APP_KEY y runtime
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
rem 5. Frontend: comportamiento original con Yarn
rem ------------------------------------------------------------
if exist package.json (
  set "HAS_FRONTEND=1"
  set "FRONTEND_COMMAND=yarn dev"

  where node >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] Node.js no esta disponible en el PATH.
    goto :error
  )

  where yarn >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] Yarn no esta disponible en el PATH.
    goto :error
  )

  for /f "delims=" %%V in ('node --version 2^>nul') do set "NODE_VERSION=%%V"
  for /f "delims=" %%V in ('yarn --version 2^>nul') do set "YARN_VERSION=%%V"
  echo [OK] Node.js !NODE_VERSION!.
  echo [OK] Yarn !YARN_VERSION!.

  if not exist node_modules\.bin\vite.cmd (
    echo [INFO] No se encontro Vite. Ejecutando yarn install...
    call yarn install
    if errorlevel 1 (
      echo [ERROR] yarn install fallo.
      goto :error
    )
  )

  if not exist node_modules\.bin\vite.cmd (
    echo [ERROR] Vite no esta disponible despues de yarn install.
    goto :error
  )

  echo [OK] Frontend: yarn dev.
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

rem 0.0.0.0 se usa para escuchar. El navegador siempre usa 127.0.0.1.
set "APP_URL=http://!BROWSER_HOST!:!APP_PORT!"

rem ------------------------------------------------------------
rem 8. Navegador de desarrollo preferido
rem ------------------------------------------------------------
if exist "%ProgramFiles%\Firefox Developer Edition\firefox.exe" (
  set "BROWSER_EXE=%ProgramFiles%\Firefox Developer Edition\firefox.exe"
  set "BROWSER_NAME=Firefox Developer Edition"
) else if exist "%ProgramFiles(x86)%\Firefox Developer Edition\firefox.exe" (
  set "BROWSER_EXE=%ProgramFiles(x86)%\Firefox Developer Edition\firefox.exe"
  set "BROWSER_NAME=Firefox Developer Edition"
) else if exist "%LOCALAPPDATA%\Google\Chrome Dev\Application\chrome.exe" (
  set "BROWSER_EXE=%LOCALAPPDATA%\Google\Chrome Dev\Application\chrome.exe"
  set "BROWSER_NAME=Google Chrome Dev"
) else if exist "%LOCALAPPDATA%\Google\Chrome SxS\Application\chrome.exe" (
  set "BROWSER_EXE=%LOCALAPPDATA%\Google\Chrome SxS\Application\chrome.exe"
  set "BROWSER_NAME=Google Chrome Canary"
)

echo.
echo ============================================
echo       Entorno validado correctamente
echo ============================================
echo Proyecto: !APP_NAME!
echo Laravel:  !LARAVEL_VERSION!
echo Escucha:  http://!APP_HOST!:!APP_PORT!
echo Local:    !APP_URL!
if "!HAS_FRONTEND!"=="1" echo Frontend: yarn dev
if defined BROWSER_NAME echo Browser:  !BROWSER_NAME!
echo.
echo Iniciando servicios...

start "!APP_NAME! Laravel" cmd /k "cd /d ""%CD%"" && php artisan serve --host=!APP_HOST! --port=!APP_PORT!"

if "!HAS_FRONTEND!"=="1" (
  start "!APP_NAME! Yarn" cmd /k "cd /d ""%CD%"" && yarn dev"
)

echo [INFO] Esperando que Laravel quede disponible...
powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 20; $i++){ if(Get-NetTCPConnection -LocalPort !APP_PORT! -State Listen -ErrorAction SilentlyContinue){$ok=$true; break}; Start-Sleep -Seconds 1 }; if(-not $ok){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Laravel no confirmo escucha en el puerto !APP_PORT!.
  goto :error
)

echo [OK] Laravel iniciado.

if "!OPEN_BROWSER!"=="1" (
  if defined BROWSER_EXE (
    start "" "!BROWSER_EXE!" "!APP_URL!"
  ) else (
    start "" "!APP_URL!"
  )
)

echo.
echo !APP_NAME! disponible localmente en !APP_URL!.
endlocal
exit /b 0

:port_error
echo [ERROR] No se encontro un puerto libre entre !PORT_START! y !PORT_MAX!.
goto :error

:storage_error
echo [ERROR] No fue posible preparar los directorios de runtime de Laravel.
echo Verifica permisos de escritura sobre storage y bootstrap\cache.
goto :error

:usage_error
echo.
echo Ejecuta este archivo con --help para ver los parametros disponibles.
goto :error

:help
echo Iniciador generico de proyectos Laravel para Windows
echo.
echo Uso:
echo   %~nx0 [opciones]
echo.
echo Opciones:
echo   --project RUTA       Ruta de la raiz del proyecto Laravel.
echo   --name NOMBRE        Nombre mostrado en consola y ventanas.
echo   --host HOST          Host para php artisan serve.
echo   --port PUERTO        Puerto preferido.
echo   --no-browser         No abrir el navegador.
echo   --skip-db-check      Omitir validacion de base de datos.
echo   --strict-db-check    Fallar si migrate:status no puede ejecutarse.
echo   --help               Mostrar esta ayuda.
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
