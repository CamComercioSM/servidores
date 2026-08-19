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

## Tolerancia a errores y continuidad

La ejecución no se detiene ante el primer fallo.

Durante la importación de una base se utiliza `mariadb --force`, de modo que si una sentencia, tabla, vista, trigger, rutina u otro objeto genera error, el cliente registra el error y continúa procesando las siguientes sentencias del mismo SQL.

Si una base no puede exportarse, el dump queda vacío o la importación presenta errores, el script registra el resultado de esa base y continúa con la siguiente base de la lista.

Al finalizar se presenta un resumen con tres estados:

- `Correctas`: bases importadas sin errores detectados.
- `Parciales`: bases donde hubo uno o más errores durante la importación, pero se continuó con las siguientes tablas y objetos.
- `Fallidas/omitidas`: bases cuyo dump no pudo generarse o resultó inválido y no pudieron procesarse.

La continuidad permite completar la mayor parte de la clonación aun cuando existan incompatibilidades puntuales entre MySQL 8.0.37-google y MariaDB 12.3.2.

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
6. Ejecución automática del SQL sobre el servidor MariaDB local mediante `mariadb --force`.
7. Registro de errores de importación sin detener las siguientes sentencias.
8. Continuación automática con la siguiente base, incluso cuando la base actual quede parcial o falle.
9. Eliminación de archivos temporales al terminar el procesamiento de cada base.
10. Presentación de un resumen final de resultados.

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
- `mariadb.exe` disponible en `PATH` o en la ruta conocida `C:\Program Files\MariaDB 12.3\bin\`.
- `mariadb-dump.exe` disponible en `PATH` o en la ruta conocida `C:\Program Files\MariaDB 12.3\bin\`.
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

1. Ejecutar `--dry-run` para ambos modos y revisar el alcance informado.
2. Ejecutar `--validate` y confirmar acceso al origen, destino y las 19 bases.
3. Probar primero `--schema-only` para verificar compatibilidad estructural MySQL 8.0.37-google → MariaDB 12.3.2.
4. Confirmar que, si una sentencia falla, el script continúa con las siguientes tablas/objetos de la misma base.
5. Confirmar que, si una base falla, la siguiente base sí es procesada.
6. Revisar el resumen final de bases correctas, parciales y fallidas.
7. Validar en SQLyog los objetos realmente creados.
8. Después ejecutar `--full` y validar datos y objetos.

## Riesgos y consideraciones

- Ambos modos son destructivos sobre las bases locales listadas.
- `--schema-only` también elimina y recrea las bases; la diferencia es que no importa filas de datos.
- No se crea respaldo automático del destino.
- Una base marcada como `Parcial` puede haber quedado incompleta; debe revisarse el error mostrado en consola.
- Una base marcada como `Fallida/omitida` no debe considerarse clonada.
- El origen es MySQL 8.0.37-google y el destino MariaDB 12.3.2; pueden existir incompatibilidades puntuales de DDL, `DEFINER`, collations u objetos específicos.
- El servidor local tiene `lower_case_table_names=1`, por lo que los nombres de tablas se materializan en minúsculas. La continuidad ante errores no cambia este comportamiento del servidor.
- `--single-transaction` se utiliza en la clonación completa para consistencia de tablas transaccionales.
- El archivo temporal contiene datos reales únicamente en modo `--full`; se elimina después de procesar cada base.

## Procedimiento de reversión

El script no mantiene el estado local anterior. Si se necesita posibilidad de reversión, el operador debe crear previamente un respaldo local independiente y restaurarlo manualmente.

## Evidencia mínima

Registrar en Jira CE-746 o en la incidencia operativa correspondiente:

- fecha y hora;
- commit o versión del script;
- modo utilizado (`schema-only` o `full`);
- resultado de `--validate`;
- resumen final de bases correctas, parciales y fallidas;
- errores encontrados;
- validación posterior realizada.

Nunca registrar contraseñas, cadenas de conexión completas ni volcados SQL.

## Historial

- 2026-08-19: creación inicial del procedimiento y script asociado a CE-746.
- 2026-08-19: ambiente local identificado como MariaDB 12.3.2 y origen como MySQL 8.0.37-google.
- 2026-08-19: se agregan los modos `--schema-only` y `--full`; el BAT genera y ejecuta automáticamente cada SQL temporal sobre el servidor local.
- 2026-08-19: se agrega tolerancia a errores para continuar con las siguientes tablas/sentencias y bases, incluyendo resumen final de resultados.
