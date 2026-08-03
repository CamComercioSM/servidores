# Repositorio de scripts para servidores

Repositorio institucional para centralizar, documentar y versionar scripts utilizados en la administración, mantenimiento, seguridad, respaldo, monitoreo y automatización de servidores y máquinas virtuales.

## Objetivos

- Evitar scripts dispersos o sin control de versiones.
- Mantener trazabilidad sobre cada cambio operativo.
- Estandarizar validaciones, registros y manejo de errores.
- Facilitar la reutilización segura de tareas administrativas.
- Conservar documentación técnica y procedimientos de ejecución.

## Estructura

```text
.
├── camara-4.0/            # Scripts y documentación del programa CÁMARA 4.0
├── docs/                  # Estándares y documentación técnica
├── inventory/             # Plantillas de inventario sin datos reales
├── scripts/               # Catálogo general de automatizaciones
└── templates/             # Plantillas para nuevos scripts
```

## Reglas obligatorias

1. No almacenar contraseñas, tokens, llaves privadas, certificados, secretos, archivos `.env`, respaldos ni volcados de bases de datos.
2. No registrar IP privadas, nombres internos o datos personales sin anonimización y autorización.
3. Todo script debe incluir propósito, requisitos, parámetros, validaciones, reversión y evidencia.
4. Los scripts destructivos deben exigir confirmación explícita.
5. Antes de producción, probar en un entorno controlado.
6. Los cambios deben realizarse mediante rama y pull request.
7. Cada ejecución productiva debe quedar asociada al requerimiento correspondiente en Jira.

## Convención de nombres

Usar minúsculas y guiones:

```text
verificar-espacio-disco.sh
respaldar-base-datos.sh
reiniciar-servicio.ps1
```

## Estados recomendados

- `experimental`: en construcción.
- `validated`: probado en ambiente controlado.
- `production`: aprobado para uso operativo.
- `deprecated`: conservado solo por trazabilidad.

## Uso básico

```bash
git clone https://github.com/CamComercioSM/servidores.git
cd servidores
```

Consulte [SECURITY.md](SECURITY.md) y [docs/estandar-scripts.md](docs/estandar-scripts.md) antes de incorporar o ejecutar automatizaciones.
