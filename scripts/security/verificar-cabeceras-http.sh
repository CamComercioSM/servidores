#!/usr/bin/env bash
# Nombre: verificar-cabeceras-http.sh
# Proposito: auditar cabeceras HTTP de seguridad en URLs publicas y, de forma
#            opcional, comparar la respuesta con el servidor de origen.
# Estado: experimental.
# Alcance: comprobacion HTTPS de los hosts recibidos en un archivo local.
# Requisitos: Bash 4+, curl, awk, sed, grep y mktemp; dig es opcional.
# Parametros: consulte --help. Los inventarios e IP se reciben en ejecucion.
# Impacto: solo lectura; realiza solicitudes HTTPS y genera un archivo CSV.
# Reversion: no modifica servicios; elimine el CSV generado si no se necesita.
# Evidencia: CSV con fecha, host, alcance, cabeceras, faltantes y resultado.
# Responsable: administracion de infraestructura y seguridad.
# Seguridad: no versionar el archivo de hosts, el export DNS ni IP de origen.

set -uo pipefail

DNS_EXPORT=""
HOSTS_FILE=""
OUTPUT="resultado_cabeceras_$(date +%Y%m%d_%H%M%S).csv"
ORIGIN_DEFAULT=""
declare -A ORIGIN_BY_HOST=()

usage() {
  cat <<'EOF'
Verifica cabeceras HTTP de seguridad contra la respuesta HTTPS publica.
Opcionalmente compara la respuesta publica con uno o mas origenes.

Formato del archivo de hosts (uno por linea):
  ID|host.example.org

Dependencia obligatoria: curl. Para detalle DNS: instale dig/bind-utils.

Uso basico:
  ./verificar-cabeceras-http.sh --hosts-file hosts.txt \
    --dns-export zona-dns.txt

Comparar todos los hosts con un origen predeterminado:
  ./verificar-cabeceras-http.sh --hosts-file hosts.txt \
    --origin-default IP_ORIGEN

Indicar un origen particular:
  ./verificar-cabeceras-http.sh --hosts-file hosts.txt \
    --origin host.example.org=IP_ORIGEN

Opciones:
  --hosts-file ARCHIVO     Inventario local obligatorio en formato ID|HOST.
  --dns-export ARCHIVO      Export de zona DNS de Cloudflare.
  --output ARCHIVO          CSV de salida.
  --origin-default IP       Origen predeterminado para todos los hosts.
  --origin HOST=IP          Origen especifico; se puede repetir.
  -h, --help                Mostrar esta ayuda.

Codigos de salida:
  0  = los seis encabezados estan presentes en todas las respuestas publicas.
  2  = parametros invalidos.
  10 = dependencia ausente.
  30 = validacion previa fallida.
  40 = hay encabezados faltantes o errores de conexion.
EOF
}

while (($#)); do
  case "$1" in
    --hosts-file)
      [[ $# -ge 2 ]] || { echo "Falta el archivo de --hosts-file" >&2; exit 2; }
      HOSTS_FILE="$2"
      shift 2
      ;;
    --dns-export)
      [[ $# -ge 2 ]] || { echo "Falta el archivo de --dns-export" >&2; exit 2; }
      DNS_EXPORT="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "Falta el archivo de --output" >&2; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    --origin-default)
      [[ $# -ge 2 ]] || { echo "Falta la IP de --origin-default" >&2; exit 2; }
      ORIGIN_DEFAULT="$2"
      shift 2
      ;;
    --origin)
      [[ $# -ge 2 && "$2" == *=* ]] || {
        echo "Use --origin HOST=IP" >&2
        exit 2
      }
      ORIGIN_BY_HOST["${2%%=*}"]="${2#*=}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcion no reconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for command_name in curl awk sed grep mktemp; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Falta la dependencia: $command_name" >&2
    exit 10
  fi
done

if [[ -z "$HOSTS_FILE" ]]; then
  echo "Debe indicar --hosts-file ARCHIVO" >&2
  usage >&2
  exit 2
fi

if [[ ! -r "$HOSTS_FILE" ]]; then
  echo "No se puede leer el archivo de hosts: $HOSTS_FILE" >&2
  exit 30
fi

if [[ -n "$DNS_EXPORT" && ! -r "$DNS_EXPORT" ]]; then
  echo "No se puede leer el export DNS: $DNS_EXPORT" >&2
  exit 30
fi

hosts_data="$(
  awk '
    /^[[:space:]]*($|#)/ { next }
    NF == 2 && $1 != "" && $2 ~ /^[A-Za-z0-9.-]+$/ { print $1 "|" tolower($2); next }
    { invalid = 1 }
    END { exit invalid }
  ' FS='|' "$HOSTS_FILE"
)"
hosts_rc=$?

if ((hosts_rc != 0)) || [[ -z "$hosts_data" ]]; then
  echo "El archivo de hosts esta vacio o contiene lineas invalidas; use ID|HOST" >&2
  exit 30
fi

mapfile -t HALLAZGOS <<<"$hosts_data"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

csv_escape() {
  local value=${1//$'\r'/}
  value=${value//$'\n'/ }
  value=${value//\"/\"\"}
  printf '"%s"' "$value"
}

csv_row() {
  local first=1 value
  for value in "$@"; do
    ((first)) || printf ',' >>"$OUTPUT"
    csv_escape "$value" >>"$OUTPUT"
    first=0
  done
  printf '\n' >>"$OUTPUT"
}

export_record() {
  local host="$1"
  [[ -n "$DNS_EXPORT" ]] || { printf 'NO_PROVISTO|||'; return; }

  awk -v wanted="${host}." '
    $1 == wanted && ($4 == "A" || $4 == "AAAA" || $4 == "CNAME") {
      proxy = "SIN_ETIQUETA"
      if (index($0, "cf-proxied:true")) proxy = "SI"
      else if (index($0, "cf-proxied:false")) proxy = "NO"
      printf "%s|%s|%s", $4, $5, proxy
      found = 1
      exit
    }
    END { if (!found) printf "NO_ENCONTRADO||NO_ENCONTRADO" }
  ' "$DNS_EXPORT"
}

public_dns() {
  local host="$1" result
  if command -v dig >/dev/null 2>&1; then
    result="$({ dig +short CNAME "$host"; dig +short A "$host"; dig +short AAAA "$host"; } \
      | sed '/^[[:space:]]*$/d' \
      | awk '!seen[$0]++ { values = values (values ? ";" : "") $0 } END { print values }')"
  elif command -v getent >/dev/null 2>&1; then
    result="$(getent ahosts "$host" 2>/dev/null \
      | awk '!seen[$1]++ { values = values (values ? ";" : "") $1 } END { print values }')"
  else
    result="HERRAMIENTA_DNS_NO_DISPONIBLE"
  fi
  printf '%s' "${result:-SIN_RESPUESTA}"
}

final_header_block() {
  local source_file="$1"
  sed 's/\r$//' "$source_file" | awk '
    /^HTTP\// { block = ""; capture = 1 }
    capture { block = block $0 "\n" }
    END { printf "%s", block }
  '
}

header_value() {
  local source_file="$1" wanted="$2"
  awk -v wanted="$wanted" '
    {
      line = $0
      sub(/\r$/, "", line)
      separator = index(line, ":")
      if (separator > 0 && tolower(substr(line, 1, separator - 1)) == tolower(wanted)) {
        value = substr(line, separator + 1)
        sub(/^[[:space:]]+/, "", value)
        print value
        exit
      }
    }
  ' "$source_file"
}

PUBLIC_FAILURES=0

probe() {
  local finding_id="$1" host="$2" scope="$3" resolve_ip="${4:-}"
  local raw_headers="$tmp_dir/${finding_id}_${scope//[^A-Za-z0-9]/_}_raw.txt"
  local final_headers="$tmp_dir/${finding_id}_${scope//[^A-Za-z0-9]/_}_final.txt"
  local curl_error="$tmp_dir/${finding_id}_${scope//[^A-Za-z0-9]/_}_error.txt"
  local curl_result curl_rc http_code final_url server cf_ray cloudflare
  local record record_type record_target export_proxy dns_result
  local hsts x_frame x_content csp referrer permissions missing missing_count status
  local -a resolve_args=()

  record="$(export_record "$host")"
  IFS='|' read -r record_type record_target export_proxy <<<"$record"
  dns_result="$(public_dns "$host")"

  if [[ -n "$resolve_ip" ]]; then
    # Un proxy HTTP ignoraria --resolve y resolveria el host por su cuenta.
    # --noproxy fuerza que esta prueba llegue realmente a la IP de origen.
    resolve_args=(--noproxy '*' --resolve "${host}:443:${resolve_ip}")
  fi

  curl_result="$(curl -k -sS -L --max-redirs 5 \
    --connect-timeout 10 --max-time 35 \
    -A 'HTTP-Security-Header-Audit/1.0' \
    -D "$raw_headers" -o /dev/null \
    "${resolve_args[@]}" \
    -w '%{http_code}|%{url_effective}' \
    "https://${host}/" 2>"$curl_error")"
  curl_rc=$?

  IFS='|' read -r http_code final_url <<<"${curl_result:-000|https://${host}/}"
  final_header_block "$raw_headers" >"$final_headers"

  server="$(header_value "$final_headers" "Server")"
  cf_ray="$(header_value "$final_headers" "CF-Ray")"
  if [[ "${server,,}" == *cloudflare* || -n "$cf_ray" ]]; then
    cloudflare="SI"
  else
    cloudflare="NO"
  fi

  hsts="$(header_value "$final_headers" "Strict-Transport-Security")"
  x_frame="$(header_value "$final_headers" "X-Frame-Options")"
  x_content="$(header_value "$final_headers" "X-Content-Type-Options")"
  csp="$(header_value "$final_headers" "Content-Security-Policy")"
  referrer="$(header_value "$final_headers" "Referrer-Policy")"
  permissions="$(header_value "$final_headers" "Permissions-Policy")"

  missing=""
  [[ -n "$hsts" ]] || missing+="Strict-Transport-Security;"
  [[ -n "$x_frame" ]] || missing+="X-Frame-Options;"
  [[ -n "$x_content" ]] || missing+="X-Content-Type-Options;"
  [[ -n "$csp" ]] || missing+="Content-Security-Policy;"
  [[ -n "$referrer" ]] || missing+="Referrer-Policy;"
  [[ -n "$permissions" ]] || missing+="Permissions-Policy;"
  missing="${missing%;}"

  if [[ -z "$missing" ]]; then
    missing_count=0
  else
    missing_count="$(awk -F';' '{print NF}' <<<"$missing")"
  fi

  if ((curl_rc != 0)) || [[ "$http_code" == "000" ]]; then
    status="ERROR_CONEXION"
  elif [[ "$http_code" =~ ^[45] ]]; then
    status="NO_CONCLUYENTE_HTTP"
  elif ((missing_count == 0)); then
    status="COMPLETO"
  else
    status="INCOMPLETO"
  fi

  csv_row \
    "$(date -Iseconds)" "$finding_id" "$host" "$scope" \
    "$record_type" "$record_target" "$export_proxy" "$dns_result" \
    "$http_code" "$final_url" "$server" "$cf_ray" "$cloudflare" \
    "${hsts:+SI}" "$hsts" "${x_frame:+SI}" "$x_frame" \
    "${x_content:+SI}" "$x_content" "${csp:+SI}" "$csp" \
    "${referrer:+SI}" "$referrer" "${permissions:+SI}" "$permissions" \
    "$missing_count" "$missing" "$status" "$(<"$curl_error")"

  printf '%-5s %-43s %-8s %-4s %-3s %-9s %s\n' \
    "$finding_id" "$host" "$scope" "$http_code" "$cloudflare" "$status" \
    "${missing:-ninguna}"

  if [[ "$scope" == "PUBLICO" && "$status" != "COMPLETO" ]]; then
    PUBLIC_FAILURES=$((PUBLIC_FAILURES + 1))
  fi
}

: >"$OUTPUT"
csv_row \
  "fecha_hora" "hallazgo" "host" "alcance" \
  "dns_export_tipo" "dns_export_destino" "proxy_cloudflare_export" "dns_publico" \
  "http_codigo" "url_final" "servidor" "cf_ray" "cloudflare_detectado" \
  "hsts" "hsts_valor" "x_frame_options" "x_frame_options_valor" \
  "x_content_type_options" "x_content_type_options_valor" \
  "content_security_policy" "content_security_policy_valor" \
  "referrer_policy" "referrer_policy_valor" \
  "permissions_policy" "permissions_policy_valor" \
  "cantidad_faltantes" "cabeceras_faltantes" "resultado" "error"

printf '%-5s %-43s %-8s %-4s %-3s %-9s %s\n' \
  "ID" "HOST" "ALCANCE" "HTTP" "CF" "RESULTADO" "CABECERAS FALTANTES"

for item in "${HALLAZGOS[@]}"; do
  IFS='|' read -r finding_id host <<<"$item"
  probe "$finding_id" "$host" "PUBLICO"

  origin_ip="${ORIGIN_BY_HOST[$host]:-}"
  if [[ -z "$origin_ip" ]]; then
    origin_ip="$ORIGIN_DEFAULT"
  fi
  if [[ -n "$origin_ip" ]]; then
    probe "$finding_id" "$host" "ORIGEN" "$origin_ip"
  fi
done

echo
echo "Resultado detallado: $OUTPUT"
if ((PUBLIC_FAILURES > 0)); then
  echo "Se encontraron problemas en $PUBLIC_FAILURES de ${#HALLAZGOS[@]} respuestas publicas."
  exit 40
fi

echo "Los ${#HALLAZGOS[@]} hosts publicos entregan las seis cabeceras evaluadas."
exit 0
