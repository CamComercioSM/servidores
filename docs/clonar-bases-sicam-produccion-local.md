# Clonación de bases SICAM de producción a entorno local

## Estado

En desarrollo / `experimental`.

## Jira

CE-746 — Crear script para clonar bases de datos SICAM de producción a entorno local.

## Objetivo

Disponer de una operación manual y repetible para reemplazar las bases de datos SICAM de un servidor MariaDB local con una copia lógica obtenida desde producción.

No es una sincronización incremental. El estado previo de cada base local no se compara ni se conserva: el volcado generado incluye `DROP DATABASE` y `CREATE DATABASE`, por lo que la restauración sustituye la base local completa.

El script genera el SQL temporal y lo ejecuta automáticamente sobre el servidor local. El operador no debe importar manualmente los archivos `.sql`.

## Modos de clonación

El script dispone de dos modos funcionales:

### Solo esquema

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --schema-only
```

Reemplaza cada base local copiando:

- base de datos;
- tablas;
- vistas;
- índices y restricciones;
- triggers;
- procedimientos y funciones;
- eventos.

No copia filas de datos. Internamente utiliza `mariadb-dump --no-data` y ejecuta inmediatamente el SQL generado sobre el destino local.

### Clonación completa

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --full
```

Reemplaza cada base local copiando tanto estructura como datos. Este es el modo predeterminado cuando no se especifica ninguno de los dos parámetros.

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

El origen validado durante CE-746 reporta MySQL `8.0.37-google`.

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
2. Inclusión de `DROP DATABASE` y `CREATE DATABASE` en el volcado.
3. Inclusión de objetos de esquema, triggers, rutinas y eventos.
4. Inclusión o exclusión de datos según el modo seleccionado.
5. Validación de que el archivo SQL temporal no esté vacío.
6. Ejecución automática del SQL sobre el servidor MariaDB local mediante `mariadb`.
7. Eliminación del archivo temporal al finalizar la base.
8. Interrupción inmediata si falla la exportación o la importación.

Los archivos temporales se crean bajo `%TEMP%` y no dentro del repositorio.

## Credenciales y conexiones

No se almacenan IP, usuarios ni contraseñas en Git.

El script utiliza archivos de opciones externos al repositorio mediante `--defaults-extra-file`.

Rutas predeterminadas:

```text
%APPDATA%\SICAM\database-clone\produccion.cnf
%APPDATA%\SICAM\database-clone\local.cnf
```

## Requisitos

- Windows.
- MariaDB Client instalado.
- `mariadb.exe` disponible en `PATH`.
- `mariadb-dump.exe` disponible en `PATH`.
- Usuario de producción con permisos de lectura suficientes para exportar objetos y datos.
- Usuario local con permisos para eliminar, crear e importar las bases indicadas.

## Ejecución y validación

Simulación sin conexiones ni modificaciones:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --dry-run --schema-only
scripts\database\clonar-bases-sicam-produccion-local.bat --dry-run --full
```

Validación de conexiones y acceso a las bases, sin modificar el destino:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --validate
```

Clonación únicamente de esquemas:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --schema-only
```

Clonación completa con datos:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --full
```

La ejecución destructiva exige escribir exactamente:

```text
CLONAR SICAM
```

El parámetro `--yes` permite omitir esa confirmación en una ejecución previamente controlada.

## Pruebas y validaciones

1. Confirmar que `mariadb --version` y `mariadb-dump --version` responden correctamente.
2. Ejecutar `--dry-run` para ambos modos y revisar el alcance informado.
3. Ejecutar `--validate` y confirmar acceso al origen, destino y las 19 bases.
4. Probar primero `--schema-only` para verificar compatibilidad estructural MySQL 8.0.37-google → MariaDB 12.3.2.
5. Validar en SQLyog la creación de bases, tablas, vistas, triggers, rutinas y eventos.
6. Confirmar que las tablas no contienen filas después de `--schema-only`.
7. Después ejecutar `--full` y validar datos y objetos.

## Riesgos y consideraciones

- Ambos modos son destructivos sobre las bases locales listadas.
- `--schema-only` también elimina y recrea las bases; la diferencia es que no importa filas de datos.
- No se crea respaldo automático del destino.
- Si una importación falla después de ejecutar el `DROP DATABASE`, esa base local puede quedar incompleta. El proceso se detiene y reporta el error.
- El origen es MySQL 8.0.37-google y el destino MariaDB 12.3.2; pueden existir incompatibilidades puntuales de DDL, `DEFINER`, collations u objetos específicos.
- `--single-transaction` se utiliza en la clonación completa para consistencia de tablas transaccionales.
- El archivo temporal contiene datos reales únicamente en modo `--full`; se elimina inmediatamente después de importar cada base o cuando ocurre un fallo.

## Procedimiento de reversión

El script no mantiene el estado local anterior. Si se necesita posibilidad de reversión, el operador debe crear previamente un respaldo local independiente y restaurarlo manualmente.

## Evidencia mínima

Registrar en Jira CE-746 o en la incidencia operativa correspondiente:

- fecha y hora;
- commit o versión del script;
- modo utilizado (`schema-only` o `full`);
- resultado de `--validate`;
- bases procesadas;
- errores encontrados;
- validación posterior realizada.

Nunca registrar contraseñas, cadenas de conexión completas ni volcados SQL.

## Historial

- 2026-08-19: creación inicial del procedimiento y script asociado a CE-746.
- 2026-08-19: ambiente local identificado como MariaDB 12.3.2 y origen como MySQL 8.0.37-google.
- 2026-08-19: se agregan los modos `--schema-only` y `--full`; el BAT genera y ejecuta automáticamente cada SQL temporal sobre el servidor local.
