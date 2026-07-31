# Catálogo de scripts

Organice cada script según su función principal:

- `backup/`: respaldo, restauración, retención y verificación.
- `database/`: mantenimiento y operación de bases de datos.
- `linux/`: usuarios, servicios, paquetes, almacenamiento y sistema operativo.
- `monitoring/`: disponibilidad, recursos, certificados y alertas.
- `network/`: DNS, firewall, puertos, conectividad y proxy.
- `security/`: endurecimiento, auditoría, revisión y respuesta.
- `windows/`: PowerShell y administración de Windows Server.

Git no conserva carpetas vacías. La carpeta correspondiente aparecerá cuando se agregue su primer script.

## Antes de incorporar un script

1. Copie la plantilla apropiada desde `templates/`.
2. Complete cabecera, parámetros, impacto y reversión.
3. Elimine valores reales y use variables o parámetros.
4. Ejecute una validación sintáctica.
5. Pruebe primero en ambiente controlado.
6. Incluya un `README.md` adicional cuando el procedimiento necesite contexto operativo.

## Clasificación por estado

El estado debe figurar en la cabecera del archivo:

```text
experimental -> validated -> production -> deprecated
```

No ejecute en producción archivos marcados como `experimental`.
