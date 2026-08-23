@echo off
setlocal EnableExtensions
title RUTAC Admin - Verificacion de entorno

set "PROJECT_DIR=%~dp0"
set "APP_HOST=127.0.0.1"
set "APP_PORT=8000"
set "APP_URL=http://%APP_HOST%:%APP_PORT%"
set "PHP_UPPER_BOUND_WARNING=0"

cd /d "%PROJECT_DIR%"

echo ============================================
echo       RUTAC Admin - Inicio local
echo ============================================
echo.
echo Verificando entorno antes de iniciar...
echo.

rem ------------------------------------------------------------
rem 1. Estructura minima del proyecto
rem ------------------------------------------------------------
if not exist artisan (
  echo [ERROR] No se encontro artisan.
  echo Este archivo debe ejecutarse desde la raiz de RUTAC Admin.
  goto :error
)

if not exist composer.json (
  echo [ERROR] No se encontro composer.json.
  echo El proyecto Laravel parece estar incompleto.
  goto :error
)

if not exist composer.lock (
  echo [ERROR] No se encontro composer.lock.
  echo RUTAC requiere el lock del repositorio para instalar versiones validadas.
  goto :error
)

if not exist package.json (
  echo [ERROR] No se encontro package.json.
  echo El proyecto frontend parece estar incompleto.
  goto :error
)

if not exist .env.example (
  echo [ERROR] No se encontro .env.example.
  echo No es posible preparar la configuracion local automaticamente.
  goto :error
)

echo [OK] Estructura basica del proyecto.

rem ------------------------------------------------------------
rem 2. Herramientas requeridas por Laravel 12, Materio y RUTAC
rem    Materio: PHP 8.2+, Composer 2.2+, Node 18.12+.
rem    PHP 8.5+: permitido con advertencia mientras Laravel Excel 3.1 +
rem    PhpSpreadsheet 1.30.x mantengan un limite superior menor a 8.5.
rem ------------------------------------------------------------
where php >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PHP no esta disponible en el PATH de Windows.
  goto :error
)

for /f "delims=" %%V in ('php -r "echo PHP_VERSION;"') do set "PHP_VERSION=%%V"
powershell -NoProfile -Command "$v=[version]'%PHP_VERSION%'; if ($v -lt [version]'8.2.0') { exit 1 }" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] PHP %PHP_VERSION% no cumple el minimo requerido: PHP 8.2.0.
  goto :error
)

powershell -NoProfile -Command "$v=[version]'%PHP_VERSION%'; if ($v -ge [version]'8.5.0') { exit 0 } else { exit 1 }" >nul 2>nul
if not errorlevel 1 (
  set "PHP_UPPER_BOUND_WARNING=1"
  echo [ADVERTENCIA] PHP %PHP_VERSION% supera el limite declarado por una dependencia de Excel.
  echo              RUTAC puede iniciar y ya fue probado localmente con PHP 8.5,
  echo              pero Laravel Excel 3.1 / PhpSpreadsheet 1.30.x aun declaran PHP menor a 8.5.
  echo              Composer ignorara solamente ese limite superior de PHP cuando sea necesario.
  echo              Las exportaciones Excel deben mantenerse bajo observacion hasta actualizar la dependencia.
) else (
  echo [OK] PHP %PHP_VERSION%.
)

where composer >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Composer no esta disponible en el PATH de Windows.
  goto :error
)

set "COMPOSER_VERSION="
for /f "tokens=3" %%V in ('composer --version --no-ansi 2^>nul') do if not defined COMPOSER_VERSION set "COMPOSER_VERSION=%%V"
if not defined COMPOSER_VERSION (
  echo [ERROR] No fue posible determinar la version de Composer.
  goto :error
)
powershell -NoProfile -Command "if ([version]'%COMPOSER_VERSION%' -lt [version]'2.2.0') { exit 1 }" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Composer %COMPOSER_VERSION% no cumple el minimo requerido: Composer 2.2.0.
  goto :error
)
echo [OK] Composer %COMPOSER_VERSION%.

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js no esta disponible en el PATH de Windows.
  goto :error
)

for /f "delims=" %%V in ('node --version') do set "NODE_VERSION=%%V"
powershell -NoProfile -Command "$v='%NODE_VERSION%'.TrimStart('v'); if ([version]$v -lt [version]'18.12.0') { exit 1 }" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js %NODE_VERSION% no cumple el minimo requerido: Node 18.12.0.
  goto :error
)
echo [OK] Node.js %NODE_VERSION%.

where yarn >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Yarn no esta disponible en el PATH de Windows.
  echo Instala o habilita Yarn antes de continuar.
  goto :error
)
for /f "delims=" %%V in ('yarn --version 2^>nul') do set "YARN_VERSION=%%V"
echo [OK] Yarn %YARN_VERSION%.

rem ------------------------------------------------------------
rem 3. Archivo de entorno
rem ------------------------------------------------------------
if not exist .env (
  echo [INFO] No existe .env. Creando desde .env.example...
  copy /y .env.example .env >nul
  if errorlevel 1 (
    echo [ERROR] No fue posible crear .env.
    goto :error
  )
  echo [OK] Archivo .env creado.
) else (
  echo [OK] Archivo .env disponible.
)

rem ------------------------------------------------------------
rem 4. Dependencias PHP
rem ------------------------------------------------------------
if not exist vendor\autoload.php (
  echo [INFO] No se encontro vendor\autoload.php.
  if "%PHP_UPPER_BOUND_WARNING%"=="1" (
    echo [INFO] Ejecutando composer install desde composer.lock ignorando solo el limite superior de PHP...
    call composer install --no-interaction --ignore-platform-req=php+
  ) else (
    echo [INFO] Ejecutando composer install desde composer.lock...
    call composer install --no-interaction
  )
  if errorlevel 1 (
    echo [ERROR] composer install fallo.
    echo No uses composer update como solucion automatica.
    echo Revisa primero la version de PHP y los requisitos del lock.
    goto :error
  )
)

if not exist vendor\autoload.php (
  echo [ERROR] Las dependencias PHP siguen incompletas despues de Composer.
  goto :error
)
echo [OK] Dependencias PHP instaladas.

echo [INFO] Validando requisitos de plataforma PHP y extensiones...
if "%PHP_UPPER_BOUND_WARNING%"=="1" (
  call composer install --dry-run --no-interaction --ignore-platform-req=php+ >nul
  if errorlevel 1 (
    echo [ERROR] El entorno no cumple uno o mas requisitos de Composer distintos del limite superior de PHP.
    echo Ejecuta manualmente:
    echo   composer install --dry-run --ignore-platform-req=php+
    goto :error
  )
  echo [ADVERTENCIA] Requisitos validados permitiendo solo el limite superior de PHP.
) else (
  call composer check-platform-reqs --no-interaction
  if errorlevel 1 (
    echo [ERROR] PHP no cumple todos los requisitos de los paquetes instalados.
    echo Revisa las extensiones PHP indicadas por Composer.
    goto :error
  )
  echo [OK] Requisitos de plataforma PHP.
)

rem ------------------------------------------------------------
rem 5. Version real de Laravel
rem ------------------------------------------------------------
set "LARAVEL_VERSION="
for /f "tokens=3" %%V in ('php artisan --version 2^>nul') do set "LARAVEL_VERSION=%%V"
if not defined LARAVEL_VERSION (
  echo [ERROR] Artisan no pudo inicializar Laravel.
  goto :error
)
powershell -NoProfile -Command "if ([version]'%LARAVEL_VERSION%' -lt [version]'12.0.0') { exit 1 }" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Laravel %LARAVEL_VERSION% no cumple el minimo requerido: Laravel 12.0.0.
  goto :error
)
echo [OK] Laravel %LARAVEL_VERSION%.

rem ------------------------------------------------------------
rem 6. APP_KEY
rem ------------------------------------------------------------
set "APP_KEY_VALUE="
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
rem 7. Directorios escribibles requeridos por Laravel
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
rem 8. Dependencias frontend
rem ------------------------------------------------------------
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
echo [OK] Dependencias frontend instaladas.

rem ------------------------------------------------------------
rem 9. Configuracion Laravel y base de datos
rem ------------------------------------------------------------
echo [INFO] Limpiando caches de desarrollo...
php artisan optimize:clear >nul
if errorlevel 1 (
  echo [ERROR] Laravel no pudo limpiar sus caches.
  goto :error
)
echo [OK] Caches Laravel.

echo [INFO] Verificando configuracion y acceso a base de datos...
php artisan migrate:status --no-interaction >nul 2>nul
if errorlevel 1 (
  echo [ERROR] No fue posible consultar el estado de migraciones.
  echo Revisa la configuracion de base de datos en .env y que el servidor este disponible.
  echo Puedes diagnosticarlo manualmente con:
  echo   php artisan migrate:status
  goto :error
)
echo [OK] Conexion de base de datos disponible.

rem ------------------------------------------------------------
rem 10. Puerto Laravel
rem ------------------------------------------------------------
powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort %APP_PORT% -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>nul
if not errorlevel 1 (
  echo [ERROR] El puerto %APP_PORT% ya esta ocupado.
  echo Cierra el proceso que usa %APP_URL% o cambia APP_PORT en este archivo.
  goto :error
)
echo [OK] Puerto %APP_PORT% disponible.

echo.
echo ============================================
echo       Entorno validado correctamente
echo ============================================
echo Laravel: %APP_URL%
echo Vite:    yarn dev
echo.
echo Iniciando servicios...

start "RUTAC Laravel" cmd /k "cd /d ""%PROJECT_DIR%"" && php artisan serve --host=%APP_HOST% --port=%APP_PORT%"
start "RUTAC Vite" cmd /k "cd /d ""%PROJECT_DIR%"" && yarn dev"

echo [INFO] Esperando que Laravel quede disponible...
powershell -NoProfile -Command "$ok=$false; for($i=0; $i -lt 15; $i++){ if(Get-NetTCPConnection -LocalPort %APP_PORT% -State Listen -ErrorAction SilentlyContinue){$ok=$true; break}; Start-Sleep -Seconds 1 }; if(-not $ok){exit 1}" >nul 2>nul
if errorlevel 1 (
  echo [ADVERTENCIA] Laravel no confirmo escucha en el puerto %APP_PORT% despues de 15 segundos.
  echo Revisa la ventana "RUTAC Laravel" para ver el error.
  goto :error
)

echo [OK] Laravel iniciado.
start "" "%APP_URL%"

echo.
echo RUTAC Admin esta iniciando en %APP_URL%.
endlocal
exit /b 0

:storage_error
echo [ERROR] No fue posible preparar los directorios de runtime de Laravel.
echo Verifica permisos de escritura sobre storage y bootstrap\cache.
goto :error

:error
echo.
echo ============================================
echo        RUTAC Admin NO fue iniciado
echo ============================================
echo Corrige el error indicado y vuelve a ejecutar este archivo.
echo.
pause
endlocal
exit /b 1
