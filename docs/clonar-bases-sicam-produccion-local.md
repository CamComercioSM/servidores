# Clonación de bases SICAM de producción a entorno local

## Estado

En desarrollo / `experimental`.

## Jira

CE-746 — Crear script para clonar bases de datos SICAM de producción a entorno local.

## Objetivo

Disponer de una operación manual y repetible para reemplazar las bases de datos SICAM de un servidor MySQL local con una copia lógica obtenida desde producción.

No es una sincronización incremental. El estado previo de cada base local no se compara ni se conserva: el volcado generado con `mysqldump` incluye `DROP DATABASE` y `CREATE DATABASE`, por lo que la restauración sustituye la base local completa.

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

1. Exportación desde producción a un archivo temporal mediante `mysqldump`.
2. Inclusión de estructura, datos, triggers, rutinas y eventos.
3. Inclusión de `DROP DATABASE` y `CREATE DATABASE` en el volcado.
4. Importación del volcado sobre el servidor MySQL local.
5. Eliminación del archivo temporal al finalizar la base.
6. Interrupción inmediata si falla la exportación o la importación.

Los archivos temporales se crean bajo `%TEMP%` y no dentro del repositorio.

## Credenciales y conexiones

No se almacenan IP, usuarios ni contraseñas en Git.

El script usa el almacén de credenciales de MySQL mediante `mysql_config_editor`. Los nombres predeterminados de los perfiles son:

- Producción: `sicam_prod`
- Local: `sicam_local`

Configure los perfiles una sola vez desde Windows:

```bat
mysql_config_editor set --login-path=sicam_prod --host=SERVIDOR_PRODUCCION --port=3306 --user=USUARIO_PRODUCCION --password
mysql_config_editor set --login-path=sicam_local --host=127.0.0.1 --port=3306 --user=USUARIO_LOCAL --password
```

El comando solicita la contraseña de forma interactiva y la guarda en el mecanismo propio de MySQL para login paths.

Para verificar los perfiles:

```bat
mysql_config_editor print --login-path=sicam_prod
mysql_config_editor print --login-path=sicam_local
```

La salida no debe utilizarse como evidencia pública si expone información de infraestructura que no deba registrarse.

## Requisitos

- Windows.
- `mysql.exe` disponible en `PATH`.
- `mysqldump.exe` disponible en `PATH`.
- `mysql_config_editor.exe` para preparar los perfiles de conexión.
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

Para una ejecución ya controlada donde se quiera omitir la confirmación manual:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --yes
```

Para usar otros nombres de login path:

```bat
scripts\database\clonar-bases-sicam-produccion-local.bat --prod-login-path otro_origen --local-login-path otro_destino
```

## Pruebas y validaciones

Antes de utilizar el script con todas las bases:

1. Confirmar que `mysql --version` y `mysqldump --version` responden correctamente.
2. Ejecutar `--dry-run` y revisar la lista completa de bases.
3. Confirmar acceso con ambos login paths.
4. Ejecutar inicialmente en un MySQL local descartable o respaldado.
5. Tras una clonación, validar en SQLyog o MySQL que las bases esperadas existen y que las tablas críticas son consultables.
6. Revisar especialmente rutinas, eventos, triggers y vistas si el servidor de producción utiliza `DEFINER` específicos.

## Riesgos y consideraciones

- La operación es destructiva sobre las bases locales listadas.
- No se crea un respaldo automático del destino porque el objetivo solicitado es reemplazarlo directamente por producción.
- Si una importación falla después de ejecutar el `DROP DATABASE`, esa base local puede quedar incompleta. El proceso se detiene y reporta el error.
- `--single-transaction` ofrece una copia consistente para tablas transaccionales como InnoDB sin bloquear globalmente producción. Tablas no transaccionales modificadas durante el dump pueden requerir una ventana controlada si se necesita consistencia absoluta.
- La creación de rutinas, vistas o eventos puede requerir privilegios adicionales según los `DEFINER` existentes.
- El archivo temporal contiene datos reales mientras dura la operación; se elimina tras cada base y también cuando se detecta un fallo de exportación o importación.

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
