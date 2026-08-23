# Inicio local genérico de proyectos Laravel en Windows

## Objetivo

Disponer de un único BAT reutilizable para iniciar proyectos Laravel locales sin acoplarlo a RUTAC, COPMAR, Materio, una versión fija de Laravel o un gestor frontend específico.

Archivo:

```text
scripts/iniciar-repo-serve-yarn.bat
```

El nombre del archivo se conserva por compatibilidad histórica, aunque el script ya no depende exclusivamente de Yarn.

## Uso recomendado

Puede copiarse el BAT a la raíz del proyecto Laravel y ejecutarse directamente:

```bat
iniciar-repo-serve-yarn.bat
```

También puede mantenerse centralizado y recibir la ruta del proyecto:

```bat
iniciar-repo-serve-yarn.bat --project "C:\Desarrollo\COPMAR" --port 8030
```

## Detección automática

El BAT:

1. valida que existan `artisan` y `composer.json`;
2. crea `.env` desde `.env.example` si es necesario;
3. toma `APP_NAME` del `.env` o usa el nombre de la carpeta;
4. toma `APP_PORT` del `.env`, de `--port` o usa `8000`;
5. valida PHP y Composer según los requisitos reales instalados;
6. ejecuta `composer install` solamente cuando falta `vendor/autoload.php`;
7. detecta la versión real de Laravel sin imponer una versión mínima fija;
8. genera `APP_KEY` si falta;
9. prepara los directorios de runtime;
10. trata el frontend como opcional;
11. si existe `scripts.dev`, detecta pnpm, Yarn o npm según el lock;
12. instala `node_modules` solo cuando falta;
13. valida la base de datos sin bloquear por defecto;
14. busca otro puerto si el preferido está ocupado;
15. inicia Laravel y, cuando corresponde, el frontend;
16. abre el navegador únicamente después de confirmar que Laravel escucha.

## Configuración por proyecto

Para conservar un puerto estable por proyecto puede agregarse al `.env`:

```dotenv
APP_NAME=COPMAR
APP_PORT=8030
```

No es obligatorio modificar el BAT.

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

La validación de base de datos es informativa por defecto. Use `--strict-db-check` cuando el proyecto no deba iniciar si `php artisan migrate:status` falla.

## Gestores frontend

Orden de detección:

1. `pnpm-lock.yaml` → pnpm;
2. `yarn.lock` → Yarn;
3. `package-lock.json` → npm con `npm ci`;
4. sin lock → npm con `npm install`.

Si `package.json` no existe o no contiene `scripts.dev`, no se exige Node.js y solo se levanta Laravel.
