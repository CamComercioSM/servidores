# Diagnóstico AVX/AVX2 — VM dev-camara-4-0

Relacionado con Jira **CE-546**.

## Objetivo

Comprobar si la máquina virtual tiene visibles las extensiones de CPU `AVX` y `AVX2` requeridas por las aplicaciones de CÁMARA 4.0.

## Script

- `diagnostico-avx.sh`: consulta información del sistema y valida las banderas `avx` y `avx2` sin modificar la VM.

## Ejecución directa desde el repositorio clonado

```bash
chmod +x diagnostico-avx.sh
./diagnostico-avx.sh
```

## Guardar evidencia local

```bash
./diagnostico-avx.sh | tee diagnostico-avx-$(date +%F-%H%M%S).txt
```

El archivo de evidencia puede contener hostname, modelo de CPU y versión del kernel. Debe revisarse antes de publicarlo o adjuntarlo fuera de los sistemas institucionales.

## Interpretación

- `AVX: DISPONIBLE` y `AVX2: DISPONIBLE`: la VM ya recibe ambas extensiones desde el hipervisor.
- Alguna extensión como `NO DISPONIBLE`: revisar el soporte de la CPU física y el modelo de CPU virtual configurado en Proxmox.

## Controles

- El diagnóstico no instala paquetes ni modifica configuraciones.
- No almacenar contraseñas, tokens, llaves privadas ni secretos en este repositorio.
- Antes de modificar el modelo de CPU de la VM se debe crear snapshot o respaldo y documentar la configuración anterior.
