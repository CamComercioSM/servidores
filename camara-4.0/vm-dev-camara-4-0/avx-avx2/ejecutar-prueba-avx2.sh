#!/usr/bin/env bash
set -euo pipefail

# Compila y ejecuta una prueba funcional que usa instrucciones AVX2 reales.
# Jira: CE-546

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FUENTE="$SCRIPT_DIR/prueba-avx2.c"
BINARIO="${TMPDIR:-/tmp}/prueba-avx2-ce-546"

if ! command -v gcc >/dev/null 2>&1; then
  echo "ERROR: gcc no esta instalado. Instale el grupo de herramientas de desarrollo o el paquete gcc." >&2
  exit 10
fi

if [[ ! -r "$FUENTE" ]]; then
  echo "ERROR: no se encuentra el archivo $FUENTE" >&2
  exit 11
fi

echo "=== COMPILACION AVX2 ==="
gcc -O2 -std=c11 -Wall -Wextra -Werror -mavx2 "$FUENTE" -o "$BINARIO"

echo "Compilador: $(gcc --version | head -n 1)"
echo "Binario temporal: $BINARIO"
echo

echo "=== VERIFICACION DEL BINARIO ==="
if command -v objdump >/dev/null 2>&1; then
  if objdump -d "$BINARIO" | grep -Eq '\bv(paddd|movdqu|movdqa)\b'; then
    echo "Se encontraron instrucciones vectoriales AVX/AVX2 en el binario."
  else
    echo "ADVERTENCIA: objdump no encontro el patron esperado; se continuara con la ejecucion." >&2
  fi
else
  echo "objdump no esta disponible; se omite la inspeccion del binario."
fi

echo
echo "=== EJECUCION FUNCIONAL ==="
"$BINARIO"

echo
echo "Resultado final: PRUEBA FUNCIONAL AVX2 SUPERADA"
rm -f "$BINARIO"
