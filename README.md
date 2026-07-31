# Repositorio de scripts para servidores

Repositorio institucional para centralizar, documentar y versionar scripts utilizados en la administración, mantenimiento, seguridad, respaldo, monitoreo y automatización de servidores.

## Objetivos

- Evitar scripts dispersos o sin control de versiones.
- Mantener trazabilidad sobre cada cambio operativo.
- Estandarizar validaciones, registros y manejo de errores.
- Facilitar la reutilización segura de tareas administrativas.
- Conservar documentación técnica y procedimientos de ejecución.

## Estructura

```text
.
├── docs/                 # Estándares, procedimientos y documentación técnica
├── inventory/            # Plantillas de inventario, nunca datos sensibles reales
├── scripts/
│   ├── backup/           # Copias de seguridad y restauración
│   ├── database/         # Motores de bases de datos
│   ├── linux/            # Administración de servidores Linux
│   ├── monitoring/       # Salud, disponibilidad y alertas
│   ├── network/          # Red, DNS, firewall y conectividad
│   ├── security/         # Endurecimiento, auditoría y respuesta
│   └── windows/          # Administración de Windows Server
└── templates/            # Plantillas para nuevos scripts
```

## Reglas obligatorias

1. No almacenar contraseñas, tokens, llaves privadas, certificados, secretos, archivos `.env`, respaldos ni volcados de bases de datos.
2. No registrar IP privadas, nombres internos, rutas sensibles o datos personales sin anonimización.
3. Todo script debe incluir propósito, requisitos, parámetros, ejemplo, validaciones, reversión y responsable.
4. Los scripts destructivos deben exigir confirmación explícita o una opción como `--force`.
5. Antes de producción, probar en un entorno controlado.
6. Los cambios deben realizarse mediante rama y pull request cuando el repositorio tenga más colaboradores.
7. Cada ejecución productiva debe quedar asociada al requerimiento correspondiente en Jira.

## Convención de nombres

Usar minúsculas y guiones:

```text
verificar-espacio-disco.sh
respaldar-base-datos.sh
reiniciar-servicio.ps1
```

## Estados recomendados para scripts

- `experimental`: en construcción; no ejecutar en producción.
- `validated`: probado en ambiente controlado.
- `production`: aprobado para uso operativo.
- `deprecated`: no usar; se conserva solo por trazabilidad.

## Uso básico

```bash
git clone https://github.com/CamComercioSM/servidores.git
cd servidores
```

Revise el archivo `README.md` de cada categoría y la documentación de seguridad antes de ejecutar cualquier script.

## Seguridad

Consulte [SECURITY.md](SECURITY.md). Debido a que este repositorio puede contener automatizaciones de infraestructura, se recomienda mantenerlo privado antes de incorporar detalles reales del entorno institucional.
