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
rem   DEV_QUEUE_WORKER=true    Abre php artisan queue:work en otra consola.
rem   DEV_SCHEDULER=true       Abre php artisan schedule:work en otra consola.
rem
rem Si existe package.json, el frontend se inicia con Yarn mediante yarn dev,
rem conservando el comportamiento original del iniciador.
rem ============================================================================

set "PROJECT_DIR=%~dp0"
set "APP_HOST=0.0.0.0"
set "BROWSER_HOST=127.0.0.1"
set "OPEN_BROWSER=1"
set "CHECK_DATABASE=1"
set "STRICT_DB_CHECK=0"
set "HAS_FRONTEND=0"
set "START_QUEUE_WORKER=0"
set "START_SCHEDULER=0"
set "FRONTEND_MANAGER="
set "FRONTEND_COMMAND="
set "FRONTEND_INSTALL_COMMAND="
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
  echo Este BAT debe ejecutarse desde la raiz de un proyecto Laravel
  echo o recibir la ruta mediante --project.
  goto :error
)

if not exist composer.json (
  echo [ERROR] No se encontro composer.json.
  echo El proyecto Laravel parece estar incompleto.
  goto :error
)

if not exist composer.lock (
  echo [ADVERTENCIA] No se encontro composer.lock.
  echo               Composer resolvera versiones desde composer.json.
  echo               Para entornos controlados se recomienda versionar composer.lock.
)

if not exist .env (
  if exist .env.example (
    echo [INFO] No existe .env. Creando desde .env.example...
    copy /y .env.example .env >nul
    if errorlevel 1 (
      echo [ERROR] No fue posible crear .env.
      goto :error
    )
    echo [OK] Archivo .env creado.
  ) else (
    echo [ERROR] No existe .env ni .env.example.
    echo No es posible preparar automaticamente la configuracion local.
    goto :error
  )
) else (
  echo [OK] Archivo .env disponible.
)

rem ------------------------------------------------------------
rem 2. Nombre del proyecto, puerto y servicios opcionales
rem ------------------------------------------------------------
if "%NAME_FROM_ARGUMENT%"=="0" if not defined APP_NAME (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="APP_NAME" set "APP_NAME=%%B"
  )
)

if defined APP_NAME (
  set "APP_NAME=!APP_NAME:"=!"
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
set "APP_PORT=!APP_PORT:"=!"

set "DEV_QUEUE_WORKER_VALUE="
set "DEV_SCHEDULER_VALUE="
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if /I "%%A"=="DEV_QUEUE_WORKER" set "DEV_QUEUE_WORKER_VALUE=%%B"
  if /I "%%A"=="DEV_SCHEDULER" set "DEV_SCHEDULER_VALUE=%%B"
)
set "DEV_QUEUE_WORKER_VALUE=!DEV_QUEUE_WORKER_VALUE:"=!"
set "DEV_SCHEDULER_VALUE=!DEV_SCHEDULER_VALUE:"=!"
if /I "!DEV_QUEUE_WORKER_VALUE!"=="true" set "START_QUEUE_WORKER=1"
if "!DEV_QUEUE_WORKER_VALUE!"=="1" set "START_QUEUE_WORKER=1"
if /I "!DEV_SCHEDULER_VALUE!"=="true" set "START_SCHEDULER=1"
if "!DEV_SCHEDULER_VALUE!"=="1" set "START_SCHEDULER=1"

where powershell >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PowerShell no esta disponible en el PATH de Windows.
  echo Se requiere para validar y seleccionar el puerto local.
  goto :error
)

powershell -NoProfile -Command "$p=0; if(-not [int]::TryParse('!APP_PORT!',[ref]$p)){exit 1}; if($p -lt 1 -or $p -gt 65535){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Puerto invalido: !APP_PORT!
  goto :error
)

title !APP_NAME! - Verificacion de entorno

echo ============================================
echo       !APP_NAME! - Inicio local
echo ============================================
echo.
echo Proyecto: %CD%
echo Verificando entorno antes de iniciar...
echo.
echo [OK] Estructura basica del proyecto.

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

set "COMPOSER_VERSION="
for /f "tokens=3" %%V in ('composer --version --no-ansi 2^>nul') do if not defined COMPOSER_VERSION set "COMPOSER_VERSION=%%V"
if defined COMPOSER_VERSION (
  echo [OK] Composer !COMPOSER_VERSION!.
) else (
  echo [OK] Composer disponible.
)

rem ------------------------------------------------------------
rem 4. Dependencias PHP y requisitos reales del proyecto
rem ------------------------------------------------------------
if not exist vendor\autoload.php (
  echo [INFO] No se encontro vendor\autoload.php.
  echo [INFO] Ejecutando composer install...
  call composer install --no-interaction
  if errorlevel 1 (
    echo [ERROR] composer install fallo.
    echo Revisa la version de PHP, las extensiones requeridas y composer.lock.
    echo No se ejecutara composer update automaticamente.
    goto :error
  )
)

if not exist vendor\autoload.php (
  echo [ERROR] Las dependencias PHP siguen incompletas despues de Composer.
  goto :error
)
echo [OK] Dependencias PHP instaladas.

echo [INFO] Validando requisitos de plataforma PHP y extensiones...
call composer check-platform-reqs --no-interaction
if errorlevel 1 (
  echo [ERROR] El entorno no cumple los requisitos PHP de las dependencias instaladas.
  echo Revisa el detalle informado por Composer.
  goto :error
)
echo [OK] Requisitos de plataforma PHP.

rem ------------------------------------------------------------
rem 5. Version real de Laravel, sin imponer una version fija
rem ------------------------------------------------------------
for /f "tokens=3" %%V in ('php artisan --version 2^>nul') do set "LARAVEL_VERSION=%%V"
if not defined LARAVEL_VERSION (
  echo [ERROR] Artisan no pudo inicializar Laravel.
  goto :error
)
echo [OK] Laravel !LARAVEL_VERSION!.

rem ------------------------------------------------------------
rem 6. APP_KEY
rem ------------------------------------------------------------
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if /I "%%A"=="APP_KEY" set "APP_KEY_VALUE=%%B"
)

if not defined APP_KEY_VALUE (
  echo [INFO] APP_KEY no esta configurada. Generando llave de aplicacion...
  php artisan key:generate --force
  if errorlevel 1 (
    echo [ERROR] No fue posible generar APP_KEY.
    goto :error
  )
  echo [OK] APP_KEY generada.
) else (
  echo [OK] APP_KEY configurada.
)

rem ------------------------------------------------------------
rem 7. Directorios de runtime requeridos por Laravel
rem ------------------------------------------------------------
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
echo [OK] Directorios de runtime de Laravel.

rem ------------------------------------------------------------
rem 8. Frontend con Yarn
rem ------------------------------------------------------------
if exist package.json (
  set "HAS_FRONTEND=1"
  set "FRONTEND_MANAGER=yarn"
  set "FRONTEND_INSTALL_COMMAND=yarn install"
  set "FRONTEND_COMMAND=yarn dev"

  where node >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] El proyecto tiene frontend, pero Node.js no esta disponible.
    goto :error
  )

  for /f "delims=" %%V in ('node --version 2^>nul') do set "NODE_VERSION=%%V"
  echo [OK] Node.js !NODE_VERSION!.

  where yarn >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] Yarn no esta disponible en el PATH.
    goto :error
  )

  for /f "delims=" %%V in ('yarn --version 2^>nul') do set "YARN_VERSION=%%V"
  echo [OK] Yarn !YARN_VERSION!.

  if not exist node_modules\.bin\vite.cmd (
    echo [INFO] No se encontro Vite en node_modules.
    echo [INFO] Ejecutando yarn install...
    call yarn install
    if errorlevel 1 (
      echo [ERROR] yarn install fallo.
      goto :error
    )
  )

  if not exist node_modules\.bin\vite.cmd (
    echo [ERROR] Vite sigue sin estar disponible despues de Yarn.
    goto :error
  )

  echo [OK] Frontend detectado: yarn dev.
) else (
  echo [INFO] El proyecto no tiene package.json. Se iniciara solo Laravel.
)

rem ------------------------------------------------------------
rem 9. Configuracion Laravel y comprobacion opcional de BD
rem ------------------------------------------------------------
echo [INFO] Limpiando caches de desarrollo...
php artisan optimize:clear >nul
if errorlevel 1 (
  echo [ERROR] Laravel no pudo limpiar sus caches.
  goto :error
)
echo [OK] Caches Laravel.

if "!CHECK_DATABASE!"=="1" (
  echo [INFO] Verificando acceso a base de datos mediante migrate:status...
  php artisan migrate:status --no-interaction >nul 2>nul
  if errorlevel 1 (
    if "!STRICT_DB_CHECK!"=="1" (
      echo [ERROR] No fue posible consultar el estado de migraciones.
      echo Revisa la configuracion de base de datos en .env y el servidor de BD.
      goto :error
    ) else (
      echo [ADVERTENCIA] No fue posible validar la base de datos.
      echo               El inicio continuara. Usa --strict-db-check para bloquear ante este fallo.
    )
  ) else (
    echo [OK] Conexion de base de datos disponible.
  )
) else (
  echo [INFO] Validacion de base de datos omitida por parametro.
)

rem ------------------------------------------------------------
rem 10. Puerto Laravel: usar preferido o siguiente disponible
rem ------------------------------------------------------------
set /a "PORT_START=!APP_PORT!"
set /a "PORT_CANDIDATE=!PORT_START!"
set /a "PORT_MAX=!PORT_START!+99"
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
if not "!APP_PORT!"=="!PORT_START!" (
  echo [ADVERTENCIA] El puerto !PORT_START! estaba ocupado. Se utilizara !APP_PORT!.
) else (
  echo [OK] Puerto !APP_PORT! disponible.
)

rem 0.0.0.0 se usa solamente para escuchar. El navegador abre 127.0.0.1.
set "APP_URL=http://!BROWSER_HOST!:!APP_PORT!"

rem ------------------------------------------------------------
rem 11. Navegador de desarrollo preferido
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
echo Navegador: !APP_URL!
if defined BROWSER_NAME echo Browser:  !BROWSER_NAME!
if "!HAS_FRONTEND!"=="1" echo Frontend: !FRONTEND_COMMAND!
if "!START_QUEUE_WORKER!"=="1" echo Worker:   php artisan queue:work
if "!START_SCHEDULER!"=="1" echo Scheduler: php artisan schedule:work
echo.
echo Iniciando servicios...

start "!APP_NAME! Laravel" cmd /k "cd /d ""%CD%"" && php artisan serve --host=!APP_HOST! --port=!APP_PORT!"

if "!HAS_FRONTEND!"=="1" (
  start "!APP_NAME! Frontend" cmd /k "cd /d ""%CD%"" && yarn dev"
)

if "!START_QUEUE_WORKER!"=="1" (
  start "!APP_NAME! Queue Worker" cmd /k "cd /d ""%CD%"" && php artisan queue:work"
)

if "!START_SCHEDULER!"=="1" (
  start "!APP_NAME! Scheduler" cmd /k "cd /d ""%CD%"" && php artisan schedule:work"
)

echo [INFO] Esperando que Laravel quede disponible...
powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 20; $i++){ if(Get-NetTCPConnection -LocalPort !APP_PORT! -State Listen -ErrorAction SilentlyContinue){$ok=$true; break}; Start-Sleep -Seconds 1 }; if(-not $ok){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Laravel no confirmo escucha en el puerto !APP_PORT!.
  echo Revisa la ventana "!APP_NAME! Laravel" para ver el error de inicio.
  goto :error
)

echo [OK] Laravel iniciado.

if "!OPEN_BROWSER!"=="1" (
  if defined BROWSER_EXE (
    start "" "!BROWSER_EXE!" "!APP_URL!"
  ) else (
    echo [INFO] No se detecto Firefox Developer Edition ni Chrome Dev/Canary.
    echo [INFO] Abriendo el navegador predeterminado de Windows.
    start "" "!APP_URL!"
  )
) else (
  echo [INFO] Navegador no abierto por parametro.
)

echo.
echo !APP_NAME! esta disponible localmente en !APP_URL!.
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
