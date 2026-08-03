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

Los valores variables deben recibirse mediante parámetros, variables de entorno, archivos locales excluidos por `.gitignore` o un gestor institucional de secretos.

## Requisitos para scripts

- Detenerse ante errores no controlados.
- Validar permisos y dependencias antes de ejecutar.
- Generar mensajes claros y códigos de salida coherentes.
- No imprimir secretos en pantalla ni archivos de registro.
- Incluir modo de simulación cuando sea razonable.
- Documentar impacto, reversión y evidencia esperada.

## Incidentes

Si se publica accidentalmente un secreto, debe revocarse o rotarse inmediatamente, retirarse del repositorio y registrarse el incidente por el canal institucional.
