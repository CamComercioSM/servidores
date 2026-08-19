# Clonación de bases SICAM de producción a entorno local

## Estado

En desarrollo / `experimental`.

## Jira

CE-746 — Crear script para clonar bases de datos SICAM de producción a entorno local.

## Objetivo

Disponer de una operación manual y repetible para reemplazar las bases de datos SICAM de un servidor MariaDB local con una copia lógica obtenida desde producción.

No es una sincronización incremental. El estado previo de cada base local no se compara ni se conserva: el volcado generado incluye `DROP DATABASE` y `CREATE DATABASE`, por lo que la restauración sustituye la base local completa.

## Ambiente local validado

El servidor local reporta:

- Motor: MariaDB Server.
- Versión: `12.3.2-MariaDB`.
- Host: `localhost`.
- Puerto: `3306`.
- Usuario administrativo observado: `root`.
- Charset del servidor: `utf8mb4`.
- Motor predeterminado: `InnoDB`.
- `lower_case_table_names=1`.

Estos datos fueron verificados el 2026-08-19 a partir de la información del servidor local compartida para CE-746.

## Alcance

El script procesa estas bases:

- `sicam_aplicaciones`
- `sicam_apps`
- `sicam_citurcam`
- `sicam_comercial`
- `sicam_datospersonales`
- `sicam_historia`
- `sicam_logs`
- `sicam_maestras`
- `sicam_modelodatos`
- `sicam_planeador`
- `sicam_principal`
- `sicam_registros`
- `sicam_robots`
- `sicam_saladescanso`
- `sicam_seguridad`
- `sicam_servicios`
- `sicam_talentohumano`
- `sicam_tejidoempresarial`
- `sicam_warehouse`

Quedan excluidas las bases de sistema `information_schema`, `mysql`, `performance_schema` y `sys`.

## Descripción técnica

Archivo principal:

```text
scripts/database/clonar-bases-sicam-produccion-local.bat
```

Por cada base, el proceso realiza:

1. Exportación desde producción a un archivo temporal mediante `mariadb-dump`.
2. Inclusión de estructura, datos, triggers, rutinas y eventos.
3. Inclusión de `DROP DATABASE` y `CREATE DATABASE` en el volcado.
4. Importación del volcado sobre el servidor MariaDB local mediante `mariadb`.
5. Eliminación del archivo temporal al finalizar la base.
6. Interrupción inmediata si falla la exportación o la importación.

Los archivos temporales se crean bajo `%TEMP%` y no dentro del repositorio.

## Credenciales y conexiones

No se almacenan IP, usuarios ni contraseñas en Git.

MariaDB no soporta el archivo `.mylogin.cnf` generado por `mysql_config_editor`, por lo que el script utiliza archivos de opciones externos al repositorio mediante `--defaults-extra-file`.

Rutas predeterminadas:

```text
%APPDATA%\SICAM\database-clone\produccion.cnf
%APPDATA%\SICAM\database-clone\local.cnf
```

Cree la carpeta:

```bat
mkdir "%APPDATA%\SICAM\database-clone"
```

Ejemplo de `local.cnf`:

```ini
[client]
host=127.0.0.1
port=3306
user=root
password=CLAVE_LOCAL
protocol=tcp
```

Ejemplo de `produccion.cnf`:

```ini
[client]
host=SERVIDOR_PRODUCCION
port=3306
user=USUARIO_PRODUCCION
password=CLAVE_PRODUCCION
protocol=tcp
```

Los valores reales se crean únicamente en el equipo del operador y nunca se versionan.

## Requisitos

- Windows.
- MariaDB Client instalado.
- `mariadb.exe` disponible en `PATH`.
- `mariadb-dump.exe` disponible en `PATH`.
- Usuario de producción con permisos de lectura suficientes para exportar objetos y datos.
- Usuario local con permisos para eliminar, crear e importar las bases indicadas.

## Ejecución

Primero realice la simulación:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --dry-run
```

Luego ejecute la clonación:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat
```

La ejecución interactiva exige escribir exactamente:

```text
CLONAR SICAM
```

Para una ejecución controlada donde se quiera omitir la confirmación manual:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --yes
```

Para utilizar archivos de configuración en otras rutas:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --prod-config "C:\ruta\produccion.cnf" --local-config "C:\ruta\local.cnf"
```

## Pruebas y validaciones

Antes de utilizar el script con todas las bases:

1. Confirmar que `mariadb --version` y `mariadb-dump --version` responden correctamente.
2. Ejecutar `--dry-run` y revisar la lista completa de bases.
3. Verificar que existan ambos archivos `.cnf` externos al repositorio.
4. Confirmar acceso con ambas configuraciones.
5. Ejecutar inicialmente contra el MariaDB local controlado.
6. Tras una clonación, validar en SQLyog que las bases esperadas existen y que las tablas críticas son consultables.
7. Revisar especialmente rutinas, eventos, triggers y vistas si el servidor de producción utiliza `DEFINER` específicos.

## Riesgos y consideraciones

- La operación es destructiva sobre las bases locales listadas.
- No se crea un respaldo automático del destino porque el objetivo solicitado es reemplazarlo directamente por producción.
- Si una importación falla después de ejecutar el `DROP DATABASE`, esa base local puede quedar incompleta. El proceso se detiene y reporta el error.
- `--single-transaction` ofrece una copia consistente para tablas transaccionales como InnoDB. Tablas no transaccionales modificadas durante el dump pueden requerir una ventana controlada si se necesita consistencia absoluta.
- La creación de rutinas, vistas o eventos puede requerir privilegios adicionales según los `DEFINER` existentes.
- El archivo temporal contiene datos reales mientras dura la operación; se elimina tras cada base y también cuando se detecta un fallo.
- Se eliminó `--set-gtid-purged=OFF` porque es una opción propia de `mysqldump` de MySQL y no forma parte de `mariadb-dump`.

## Procedimiento de reversión

El script no mantiene el estado local anterior.

Si se necesita posibilidad de reversión, el operador debe crear previamente un respaldo local independiente. La recuperación consiste en restaurar ese respaldo sobre el servidor local.

No debe ejecutarse una reversión contra producción.

## Evidencia mínima

Registrar en Jira CE-746 o en la incidencia operativa correspondiente:

- fecha y hora;
- equipo o ambiente local utilizado;
- commit o versión del script;
- ejecución de `--dry-run`;
- resultado final;
- bases procesadas;
- errores encontrados, si existen;
- validación posterior realizada.

Nunca registrar contraseñas, cadenas de conexión completas ni volcados SQL.

## Historial

- 2026-08-19: creación inicial del procedimiento y script asociado a CE-746.
- 2026-08-19: ambiente local identificado como MariaDB 12.3.2; se reemplaza el uso de `mysql_config_editor`/`--login-path` por archivos `.cnf` externos y se adapta el script a `mariadb`/`mariadb-dump`.
