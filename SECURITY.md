# Política de seguridad

Este repositorio contiene automatizaciones que pueden afectar infraestructura institucional. Todo aporte debe aplicar el principio de mínimo privilegio y evitar revelar información operativa sensible.

## Contenido prohibido

No se debe versionar:

- Contraseñas, tokens, secretos o credenciales.
- Llaves privadas, certificados o archivos de almacenes de claves.
- Archivos `.env` reales.
- Direcciones IP privadas, nombres internos o inventarios productivos sin anonimización.
- Respaldos, volcados de bases de datos o archivos con datos personales.
- Registros que expongan sesiones, cabeceras de autenticación o información confidencial.

## Manejo de configuración

Los valores variables deben recibirse mediante:

1. Parámetros de línea de comandos.
2. Variables de entorno.
3. Archivos locales excluidos por `.gitignore`.
4. Un gestor institucional de secretos.

Los ejemplos deben usar datos ficticios, como:

```text
SERVER_HOST=server.example.internal
DATABASE_NAME=example_database
```

## Requisitos para scripts

- Detenerse ante errores no controlados.
- Validar permisos y dependencias antes de ejecutar.
- Generar mensajes claros y códigos de salida coherentes.
- No imprimir secretos en pantalla ni archivos de registro.
- Incluir modo de simulación cuando sea razonable.
- Documentar impacto, reversión y evidencia esperada.

## Incidentes

Si se publica accidentalmente un secreto:

1. Revocarlo o rotarlo inmediatamente.
2. Retirar el contenido del repositorio y, si procede, del historial.
3. Registrar el incidente por el canal institucional.
4. Revisar accesos y evidencias de uso.

No basta con eliminar el archivo: un secreto comprometido debe considerarse expuesto.
