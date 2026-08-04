[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$IpAddress,

    [ValidateRange(1, 65535)]
    [int]$Port = 443,

    [switch]$FollowRedirects,

    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$curl = Get-Command curl.exe -ErrorAction Stop
$HostName = $HostName.Trim().ToLowerInvariant()
$IpAddress = $IpAddress.Trim()
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/150 Safari/537.36'
$pattern = '^(HTTP/|location:|server:|cf-ray:|strict-transport-security:|x-frame-options:|x-content-type-options:|content-security-policy:|referrer-policy:|permissions-policy:)'

Write-Host "Probando origen directo" -ForegroundColor Cyan
Write-Host "Host: $HostName"
Write-Host "IP:   $IpAddress"
Write-Host "Puerto: $Port`n"

$arguments = @(
    '-k', '-sS',
    '--noproxy', '*',
    '--resolve', "${HostName}:${Port}:${IpAddress}",
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

$arguments += "https://${HostName}:${Port}/"

$previousErrorActionPreference = $ErrorActionPreference
try {
    # Mantiene SNI/Host del dominio, pero evita DNS y proxy para llegar a la IP indicada.
    # Windows PowerShell 5.1 puede convertir STDERR de curl.exe en NativeCommandError.
    $ErrorActionPreference = 'SilentlyContinue'
    & $curl.Source @arguments 2>&1 |
        Select-String -Pattern $pattern
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

Write-Host "`nEjemplos:" -ForegroundColor Yellow
Write-Host '.\scripts\security\probar-cabeceras-origen.ps1 -HostName bi.ccsm.org.co -IpAddress 190.8.178.82'
Write-Host '.\scripts\security\probar-cabeceras-origen.ps1 -HostName eventos.appsicam.net -IpAddress 162.240.173.134'
