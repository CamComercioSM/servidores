[CmdletBinding()]
param(
    [string[]]$Hosts = @(
        'politica-datos-personales.ccsm.org.co',
        'www.politica-datos-personales.ccsm.org.co',
        'bi.ccsm.org.co',
        'ns2.ccsm.org.co',
        'cav.ccsm.org.co',
        'api.ccsm.org.co',
        'onemall.ccsm.org.co',
        'sgc.ccsm.org.co',
        'magdalena-crece.ccsm.org.co',
        'aviso-de-privacidad.ccsm.org.co',
        'www.aviso-de-privacidad.ccsm.org.co',
        'eventos.ccsm.org.co',
        'eventos.appsicam.net',
        'apps.ccsm.org.co',
        'apps.sicam32.net'
    ),

    [switch]$FollowRedirects,

    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$curl = Get-Command curl.exe -ErrorAction Stop
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/150 Safari/537.36'
$pattern = '^(HTTP/|location:|server:|cf-ray:|strict-transport-security:|x-frame-options:|x-content-type-options:|content-security-policy:|referrer-policy:|permissions-policy:)'

foreach ($hostName in $Hosts) {
    if ([string]::IsNullOrWhiteSpace($hostName)) {
        continue
    }

    $hostName = $hostName.Trim().ToLowerInvariant()
    Write-Host "`n================ $hostName ================" -ForegroundColor Cyan

    $arguments = @(
        '-k', '-sS',
        '--http1.1',
        '--tlsv1.2',
        '--max-redirs', '5',
        '--connect-timeout', '15',
        '--max-time', [string]$TimeoutSeconds,
        '-A', $userAgent,
        '-D', '-',
        '-o', 'NUL'
    )

    if ($FollowRedirects) {
        $arguments += '-L'
    }

    $arguments += "https://$hostName/"

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 puede convertir STDERR de curl.exe en NativeCommandError.
        # Se muestra la salida, pero no se detiene la evaluación de los demás hosts.
        $ErrorActionPreference = 'SilentlyContinue'
        & $curl.Source @arguments 2>&1 |
            Select-String -Pattern $pattern
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

Write-Host "`nModo de evaluación:" -ForegroundColor Yellow
if ($FollowRedirects) {
    Write-Host 'Se mostraron todos los saltos de redirección y la respuesta final.'
}
else {
    Write-Host 'Se evaluó únicamente la respuesta del host solicitado. Use -FollowRedirects para revisar la cadena completa.'
}
