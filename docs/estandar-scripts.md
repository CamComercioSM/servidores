# Estándar para scripts operativos

## Cabecera mínima

Cada script debe indicar:

- Nombre y propósito.
- Estado de madurez.
- Alcance y recursos afectados.
- Requisitos y privilegios.
- Parámetros y ejemplos.
- Impacto esperado.
- Procedimiento de reversión.
- Evidencia de ejecución.
- Área o rol responsable.

## Códigos de salida

Use códigos consistentes:

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

Una operación destructiva debe:

1. Validar el recurso objetivo.
2. Mostrar claramente el impacto.
3. Admitir simulación cuando sea posible.
4. Exigir confirmación explícita o `--force`.
5. Verificar que exista respaldo o reversión documentada.
6. Terminar si una validación falla.

## Calidad

Para Bash se recomienda ejecutar:

```bash
bash -n ruta/al/script.sh
shellcheck ruta/al/script.sh
```

Para PowerShell se recomienda utilizar PSScriptAnalyzer y probar con el mismo nivel de versión utilizado en el servidor objetivo.

## Evidencias

La evidencia debe indicar como mínimo:

- Fecha y ambiente.
- Script y versión o commit.
- Parámetros no sensibles.
- Resultado y validaciones posteriores.
- Requerimiento de Jira relacionado.

Las evidencias con información sensible no deben almacenarse en este repositorio.
