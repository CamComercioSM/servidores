#!/usr/bin/env sh
set -u

PROJECT="."
ENV_FILE=".env"
EXAMPLE_FILE=".env.example"
ONLY_PROBLEMS=0
STRICT=0
SHOW_VALUES=0
NO_INTERACTIVE=0
BACKUP=""

usage() {
  cat <<'EOF'
Verificador de .env para Laravel

Uso:
  ./verificar-env.sh [RUTA_PROYECTO]
  ./verificar-env.sh --project=RUTA --env=.env --example=.env.example

Opciones:
  --only-problems   Oculta variables correctamente ajustadas.
  --strict          Considera valores por defecto/vacios como problema.
  --show-values     Muestra valores sensibles.
  --no-interactive  Solo informa; no ofrece correcciones.
  --help            Muestra esta ayuda.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT=${arg#*=} ;;
    --env=*) ENV_FILE=${arg#*=} ;;
    --example=*) EXAMPLE_FILE=${arg#*=} ;;
    --only-problems) ONLY_PROBLEMS=1 ;;
    --strict) STRICT=1 ;;
    --show-values) SHOW_VALUES=1 ;;
    --no-interactive) NO_INTERACTIVE=1 ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "[ERROR] Opcion desconocida: $arg" >&2; exit 2 ;;
    *) PROJECT=$arg ;;
  esac
done

cd "$PROJECT" 2>/dev/null || { echo "[ERROR] No existe el proyecto: $PROJECT" >&2; exit 2; }
PROJECT=$(pwd)
[ -f "$EXAMPLE_FILE" ] || { echo "[ERROR] No existe $PROJECT/$EXAMPLE_FILE" >&2; exit 2; }
[ -f "$ENV_FILE" ] || { echo "[ERROR] No existe $PROJECT/$ENV_FILE" >&2; exit 2; }

TMPDIR_BASE=${TMPDIR:-/tmp}
WORK="$TMPDIR_BASE/verificar-env-$$"
mkdir -p "$WORK" || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

is_sensitive() {
  printf '%s' "$1" | grep -Eiq '(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APP_KEY|PRIVATE|CREDENTIAL|DATABASE_URL|DSN)'
}

display_value() {
  key=$1 value=$2
  if [ "$SHOW_VALUES" -eq 0 ] && is_sensitive "$key"; then
    printf '<oculto, %s caracteres>' "$(printf '%s' "$value" | wc -c | tr -d ' ')"
  elif [ -z "$value" ]; then
    printf '<vacio>'
  else
    printf '%s' "$value"
  fi
}

parse_file() {
  src=$1 out=$2 invalid=$3
  awk -v invalid="$invalid" '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    /^[ \t]*$/ || /^[ \t]*#/ { next }
    {
      line=$0
      if (match(line,/^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)) {
        left=substr(line,1,index(line,"=")-1)
        sub(/^[ \t]*/,"",left); sub(/^export[ \t]+/,"",left); sub(/[ \t]*$/,"",left)
        val=substr(line,index(line,"=")+1)
        norm=trim(val)
        if (length(norm)>=2 && ((substr(norm,1,1)=="\"" && substr(norm,length(norm),1)=="\"") || (substr(norm,1,1)=="\047" && substr(norm,length(norm),1)=="\047"))) norm=substr(norm,2,length(norm)-2)
        print left "\t" norm "\t" val "\t" NR
      } else {
        print NR "\t" line >> invalid
      }
    }
  ' "$src" > "$out"
}

analyze() {
  : > "$WORK/guide.invalid"; : > "$WORK/current.invalid"
  parse_file "$EXAMPLE_FILE" "$WORK/guide.tsv" "$WORK/guide.invalid"
  parse_file "$ENV_FILE" "$WORK/current.tsv" "$WORK/current.invalid"

  awk -F '\t' '{v[$1]=$2; raw[$1]=$3; line[$1]=$4} END{for(k in v) print k "\t" v[k] "\t" raw[k] "\t" line[k]}' "$WORK/guide.tsv" | sort > "$WORK/guide.eff"
  awk -F '\t' '{v[$1]=$2; raw[$1]=$3; line[$1]=$4; count[$1]++; lines[$1]=lines[$1] (lines[$1]?", ":"") $4} END{for(k in v){print k "\t" v[k] "\t" raw[k] "\t" line[k]; if(count[k]>1) print k "\t" lines[k] > dup}}' dup="$WORK/duplicates" "$WORK/current.tsv" | sort > "$WORK/current.eff"
  [ -f "$WORK/duplicates" ] || : > "$WORK/duplicates"

  cut -f1 "$WORK/guide.eff" > "$WORK/gkeys"
  cut -f1 "$WORK/current.eff" > "$WORK/ckeys"
  comm -23 "$WORK/gkeys" "$WORK/ckeys" > "$WORK/missing"
  comm -13 "$WORK/gkeys" "$WORK/ckeys" > "$WORK/extra"

  awk -F '\t' 'NR==FNR{g[$1]=$2; next} ($1 in g){if($2==g[$1]) print $1}' "$WORK/guide.eff" "$WORK/current.eff" | sort > "$WORK/defaults"
  awk -F '\t' 'NR==FNR{g[$1]=$2; next} ($1 in g){if($2!=g[$1]) print $1}' "$WORK/guide.eff" "$WORK/current.eff" | sort > "$WORK/adjusted"
  awk -F '\t' '($2=="" || tolower($2)=="null"){print $1}' "$WORK/current.eff" | sort > "$WORK/empty"
}

lookup_field() {
  file=$1 key=$2 field=$3
  awk -F '\t' -v k="$key" -v f="$field" '$1==k{print $f; exit}' "$file"
}

count_lines() { awk 'END{print NR+0}' "$1"; }

print_report() {
  missing=$(count_lines "$WORK/missing")
  extra=$(count_lines "$WORK/extra")
  defaults=$(count_lines "$WORK/defaults")
  adjusted=$(count_lines "$WORK/adjusted")
  empty=$(count_lines "$WORK/empty")
  duplicates=$(count_lines "$WORK/duplicates")
  invalid=$(count_lines "$WORK/current.invalid")
  guide_count=$(count_lines "$WORK/guide.eff")
  current_count=$(count_lines "$WORK/current.eff")

  printf '\n========================================================================\n'
  printf ' VERIFICACION DE VARIABLES DE ENTORNO - LARAVEL\n'
  printf '========================================================================\n'
  printf 'Proyecto: %s\nGuia:     %s\nActual:   %s\n\n' "$PROJECT" "$EXAMPLE_FILE" "$ENV_FILE"
  printf 'Resumen: guia=%s actual=%s faltan=%s sobran=%s por_defecto=%s ajustadas=%s vacias=%s duplicadas=%s invalidas=%s\n' "$guide_count" "$current_count" "$missing" "$extra" "$defaults" "$adjusted" "$empty" "$duplicates" "$invalid"

  if [ "$missing" -gt 0 ]; then
    printf '\nFALTAN EN %s\n' "$ENV_FILE"
    while IFS= read -r key; do val=$(lookup_field "$WORK/guide.eff" "$key" 2); printf '  - %s = %s\n' "$key" "$(display_value "$key" "$val")"; done < "$WORK/missing"
  fi
  if [ "$extra" -gt 0 ]; then
    printf '\nSOBRAN EN %s\n' "$ENV_FILE"
    while IFS= read -r key; do val=$(lookup_field "$WORK/current.eff" "$key" 2); printf '  - %s = %s\n' "$key" "$(display_value "$key" "$val")"; done < "$WORK/extra"
  fi
  if [ "$defaults" -gt 0 ]; then
    printf '\nSIGUEN CON VALOR POR DEFECTO\n'
    while IFS= read -r key; do val=$(lookup_field "$WORK/current.eff" "$key" 2); printf '  - %s = %s\n' "$key" "$(display_value "$key" "$val")"; done < "$WORK/defaults"
  fi
  if [ "$empty" -gt 0 ]; then printf '\nVACIAS O NULAS\n'; sed 's/^/  - /' "$WORK/empty"; fi
  if [ "$duplicates" -gt 0 ]; then printf '\nDUPLICADAS\n'; awk -F '\t' '{printf "  - %s: lineas %s\n",$1,$2}' "$WORK/duplicates"; fi
  if [ "$invalid" -gt 0 ]; then printf '\nLINEAS NO INTERPRETADAS\n'; awk -F '\t' '{printf "  - linea %s: %s\n",$1,$2}' "$WORK/current.invalid"; fi
  if [ "$ONLY_PROBLEMS" -eq 0 ] && [ "$adjusted" -gt 0 ]; then
    printf '\nVALORES AJUSTADOS\n'
    while IFS= read -r key; do val=$(lookup_field "$WORK/current.eff" "$key" 2); printf '  - %s = %s\n' "$key" "$(display_value "$key" "$val")"; done < "$WORK/adjusted"
  fi
}

ensure_backup() {
  [ -n "$BACKUP" ] && return 0
  stamp=$(date '+%Y%m%d-%H%M%S')
  BACKUP="$ENV_FILE.bak-$stamp"
  cp "$ENV_FILE" "$BACKUP" || exit 2
  printf '[OK] Copia de seguridad: %s\n' "$PROJECT/$BACKUP"
}

add_missing() {
  n=$(count_lines "$WORK/missing")
  [ "$n" -gt 0 ] || { echo '[OK] No faltan variables.'; return; }
  ensure_backup
  printf '\n# Variables agregadas automaticamente desde .env.example\n' >> "$ENV_FILE"
  while IFS= read -r key; do raw=$(lookup_field "$WORK/guide.eff" "$key" 3); printf '%s=%s\n' "$key" "$raw" >> "$ENV_FILE"; done < "$WORK/missing"
  printf '[OK] Se agregaron %s variables faltantes.\n' "$n"
}

remove_extra() {
  n=$(count_lines "$WORK/extra")
  [ "$n" -gt 0 ] || { echo '[OK] No sobran variables.'; return; }
  ensure_backup
  awk 'NR==FNR{drop[$1]=1;next} {line=$0; if(match(line,/^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)){left=substr(line,1,index(line,"=")-1); sub(/^[ \t]*/,"",left); sub(/^export[ \t]+/,"",left); sub(/[ \t]*$/,"",left); if(drop[left]) next} print}' "$WORK/extra" "$ENV_FILE" > "$WORK/new.env"
  mv "$WORK/new.env" "$ENV_FILE"
  printf '[OK] Se quitaron %s variables no documentadas.\n' "$n"
}

remove_duplicates() {
  n=$(count_lines "$WORK/duplicates")
  [ "$n" -gt 0 ] || { echo '[OK] No hay duplicadas.'; return; }
  ensure_backup
  awk '
    function key(line,  left){if(match(line,/^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)){left=substr(line,1,index(line,"=")-1); sub(/^[ \t]*/,"",left); sub(/^export[ \t]+/,"",left); sub(/[ \t]*$/,"",left); return left} return ""}
    {lines[NR]=$0; k=key($0); if(k!="") last[k]=NR}
    END{for(i=1;i<=NR;i++){k=key(lines[i]); if(k=="" || last[k]==i) print lines[i]}}
  ' "$ENV_FILE" > "$WORK/new.env"
  mv "$WORK/new.env" "$ENV_FILE"
  echo '[OK] Duplicadas resueltas conservando la ultima definicion efectiva.'
}

set_value() {
  target=$1 newvalue=$2
  ensure_backup
  awk -v target="$target" -v value="$newvalue" '
    function key(line,  left){if(match(line,/^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)){left=substr(line,1,index(line,"=")-1); sub(/^[ \t]*/,"",left); sub(/^export[ \t]+/,"",left); sub(/[ \t]*$/,"",left); return left} return ""}
    {lines[NR]=$0; k=key($0); if(k==target) last=NR}
    END{for(i=1;i<=NR;i++){k=key(lines[i]); if(k==target && i!=last) continue; if(i==last) print target "=" value; else print lines[i]}}
  ' "$ENV_FILE" > "$WORK/new.env"
  mv "$WORK/new.env" "$ENV_FILE"
}

review_values() {
  analyze
  cat "$WORK/defaults" "$WORK/empty" | sort -u > "$WORK/review"
  [ -s "$WORK/review" ] || { echo '[OK] No hay valores por defecto o vacios para revisar.'; return; }
  while IFS= read -r key; do
    analyze
    current=$(lookup_field "$WORK/current.eff" "$key" 2)
    guide=$(lookup_field "$WORK/guide.eff" "$key" 2)
    rawguide=$(lookup_field "$WORK/guide.eff" "$key" 3)
    printf '\n%s\n  actual: %s\n  guia:   %s\n' "$key" "$(display_value "$key" "$current")" "$(display_value "$key" "$guide")"
    if is_sensitive "$key" && [ -t 0 ]; then
      printf 'Nuevo valor (ENTER=dejar igual, !default=usar guia): '
      stty -echo 2>/dev/null || true
      IFS= read -r answer || answer=''
      stty echo 2>/dev/null || true
      printf '\n'
    else
      printf 'Nuevo valor (ENTER=dejar igual, !default=usar guia): '
      IFS= read -r answer || answer=''
    fi
    [ -n "$answer" ] || continue
    [ "$answer" = '!default' ] && answer=$rawguide
    set_value "$key" "$answer"
    printf '[OK] %s actualizado.\n' "$key"
  done < "$WORK/review"
}

interactive_menu() {
  while :; do
    analyze; print_report
    cat <<'EOF'

CORREGIR CONFIGURACION
  1) Agregar variables faltantes desde .env.example
  2) Quitar variables sobrantes de .env
  3) Resolver variables duplicadas (conservar ultima)
  4) Revisar valores por defecto o vacios uno por uno
  5) Aplicar correcciones seguras: 1 + 2 + 3
  6) Volver a verificar
  0) Salir sin mas cambios
EOF
    printf 'Seleccione una opcion: '
    IFS= read -r choice || choice=0
    case "$choice" in
      1) add_missing ;;
      2) remove_extra ;;
      3) remove_duplicates ;;
      4) review_values ;;
      5) add_missing; analyze; remove_extra; analyze; remove_duplicates ;;
      6) continue ;;
      0) return ;;
      *) echo '[AVISO] Opcion no valida.' ;;
    esac
    printf '\nENTER para volver a verificar...'; IFS= read -r _ || true
  done
}

analyze
print_report
if [ "$NO_INTERACTIVE" -eq 0 ] && [ -t 0 ]; then interactive_menu; fi
analyze

base=$(( $(count_lines "$WORK/missing") + $(count_lines "$WORK/extra") + $(count_lines "$WORK/duplicates") + $(count_lines "$WORK/current.invalid") ))
strict=$(( base + $(count_lines "$WORK/defaults") + $(count_lines "$WORK/empty") ))
if [ "$STRICT" -eq 1 ]; then [ "$strict" -eq 0 ] || exit 1; else [ "$base" -eq 0 ] || exit 1; fi
exit 0
