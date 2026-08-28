# Verificador de `.env` para Laravel

Herramienta autónoma para comparar el `.env` real de un proyecto Laravel con su `.env.example`, usado como contrato de referencia.

No requiere un archivo PHP adicional:

- en Windows, `verificar-env.bat` contiene internamente la lógica PowerShell y genera únicamente un archivo temporal durante la ejecución;
- en Linux/macOS, `verificar-env.sh` implementa la validación directamente con shell y `awk`.

El archivo temporal de Windows se elimina al finalizar la ejecución.

## Qué verifica

- Variables que faltan en `.env`.
- Variables que sobran en `.env`.
- Variables que conservan el valor por defecto de `.env.example`.
- Variables cuyo valor fue ajustado.
- Variables vacías o nulas.
- Variables duplicadas y las líneas donde aparecen.
- Líneas que no cumplen el formato `NOMBRE=valor`.

Los valores sensibles se ocultan por defecto.

## Corrección interactiva

Al finalizar la verificación, cuando se ejecuta desde una consola interactiva, el script ofrece este menú:

```text
CORREGIR CONFIGURACION
  1) Agregar variables faltantes desde .env.example
  2) Quitar variables sobrantes de .env
  3) Resolver variables duplicadas (conservar ultima)
  4) Revisar valores por defecto o vacios uno por uno
  5) Aplicar correcciones seguras: 1 + 2 + 3
  6) Volver a verificar
  0) Salir sin mas cambios
```

### Agregar faltantes

Las variables existentes en `.env.example` y ausentes en `.env` se agregan al final de `.env` usando el valor documentado en `.env.example`.

### Quitar sobrantes

Elimina del `.env` las variables que no existen en `.env.example`.

Esta operación debe usarse únicamente cuando `.env.example` se mantiene como contrato completo de configuración del proyecto.

### Resolver duplicadas

Elimina las definiciones anteriores y conserva la última definición efectiva de cada variable duplicada.

### Revisar valores por defecto o vacíos

El script no inventa valores de infraestructura, credenciales ni configuraciones particulares del ambiente. Permite revisarlos uno por uno y decidir:

- dejar el valor actual;
- escribir un valor nuevo;
- usar explícitamente el valor de `.env.example`.

### Copia de seguridad

Antes de la primera modificación de una ejecución se crea automáticamente una copia:

```text
.env.bak-YYYYMMDD-HHMMSS
```

Todas las correcciones de esa ejecución trabajan sobre la misma copia de respaldo inicial.

## Uso en Windows

Desde la carpeta donde está el script:

```powershell
.\verificar-env.bat "C:\ruta\al\proyecto-laravel"
```

Si el BAT se copia a la raíz del proyecto:

```powershell
.\verificar-env.bat
```

Modo estricto:

```powershell
.\verificar-env.bat "C:\ruta\al\proyecto" -Strict
```

Solo informar, sin ofrecer correcciones:

```powershell
.\verificar-env.bat "C:\ruta\al\proyecto" -NoInteractive
```

Otros archivos de ambiente:

```powershell
.\verificar-env.bat "C:\ruta\al\proyecto" -Env .env.production -Example .env.example
```

Opciones Windows:

| Opción | Función |
|---|---|
| `-OnlyProblems` | Oculta la lista de valores correctamente ajustados. |
| `-Strict` | También devuelve error si quedan valores por defecto o vacíos. |
| `-ShowValues` | Muestra valores sensibles; usar solo en consola controlada. |
| `-NoInteractive` | Solo verifica; no muestra el menú de corrección. |
| `-Env ARCHIVO` | Archivo a revisar. Predeterminado: `.env`. |
| `-Example ARCHIVO` | Archivo guía. Predeterminado: `.env.example`. |
| `-Help` | Muestra ayuda. |

## Uso en Linux/macOS

```bash
chmod +x verificar-env.sh
./verificar-env.sh /ruta/al/proyecto
```

Modo estricto:

```bash
./verificar-env.sh /ruta/al/proyecto --strict
```

Sin menú interactivo:

```bash
./verificar-env.sh /ruta/al/proyecto --no-interactive
```

Opciones Linux/macOS:

| Opción | Función |
|---|---|
| `--project=RUTA` | Ruta del proyecto Laravel. También puede ser el primer argumento. |
| `--env=ARCHIVO` | Archivo a revisar. Predeterminado: `.env`. |
| `--example=ARCHIVO` | Archivo guía. Predeterminado: `.env.example`. |
| `--only-problems` | Oculta valores correctamente ajustados. |
| `--strict` | También devuelve error si quedan valores por defecto o vacíos. |
| `--show-values` | Muestra valores sensibles. |
| `--no-interactive` | Solo verifica; no ofrece correcciones. |
| `--help` | Muestra ayuda. |

## Códigos de salida

- `0`: verificación satisfactoria.
- `1`: diferencias que requieren revisión.
- `2`: error de argumentos, archivos o ejecución.

En modo normal, faltantes, sobrantes, duplicados o líneas inválidas producen código `1`.

En modo estricto también producen código `1` las variables vacías o que continúan con el valor por defecto.

## Valores sensibles

Por defecto se ocultan variables cuyo nombre sugiera credenciales o secretos, por ejemplo:

- `APP_KEY`
- `DB_PASSWORD`
- `MAIL_PASSWORD`
- `API_TOKEN`
- `CLIENT_SECRET`
- `AWS_SECRET_ACCESS_KEY`
- `DATABASE_URL`

Ejemplo:

```text
DB_PASSWORD = <oculto, 24 caracteres>
```

## Uso recomendado

1. Mantener `.env.example` actualizado como contrato de configuración del proyecto.
2. Ejecutar el verificador antes de una puesta en producción o al sincronizar una rama.
3. Revisar el reporte.
4. Aplicar únicamente las correcciones seguras que correspondan.
5. Completar manualmente los valores específicos del ambiente.
6. Ejecutar nuevamente la verificación hasta obtener el estado esperado.

La herramienta nunca modifica `.env.example`.