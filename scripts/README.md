# Catálogo de scripts

Organice cada script según su función principal:

- `backup/`: respaldo, restauración, retención y verificación.
- `database/`: mantenimiento y operación de bases de datos.
- `linux/`: usuarios, servicios, paquetes, almacenamiento y sistema operativo.
- `monitoring/`: disponibilidad, recursos, certificados y alertas.
- `network/`: DNS, firewall, puertos, conectividad y proxy.
- `security/`: endurecimiento, auditoría, revisión y respuesta.
- `windows/`: PowerShell y administración de Windows Server.

## Inicio local de proyectos Laravel

- [`iniciar-repo-serve-yarn.bat`](iniciar-repo-serve-yarn.bat): iniciador genérico para proyectos Laravel en Windows. Puede copiarse a la raíz de un proyecto o ejecutarse indicando `--project RUTA`.

El iniciador:

- detecta la versión real de Laravel sin imponer Laravel 12 ni una plantilla concreta;
- valida PHP, Composer y los requisitos declarados por las dependencias;
- crea `.env` desde `.env.example` cuando sea necesario y genera `APP_KEY` si falta;
- prepara los directorios de runtime de Laravel;
- toma `APP_NAME` del `.env` y permite definir `APP_PORT`;
- si el puerto preferido está ocupado, busca automáticamente el siguiente puerto libre;
- considera `package.json` opcional;
- detecta automáticamente `pnpm`, Yarn o npm según el archivo lock;
- instala dependencias frontend solo cuando falta `node_modules`;
- levanta el proceso frontend únicamente si existe `scripts.dev`;
- permite omitir o volver estricta la validación de base de datos;
- abre el navegador después de confirmar que Laravel está escuchando.

Ejemplos:

```bat
REM BAT copiado en la raíz del proyecto
iniciar-repo-serve-yarn.bat

REM Ejecutarlo desde otra ubicación
iniciar-repo-serve-yarn.bat --project "C:\Desarrollo\COPMAR" --port 8030

REM Exigir que la base de datos esté disponible antes de iniciar
iniciar-repo-serve-yarn.bat --strict-db-check

REM Levantar sin abrir navegador
iniciar-repo-serve-yarn.bat --no-browser
```

También puede definirse un puerto estable por proyecto en `.env`:

```dotenv
APP_NAME=COPMAR
APP_PORT=8030
```

## Scripts de bases de datos

- [`database/clonar-bases-sicam-produccion-local.bat`](database/clonar-bases-sicam-produccion-local.bat): reemplaza las bases SICAM locales por una copia lógica de producción. Consulte la [documentación del procedimiento](../docs/clonar-bases-sicam-produccion-local.md).

## Antes de incorporar un script

1. Copie la plantilla desde `templates/`.
2. Complete cabecera, parámetros, impacto y reversión.
3. Elimine valores reales y use variables o parámetros.
4. Ejecute validación sintáctica.
5. Pruebe primero en ambiente controlado.
6. Incluya documentación adicional cuando sea necesaria.

## Clasificación por estado

```text
experimental -> validated -> production -> deprecated
```
