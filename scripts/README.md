# Catálogo de scripts

Organice cada script según su función principal:

- `backup/`: respaldo, restauración, retención y verificación.
- `database/`: mantenimiento y operación de bases de datos.
- `linux/`: usuarios, servicios, paquetes, almacenamiento y sistema operativo.
- `monitoring/`: disponibilidad, recursos, certificados y alertas.
- `network/`: DNS, firewall, puertos, conectividad y proxy.
- `security/`: endurecimiento, auditoría, revisión y respuesta.
- `windows/`: PowerShell y administración de Windows Server.

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
