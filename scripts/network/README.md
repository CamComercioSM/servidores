# Scripts de red

## `diagnosticar-bind.sh`

Recopila evidencia local, no destructiva, sobre una instalación de BIND en
RHEL, AlmaLinux o sistemas compatibles. Está diseñado para validar hallazgos de
versión, exposición y configuración antes de aplicar una remediación.

Estado: `experimental`.

### Uso

```bash
chmod +x scripts/network/diagnosticar-bind.sh
sudo scripts/network/diagnosticar-bind.sh --jira CE-NNN
```

También puede definir una ruta explícita:

```bash
sudo scripts/network/diagnosticar-bind.sh \
  --jira CE-NNN \
  --output /root/evidencia-bind-CE-NNN.txt
```

El archivo se crea con permisos restringidos mediante `umask 077`. Puede
contener nombres, direcciones y configuración operativa; no debe versionarse.
Debe adjuntarse únicamente a la incidencia Jira correspondiente.

### Alcance

- Identifica sistema operativo, servicio, sockets y paquetes BIND.
- Ejecuta `named-checkconf` sin modificar la configuración.
- Muestra directivas de seguridad relevantes, sin imprimir el archivo completo.
- Consulta actualizaciones y avisos de seguridad disponibles.
- Busca referencias de CVE y backports en el changelog del RPM instalado.
- Ejecuta pruebas locales de `version.bind` y recursión si `dig` está disponible.

### Limitación importante

Las consultas locales se ejecutan contra `127.0.0.1` y pueden seleccionar una
vista interna. La exposición de TCP/53 y UDP/53, la recursión y la divulgación
de versión deben verificarse adicionalmente desde una red externa autorizada.

### Impacto y reversión

El script es de solo lectura: no actualiza paquetes, no reinicia `named`, no
edita cPanel y no modifica el firewall. No requiere reversión. El único archivo
creado es la evidencia indicada en `--output` o generada en el directorio actual.
