# Verificador de `.env` para Laravel

Herramienta reutilizable y sin dependencias para comparar el `.env` real de un proyecto con su `.env.example`, usado como contrato de referencia.

## Qué informa

- Variables que faltan en `.env`.
- Variables que sobran en `.env`.
- Variables que conservan el valor por defecto de `.env.example`.
- Variables cuyo valor fue ajustado.
- Variables vacías o nulas.
- Variables duplicadas y las líneas donde aparecen.
- Líneas que no cumplen el formato `NOMBRE=valor`.

Los valores sensibles se ocultan por defecto. El script nunca modifica `.env` ni `.env.example`.

## Uso en Windows

```powershell
.\verificar-env.bat "C:\ruta\al\proyecto-laravel"
```

Desde la raíz del proyecto, si se copiaron allí los archivos:

```powershell
.\verificar-env.bat
```

Mostrar solamente lo que requiere revisión:

```powershell
.\verificar-env.bat --only-problems
```

Modo estricto, útil antes de un despliegue:

```powershell
.\verificar-env.bat --strict
```

Verificar otro archivo:

```powershell
.\verificar-env.bat --env=.env.production --example=.env.example
```

## Uso en Linux/macOS

```bash
./verificar-env.sh /ruta/al/proyecto
```

O directamente con PHP:

```bash
php verificar-env.php /ruta/al/proyecto
```

## Opciones

| Opción | Función |
|---|---|
| `--project=RUTA` | Ruta del proyecto Laravel. También puede ser el primer argumento. |
| `--env=ARCHIVO` | Archivo a revisar. Predeterminado: `.env`. |
| `--example=ARCHIVO` | Archivo guía. Predeterminado: `.env.example`. |
| `--only-problems` | Oculta la lista de valores correctamente ajustados. |
| `--strict` | También devuelve error si quedan valores por defecto o vacíos. |
| `--show-values` | Muestra valores sensibles; usar solamente en consola controlada. |
| `--help` | Muestra ayuda. |

## Códigos de salida

- `0`: verificación satisfactoria.
- `1`: diferencias que requieren revisión.
- `2`: error de argumentos, archivos o ejecución.

En modo normal, faltantes, sobrantes, duplicados o líneas inválidas producen código `1`. En modo `--strict`, también lo producen variables vacías o que continúan con el valor por defecto.

## Valores sensibles

Por defecto se ocultan variables cuyo nombre sugiera credenciales o secretos, por ejemplo:

- `APP_KEY`
- `DB_PASSWORD`
- `MAIL_PASSWORD`
- `API_TOKEN`
- `CLIENT_SECRET`
- `AWS_SECRET_ACCESS_KEY`
- URLs de conexión con credenciales

La salida será similar a:

```text
DB_PASSWORD: <vacio> -> <oculto, 24 caracteres>
```

## Integración con Composer

Ejemplo para un proyecto que copie el script dentro del repositorio:

```json
{
  "scripts": {
    "env:check": "@php verificar-env.php --only-problems",
    "env:check-strict": "@php verificar-env.php --strict"
  }
}
```

Entonces puede ejecutarse:

```bash
composer env:check
composer env:check-strict
```

## Recomendación operativa

Ejecutar el modo estricto antes de desplegar un proyecto Laravel ayuda a detectar diferencias entre el contrato documentado en `.env.example` y la configuración real del ambiente sin exponer secretos en los registros.
