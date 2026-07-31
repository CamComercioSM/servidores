#!/usr/bin/env bash
set -u

# Diagnostico de soporte AVX/AVX2 visible dentro de una maquina Linux.
# Jira: CE-546
# Este script no modifica la configuracion del sistema.

printf '%s\n' '=== IDENTIFICACION DEL SISTEMA ==='
printf 'Fecha: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf 'No disponible')"
printf 'Kernel: %s\n' "$(uname -r 2>/dev/null || printf 'No disponible')"
printf '\n'

printf '%s\n' '=== CPU VISIBLE EN LA VM ==='
if command -v lscpu >/dev/null 2>&1; then
  lscpu | grep -Ei 'Model name|Hypervisor vendor|Virtualization type|Virtualization:' || true
else
  printf '%s\n' 'lscpu no esta disponible.'
fi
printf '\n'

printf '%s\n' '=== VALIDACION AVX / AVX2 ==='
if grep -qw avx /proc/cpuinfo 2>/dev/null; then
  printf '%s\n' 'AVX: DISPONIBLE'
else
  printf '%s\n' 'AVX: NO DISPONIBLE'
fi

if grep -qw avx2 /proc/cpuinfo 2>/dev/null; then
  printf '%s\n' 'AVX2: DISPONIBLE'
else
  printf '%s\n' 'AVX2: NO DISPONIBLE'
fi
printf '\n'

printf '%s\n' '=== BANDERAS ENCONTRADAS ==='
grep -m1 -oE '\bavx2?\b' /proc/cpuinfo 2>/dev/null | sort -u || true
printf '\n'

printf '%s\n' '=== CONCLUSION ==='
if grep -qw avx /proc/cpuinfo 2>/dev/null && grep -qw avx2 /proc/cpuinfo 2>/dev/null; then
  printf '%s\n' 'La VM ya tiene expuestas las instrucciones AVX y AVX2.'
  exit 0
fi

printf '%s\n' 'La VM no tiene expuestas todas las instrucciones requeridas.'
printf '%s\n' 'Se debe revisar el soporte de la CPU fisica y el tipo de CPU configurado en Proxmox.'
exit 2
