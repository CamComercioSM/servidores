#!/usr/bin/env bash
# Nombre: recopilar-evidencias-ce308.sh
# Propósito: recopilar evidencia pública y de Cloudflare para CE-308.
# Estado: experimental (validar primero en un equipo Linux autorizado).
# Alcance: DNS, correo, DNSSEC, TLS, certificados, cabeceras, puertos y
#          configuración sanitizada de Cloudflare.
# Requisitos: bash 4+, curl, openssl, dig, jq, nmap, timeout y sha256sum.
# Parámetros: --hosts-file, --domain, --output-dir, --ports,
#             --dkim-selectors, --skip-cloudflare y --skip-nmap.
# Impacto: solo lectura; realiza consultas DNS/HTTPS y un escaneo TCP limitado.
# Reversión: eliminar el directorio de salida generado.
# Evidencia: archivos de texto/JSON, resumen TSV, manifiesto SHA-256 y bitácora.
# Responsable: Infraestructura / Desarrollo e Innovación TIC.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

HOSTS_FILE=""
DOMAIN=""
OUTPUT_DIR="evidencia-ce308-$(date +%Y%m%d-%H%M%S)"
PORTS="21,22,25,53,80,110,143,443,465,587,993,995,3306,5432,6379,8080,8443"
DKIM_SELECTORS=""
SKIP_CLOUDFLARE=0
SKIP_NMAP=0
ERROR_COUNT=0

usage() {
    cat <<'EOF'
Uso:
  recopilar-evidencias-ce308.sh --hosts-file ARCHIVO --domain DOMINIO [opciones]

Obligatorios:
  --hosts-file ARCHIVO    Un host por línea o formato HALLAZGO|host.
  --domain DOMINIO        Dominio base para SPF, DMARC, MX y DNSSEC.

Opciones:
  --output-dir DIR        Directorio de evidencia (se crea y debe estar vacío).
  --ports LISTA           Puertos TCP para nmap, separados por coma.
  --dkim-selectors LISTA  Selectores DKIM separados por coma (ej.: selector1,google).
  --skip-cloudflare       No consultar la API de Cloudflare.
  --skip-nmap             No realizar el escaneo TCP externo.
  -h, --help              Mostrar esta ayuda.

Cloudflare (opcional):
  Defina CF_API_TOKEN y CF_ZONE_ID como variables de entorno. El token debe ser
  únicamente de lectura y nunca se escribe en la evidencia.

Códigos de salida:
  0 correcto; 2 parámetros; 10 dependencia; 30 validación; 40 recolección parcial.
EOF
}

log() {
    local level="$1"
    shift
    printf '%s [%s] [%s] %s\n' "$(date --iso-8601=seconds)" "$SCRIPT_NAME" "$level" "$*" | tee -a "$LOG_FILE" >&2
}

fail() {
    local exit_code="$1"
    shift
    printf '%s [%s] [ERROR] %s\n' "$(date --iso-8601=seconds)" "$SCRIPT_NAME" "$*" >&2
    exit "$exit_code"
}

record_error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    log WARN "$*"
}

slugify() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/_/g'
}

is_valid_hostname() {
    local host="$1"
    [[ ${#host} -le 253 ]] &&
        [[ "$host" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail 10 "Dependencia ausente: $1"
}

cf_get() {
    local endpoint="$1"
    local destination="$2"
    local temp_file
    local http_code
    temp_file="$(mktemp)"

    http_code="$(curl --silent --show-error --location \
        --connect-timeout 15 --max-time 60 \
        --header "Authorization: Bearer ${CF_API_TOKEN}" \
        --header 'Content-Type: application/json' \
        --output "$temp_file" --write-out '%{http_code}' \
        "https://api.cloudflare.com/client/v4${endpoint}")" || {
        rm -f "$temp_file"
        record_error "Falló la consulta Cloudflare: $endpoint"
        return 1
    }

    if [[ ! "$http_code" =~ ^2 ]]; then
        record_error "Cloudflare devolvió HTTP $http_code para $endpoint"
        jq '{success, errors}' "$temp_file" >"$destination" 2>/dev/null || cp "$temp_file" "$destination"
        rm -f "$temp_file"
        return 1
    fi

    mv "$temp_file" "$destination"
}

while (($# > 0)); do
    case "$1" in
        --hosts-file)
            (($# >= 2)) || fail 2 "Falta el valor de --hosts-file"
            HOSTS_FILE="$2"
            shift 2
            ;;
        --domain)
            (($# >= 2)) || fail 2 "Falta el valor de --domain"
            DOMAIN="${2,,}"
            shift 2
            ;;
        --output-dir)
            (($# >= 2)) || fail 2 "Falta el valor de --output-dir"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --ports)
            (($# >= 2)) || fail 2 "Falta el valor de --ports"
            PORTS="$2"
            shift 2
            ;;
        --dkim-selectors)
            (($# >= 2)) || fail 2 "Falta el valor de --dkim-selectors"
            DKIM_SELECTORS="$2"
            shift 2
            ;;
        --skip-cloudflare)
            SKIP_CLOUDFLARE=1
            shift
            ;;
        --skip-nmap)
            SKIP_NMAP=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail 2 "Parámetro desconocido: $1"
            ;;
    esac
done

[[ -n "$HOSTS_FILE" ]] || fail 2 "--hosts-file es obligatorio"
[[ -f "$HOSTS_FILE" ]] || fail 30 "No existe el archivo: $HOSTS_FILE"
[[ -n "$DOMAIN" ]] || fail 2 "--domain es obligatorio"
is_valid_hostname "$DOMAIN" || fail 2 "Dominio inválido: $DOMAIN"
[[ "$PORTS" =~ ^[0-9]+(,[0-9]+)*$ ]] || fail 2 "Lista de puertos inválida"

for dependency in curl openssl dig jq timeout sha256sum awk sed grep tr sort tee mktemp find xargs; do
    require_command "$dependency"
done
if ((SKIP_NMAP == 0)); then
    require_command nmap
fi

[[ ! -e "$OUTPUT_DIR" ]] || fail 30 "El directorio de salida ya existe: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"/{cabeceras,certificados,dns-hosts,cloudflare}
LOG_FILE="$OUTPUT_DIR/ejecucion.log"
touch "$LOG_FILE"

declare -a HOSTS=()
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(printf '%s' "$raw_line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -z "$line" || "$line" == \#* ]] && continue
    host="${line#*|}"
    host="$(printf '%s' "$host" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | tr '[:upper:]' '[:lower:]')"
    is_valid_hostname "$host" || fail 30 "Host inválido en $HOSTS_FILE: $host"
    HOSTS+=("$host")
done <"$HOSTS_FILE"

((${#HOSTS[@]} > 0)) || fail 30 "El archivo de hosts no contiene entradas válidas"
mapfile -t HOSTS < <(printf '%s\n' "${HOSTS[@]}" | sort -u)

cat >"$OUTPUT_DIR/parametros-no-sensibles.txt" <<EOF
script=$SCRIPT_NAME
version=$SCRIPT_VERSION
fecha_inicio=$(date --iso-8601=seconds)
dominio=$DOMAIN
cantidad_hosts=${#HOSTS[@]}
puertos=$PORTS
cloudflare_solicitado=$((1 - SKIP_CLOUDFLARE))
nmap_solicitado=$((1 - SKIP_NMAP))
jira=CE-308
EOF

printf 'fecha_hora\thost\tdns\thttp_inicial\thttp_final\ttls\tvence_certificado\tserver\tresultado\n' \
    >"$OUTPUT_DIR/validacion-hosts.tsv"

log INFO "Inicio de recolección CE-308 para ${#HOSTS[@]} hosts"

for host in "${HOSTS[@]}"; do
    safe_host="$(slugify "$host")"
    dns_file="$OUTPUT_DIR/dns-hosts/${safe_host}.txt"
    header_file="$OUTPUT_DIR/cabeceras/${safe_host}.txt"
    cert_file="$OUTPUT_DIR/certificados/${safe_host}.txt"

    {
        printf 'A:\n'
        dig +time=5 +tries=1 +short A "$host"
        printf 'AAAA:\n'
        dig +time=5 +tries=1 +short AAAA "$host"
        printf 'CNAME:\n'
        dig +time=5 +tries=1 +short CNAME "$host"
    } >"$dns_file" 2>&1 || record_error "DNS incompleto para $host"

    dns_status="SIN_RESPUESTA"
    grep -Eq '^[0-9a-fA-F:.]+$|\.$' "$dns_file" && dns_status="RESUELVE"

    curl_meta="$(curl --silent --show-error --head --http1.1 \
        --connect-timeout 15 --max-time 45 \
        --dump-header "$header_file" --output /dev/null \
        --write-out '%{http_code}\t%{url_effective}\t%{ssl_verify_result}' \
        "https://${host}/" 2>>"$LOG_FILE")" || curl_meta="000\thttps://${host}/\tERROR"
    IFS=$'\t' read -r http_initial _ verify_result <<<"$curl_meta"

    final_meta="$(curl --silent --show-error --head --http1.1 --location --max-redirs 10 \
        --connect-timeout 15 --max-time 60 --output /dev/null \
        --write-out '%{http_code}\t%{url_effective}' \
        "https://${host}/" 2>>"$LOG_FILE")" || final_meta="000\thttps://${host}/"
    IFS=$'\t' read -r http_final final_url <<<"$final_meta"
    printf '\n# Destino final\n%s\n' "$final_url" >>"$header_file"

    tls_status="ERROR"
    cert_expiry=""
    if timeout 25 openssl s_client -connect "${host}:443" -servername "$host" -showcerts </dev/null 2>&1 \
        | openssl x509 -noout -subject -issuer -serial -dates -fingerprint -sha256 >"$cert_file" 2>&1; then
        tls_status="VALIDO"
        cert_expiry="$(sed -n 's/^notAfter=//p' "$cert_file" | head -n 1)"
        {
            printf '\n# Negociación TLS\n'
            timeout 25 openssl s_client -connect "${host}:443" -servername "$host" -brief </dev/null 2>&1 || true
        } >>"$cert_file"
    else
        record_error "No se pudo obtener certificado de $host"
    fi

    server_header="$(awk 'BEGIN{IGNORECASE=1} /^server:[[:space:]]*/ {sub(/^[^:]+:[[:space:]]*/, ""); gsub(/\r/, ""); print; exit}' "$header_file")"
    result="OK"
    [[ "$dns_status" == "RESUELVE" && "$http_initial" != "000" && "$tls_status" == "VALIDO" && "$verify_result" == "0" ]] || result="REVISAR"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date --iso-8601=seconds)" "$host" "$dns_status" "$http_initial" "$http_final" \
        "$tls_status" "$cert_expiry" "$server_header" "$result" \
        >>"$OUTPUT_DIR/validacion-hosts.tsv"
done

{
    printf '# Evidencia DNS de correo para %s\n' "$DOMAIN"
    printf '\n## MX\n'
    dig +time=5 +tries=1 +short MX "$DOMAIN"
    printf '\n## SPF\n'
    dig +time=5 +tries=1 +short TXT "$DOMAIN" | grep -i 'v=spf1' || true
    printf '\n## DMARC\n'
    dig +time=5 +tries=1 +short TXT "_dmarc.${DOMAIN}"
    if [[ -n "$DKIM_SELECTORS" ]]; then
        IFS=',' read -ra selectors <<<"$DKIM_SELECTORS"
        for selector in "${selectors[@]}"; do
            [[ "$selector" =~ ^[A-Za-z0-9_-]+$ ]] || fail 2 "Selector DKIM inválido: $selector"
            printf '\n## DKIM %s\n' "$selector"
            dig +time=5 +tries=1 +short TXT "${selector}._domainkey.${DOMAIN}"
            dig +time=5 +tries=1 +short CNAME "${selector}._domainkey.${DOMAIN}"
        done
    fi
} >"$OUTPUT_DIR/dns-correo.txt" 2>&1

{
    printf '# DS publicado por el dominio padre\n'
    dig +time=5 +tries=1 +dnssec DS "$DOMAIN"
    printf '\n# Respuesta DNSKEY de la zona\n'
    dig +time=5 +tries=1 +dnssec DNSKEY "$DOMAIN"
} >"$OUTPUT_DIR/dnssec.txt" 2>&1 || record_error "Consulta DNSSEC incompleta"

if ((SKIP_NMAP == 0)); then
    log INFO "Ejecutando nmap TCP limitado sobre los hosts autorizados"
    nmap -Pn -sT --reason --open -p "$PORTS" -iL <(printf '%s\n' "${HOSTS[@]}") \
        -oN "$OUTPUT_DIR/puertos-nmap.txt" >>"$LOG_FILE" 2>&1 || record_error "nmap terminó con error"
else
    printf 'OMITIDO: se indicó --skip-nmap\n' >"$OUTPUT_DIR/puertos-nmap.txt"
fi

if ((SKIP_CLOUDFLARE == 0)); then
    if [[ -z "${CF_API_TOKEN:-}" || -z "${CF_ZONE_ID:-}" ]]; then
        record_error "Cloudflare omitido: defina CF_API_TOKEN y CF_ZONE_ID"
        printf '{"omitido":true,"motivo":"faltan variables CF_API_TOKEN o CF_ZONE_ID"}\n' \
            >"$OUTPUT_DIR/cloudflare/estado.json"
    elif [[ ! "$CF_ZONE_ID" =~ ^[A-Fa-f0-9]{32}$ ]]; then
        record_error "Cloudflare omitido: CF_ZONE_ID no tiene el formato esperado"
        printf '{"omitido":true,"motivo":"CF_ZONE_ID invalido"}\n' \
            >"$OUTPUT_DIR/cloudflare/estado.json"
    else
        log INFO "Consultando Cloudflare con permisos de solo lectura"
        cf_get "/zones/${CF_ZONE_ID}/settings" "$OUTPUT_DIR/cloudflare/settings-raw.json" || true
        if [[ -s "$OUTPUT_DIR/cloudflare/settings-raw.json" ]]; then
            jq '{configuracion: [.result[] | select(.id == "ssl" or .id == "min_tls_version" or .id == "tls_1_3" or .id == "always_use_https" or .id == "automatic_https_rewrites" or .id == "opportunistic_encryption" or .id == "security_level" or .id == "http2" or .id == "http3") | {id, value, modified_on}]}' \
                "$OUTPUT_DIR/cloudflare/settings-raw.json" >"$OUTPUT_DIR/cloudflare-configuracion.json" || record_error "No se pudo resumir configuración Cloudflare"
            rm -f "$OUTPUT_DIR/cloudflare/settings-raw.json"
        fi

        cf_get "/zones/${CF_ZONE_ID}/dns_records?per_page=5000" "$OUTPUT_DIR/cloudflare/dns-raw.json" || true
        if [[ -s "$OUTPUT_DIR/cloudflare/dns-raw.json" ]]; then
            jq '{registros: [.result[] | {type, name, proxied, ttl, destino: (if (.type == "A" or .type == "AAAA") then "[REDACTADO]" else .content end)}]}' \
                "$OUTPUT_DIR/cloudflare/dns-raw.json" >"$OUTPUT_DIR/cloudflare-dns-sanitizado.json" || record_error "No se pudo sanitizar DNS Cloudflare"
            rm -f "$OUTPUT_DIR/cloudflare/dns-raw.json"
        fi

        cf_get "/zones/${CF_ZONE_ID}/dnssec" "$OUTPUT_DIR/cloudflare/dnssec-raw.json" || true
        if [[ -s "$OUTPUT_DIR/cloudflare/dnssec-raw.json" ]]; then
            jq '{dnssec: (.result | {status, algorithm, digest_algorithm, modified_on})}' \
                "$OUTPUT_DIR/cloudflare/dnssec-raw.json" >"$OUTPUT_DIR/cloudflare-dnssec.json" || record_error "No se pudo resumir DNSSEC"
            rm -f "$OUTPUT_DIR/cloudflare/dnssec-raw.json"
        fi

        cf_get "/zones/${CF_ZONE_ID}/rulesets/phases/http_request_firewall_managed/entrypoint" \
            "$OUTPUT_DIR/cloudflare/waf-raw.json" || true
        if [[ -s "$OUTPUT_DIR/cloudflare/waf-raw.json" ]]; then
            jq '{waf: (.result | {name, description, kind, phase, version, last_updated, reglas: [.rules[]? | {action, description, enabled}]})}' \
                "$OUTPUT_DIR/cloudflare/waf-raw.json" >"$OUTPUT_DIR/cloudflare-waf.json" || record_error "No se pudo resumir WAF"
            rm -f "$OUTPUT_DIR/cloudflare/waf-raw.json"
        fi

        cf_get "/zones/${CF_ZONE_ID}/ssl/certificate_packs?status=all" \
            "$OUTPUT_DIR/cloudflare/certificados-raw.json" || true
        if [[ -s "$OUTPUT_DIR/cloudflare/certificados-raw.json" ]]; then
            jq '{certificados: [.result[]? | {type, hosts, status, certificates: [.certificates[]? | {issuer, signature, status, bundle_method, expires_on}]}]}' \
                "$OUTPUT_DIR/cloudflare/certificados-raw.json" >"$OUTPUT_DIR/cloudflare-certificados.json" || record_error "No se pudo resumir certificados Cloudflare"
            rm -f "$OUTPUT_DIR/cloudflare/certificados-raw.json"
        fi
    fi
else
    printf '{"omitido":true,"motivo":"se indicó --skip-cloudflare"}\n' \
        >"$OUTPUT_DIR/cloudflare/estado.json"
fi

cat >"$OUTPUT_DIR/LEAME.txt" <<EOF
Paquete de evidencia CE-308
===========================
Fecha: $(date --iso-8601=seconds)
Script: $SCRIPT_NAME $SCRIPT_VERSION
Dominio: $DOMAIN
Hosts: ${#HOSTS[@]}

Este paquete contiene consultas de solo lectura. Revise el contenido antes de
adjuntarlo a Jira. No debe contener tokens; los destinos A/AAAA obtenidos desde
Cloudflare se sustituyen por [REDACTADO]. Los resultados públicos de DNS y nmap
pueden contener direcciones IP observables desde Internet.

Interpretación:
- validacion-hosts.tsv: resumen por host.
- certificados/: identidad, vigencia y negociación TLS.
- cabeceras/: respuesta HTTP inicial y URL final.
- dns-correo.txt: MX, SPF, DMARC y DKIM solicitado.
- dnssec.txt: DS y DNSKEY observados públicamente.
- puertos-nmap.txt: puertos TCP abiertos dentro de la lista autorizada.
- cloudflare-*.json: configuración resumida y sanitizada, si fue autorizada.
- SHA256SUMS: integridad de cada evidencia.

Reversión: elimine este directorio si la recolección debe descartarse.
Jira: CE-308, CE-314 y CE-316.
EOF

printf 'fecha_fin=%s\nerrores_controlados=%s\n' "$(date --iso-8601=seconds)" "$ERROR_COUNT" \
    >>"$OUTPUT_DIR/parametros-no-sensibles.txt"

if ((ERROR_COUNT > 0)); then
    log WARN "Recolección terminada con $ERROR_COUNT advertencias. Revise $OUTPUT_DIR"
    EXIT_CODE=40
else
    log INFO "Recolección terminada correctamente: $OUTPUT_DIR"
    EXIT_CODE=0
fi

find "$OUTPUT_DIR" -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum \
    | sed "s#  ${OUTPUT_DIR}/#  #" >"$OUTPUT_DIR/SHA256SUMS"

exit "$EXIT_CODE"
