# Estándar para scripts operativos

## Cabecera mínima

Cada script debe indicar nombre, propósito, estado de madurez, alcance, requisitos, parámetros, impacto, reversión, evidencia y rol responsable.

## Códigos de salida

- `0`: ejecución correcta.
- `2`: parámetros inválidos.
- `10`: dependencia ausente.
- `20`: permisos insuficientes.
- `30`: validación previa fallida.
- `40`: operación principal fallida.
- `50`: reversión fallida.

## Registro de ejecución

Los mensajes deben contener fecha, nombre del script y resultado. No deben incluir contraseñas, tokens, cadenas de conexión completas ni datos personales.

## Operaciones destructivas

Una operación destructiva debe validar el recurso objetivo, mostrar el impacto, admitir simulación cuando sea posible, exigir confirmación explícita y verificar respaldo o reversión documentada.

## Calidad

Para Bash:

```bash
bash -n ruta/al/script.sh
shellcheck ruta/al/script.sh
```

## Evidencias

La evidencia debe indicar fecha, ambiente, script y versión o commit, parámetros no sensibles, resultado, validaciones posteriores y requerimiento de Jira relacionado.
