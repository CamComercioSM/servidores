#!/usr/bin/env bash
# Nombre: diagnosticar-bind.sh
# Propósito: recopilar evidencia no destructiva sobre BIND en sistemas RHEL,
#            AlmaLinux o compatibles administrados o no por cPanel.
# Estado: experimental
# Alcance: diagnóstico local del servicio, paquetes, configuración relevante,
#          actualizaciones disponibles y señales de backports de seguridad.
# Requisitos: Bash 4+, systemd, rpm y privilegios de root para evidencia completa.
# Parámetros: --jira CE-NNN [--output RUTA]
# Impacto: solo lectura; no modifica configuración, paquetes, firewall ni servicios.
# Reversión: no aplica; opcionalmente elimine el archivo local de evidencia.
# Evidencia: salida fechada con la incidencia Jira, comandos y resultados.
# Responsable: Administración de infraestructura de CCSM.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
JIRA_KEY=""
OUTPUT_FILE=""

usage() {
    cat <<'USAGE'
Uso:
  sudo ./diagnosticar-bind.sh --jira CE-NNN [--output /ruta/evidencia.txt]

Opciones:
  --jira     Incidencia Jira asociada. Es obligatoria.
  --output   Archivo local para guardar la evidencia. Si se omite, se genera
             en el directorio actual.
  -h, --help Muestra esta ayuda.

El archivo de evidencia puede contener información operativa del servidor.
No lo incorpore al repositorio; adjúntelo únicamente a la incidencia Jira.
USAGE
}

log() {
    printf '%s [%s] %s\n' "$(date -Is)" "$SCRIPT_NAME" "$*"
}

run_section() {
    local title="$1"
    shift
    printf '\n===== %s =====\n' "$title"
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@" 2>&1 || printf '[ADVERTENCIA] El comando terminó con código %s.\n' "$?"
}

while (($#)); do
    case "$1" in
        --jira)
            [[ $# -ge 2 ]] || { printf 'Falta el valor de --jira.\n' >&2; exit 2; }
            JIRA_KEY="$2"
            shift 2
            ;;
        --output)
            [[ $# -ge 2 ]] || { printf 'Falta el valor de --output.\n' >&2; exit 2; }
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Parámetro no reconocido: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! "$JIRA_KEY" =~ ^CE-[0-9]+$ ]]; then
    printf 'Debe indicar una incidencia válida mediante --jira CE-NNN.\n' >&2
    exit 2
fi

if ((EUID != 0)); then
    printf 'Ejecute el script con sudo para obtener evidencia completa.\n' >&2
    exit 20
fi

for dependency in date hostnamectl rpm systemctl ss named named-checkconf grep awk; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Dependencia ausente: %s\n' "$dependency" >&2
        exit 10
    fi
done

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="./evidencia-bind-${JIRA_KEY}-$(date +%Y%m%d-%H%M%S).txt"
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
if [[ ! -d "$OUTPUT_DIR" || ! -w "$OUTPUT_DIR" ]]; then
    printf 'El directorio de salida no existe o no permite escritura: %s\n' "$OUTPUT_DIR" >&2
    exit 30
fi

umask 077
exec > >(tee "$OUTPUT_FILE") 2>&1

log "INICIO jira=$JIRA_KEY estado=experimental"
log "AVISO Esta evidencia es operativa y no debe incorporarse al repositorio."

run_section "Identificación y fecha" date -Is
run_section "Sistema" hostnamectl
run_section "Sistema operativo" cat /etc/os-release
run_section "Sockets DNS locales" bash -c "ss -lntup | grep -E '(:53[[:space:]])'"
run_section "Estado de named" systemctl status named --no-pager -l
run_section "Versión compilada de BIND" named -V
run_section "Paquetes instalados" rpm -q bind bind-libs bind-utils
run_section "Proveedor y origen del paquete" rpm -qi bind
run_section "Validación de sintaxis" named-checkconf

printf '\n===== Directivas de seguridad en archivos named.conf =====\n'
grep -RniE \
    '^[[:space:]]*(view|listen-on|listen-on-v6|recursion|allow-recursion|allow-query-cache|allow-update|allow-transfer|version|tkey-gssapi|dnssec-validation)[[:space:]]' \
    /etc/named.conf /etc/named/*.conf 2>/dev/null \
    || printf '[INFO] No se encontraron directivas coincidentes o archivos adicionales.\n'

printf '\n===== Referencias CVE en el changelog del paquete instalado =====\n'
rpm -q --changelog bind 2>/dev/null \
    | grep -Ei 'CVE-|security|vulnerab' \
    | head -n 200 \
    || printf '[INFO] El changelog instalado no expone referencias de seguridad.\n'

if command -v dnf >/dev/null 2>&1; then
    run_section "Actualizaciones disponibles para BIND" dnf check-update 'bind*'
    run_section "Avisos de seguridad relacionados con BIND" dnf updateinfo info --security 'bind*'
elif command -v yum >/dev/null 2>&1; then
    run_section "Actualizaciones disponibles para BIND" yum check-update 'bind*'
else
    log "ADVERTENCIA No se encontró dnf ni yum para consultar actualizaciones."
fi

if command -v dig >/dev/null 2>&1; then
    run_section "Divulgación local de versión CHAOS" dig @127.0.0.1 version.bind chaos txt +time=2 +tries=1
    run_section "Prueba local de recursión" dig @127.0.0.1 example.com A +time=2 +tries=1
else
    log "ADVERTENCIA dig no está disponible; se omiten las consultas locales."
fi

printf '\n===== Interpretación requerida =====\n'
cat <<'NOTES'
1. Un número de versión estable no prueba por sí solo que una CVE esté abierta:
   RHEL y AlmaLinux pueden aplicar correcciones mediante backports conservando la
   versión principal. Compare el release RPM y sus avisos oficiales.
2. Las pruebas contra 127.0.0.1 muestran la vista local/interna. No demuestran
   cómo responde el servidor a clientes de Internet.
3. La exposición externa de TCP/53 y UDP/53, la recursión pública y version.bind
   deben validarse desde un equipo externo autorizado.
4. Este script no cambia named, cPanel, firewalld ni las zonas DNS.
NOTES

log "FIN resultado=diagnostico_generado archivo=$OUTPUT_FILE"
