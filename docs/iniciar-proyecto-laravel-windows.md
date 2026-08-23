# Inicio local y LAN de proyectos Laravel en Windows

## Objetivo

Disponer de un único BAT reutilizable para iniciar proyectos Laravel en Windows, tanto para uso local como para pruebas desde otros equipos de la red LAN.

Archivo:

```text
scripts/iniciar-repo-serve-yarn.bat
```

El nombre se conserva por compatibilidad histórica, aunque el script soporta npm, Yarn y pnpm.

## Comportamiento de red

Por defecto Laravel se inicia escuchando en todas las interfaces de red:

```bat
php artisan serve --host=0.0.0.0 --port=8030
```

Esto permite que el mismo proyecto sea accesible simultáneamente:

- en el PC donde se ejecuta: `http://127.0.0.1:8030`;
- desde otros equipos de la LAN: `http://IP_DEL_PC:8030`.

El BAT intenta detectar automáticamente la IPv4 del adaptador con puerta de enlace predeterminada y muestra la URL LAN en consola.

Si existe un frontend con `scripts.dev`, también se levanta Vite usando `--host 0.0.0.0` para que los assets y HMR sean accesibles desde la LAN.

> Si otro equipo no puede conectarse, revise las reglas del Firewall de Windows para el puerto utilizado y confirme que ambos equipos estén en la misma red.

## Uso recomendado

Si el BAT está copiado en la raíz del proyecto:

```bat
iniciar-repo-serve-yarn.bat
```

También puede mantenerse centralizado:

```bat
iniciar-repo-serve-yarn.bat --project "C:\Desarrollo\COPMAR" --port 8030
```

Para COPMAR basta con definir en `.env`:

```dotenv
APP_NAME=COPMAR
APP_PORT=8030
```

El BAT usa ese puerto como preferido. Si está ocupado, intenta automáticamente los siguientes puertos disponibles.

## APP_URL durante el arranque

El proceso hijo de Laravel recibe `APP_PORT` y `APP_URL` calculados en tiempo de ejecución.

Cuando el servidor escucha en `0.0.0.0` y se detecta una IP LAN, `APP_URL` se establece temporalmente con la URL LAN para evitar que los enlaces absolutos generados por Laravel apunten a `127.0.0.1` cuando se accede desde otro equipo.

El navegador del PC servidor sigue abriéndose mediante `127.0.0.1`.

No es necesario modificar físicamente el `.env` cada vez que el BAT selecciona otro puerto.

## Detección automática

El BAT:

1. valida `artisan` y `composer.json`;
2. crea `.env` desde `.env.example` si hace falta;
3. toma `APP_NAME` del `.env` o del nombre de la carpeta;
4. toma `APP_PORT` del `.env`, de `--port` o usa `8000`;
5. valida PHP y Composer;
6. ejecuta `composer install` si falta `vendor/autoload.php`;
7. valida los requisitos reales con `composer check-platform-reqs`;
8. detecta la versión real de Laravel sin imponer una versión fija;
9. genera `APP_KEY` si falta;
10. prepara los directorios de runtime;
11. trata el frontend como opcional;
12. detecta pnpm, Yarn o npm según el lock disponible;
13. instala `node_modules` solo cuando falta;
14. expone Vite en la misma interfaz de red que Laravel;
15. valida la base de datos sin bloquear por defecto;
16. busca un puerto libre si el preferido está ocupado;
17. detecta la IP LAN;
18. muestra las URLs local y LAN;
19. abre el navegador local únicamente después de confirmar que Laravel está escuchando.

## Parámetros

```text
--project RUTA
--name NOMBRE
--host HOST
--port PUERTO
--no-browser
--skip-db-check
--strict-db-check
--help
```

El host predeterminado es `0.0.0.0`. Puede sobrescribirse con `--host` cuando se necesite restringir la escucha.

La validación de base de datos es informativa por defecto. Use `--strict-db-check` cuando el proyecto no deba iniciar si `php artisan migrate:status` falla.

## Gestores frontend

Orden de detección:

1. `pnpm-lock.yaml` → pnpm;
2. `yarn.lock` → Yarn;
3. `package-lock.json` → npm con `npm ci`;
4. sin lock → npm con `npm install`.

Si `package.json` no existe o no contiene `scripts.dev`, no se exige Node.js y solo se levanta Laravel.
