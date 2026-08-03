[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$HostsFile,

    [string]$Output = "resultado-ce311-segunda-pasada.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$curl = Get-Command curl.exe -ErrorAction Stop
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36"
$headersEvaluados = @(
    "Strict-Transport-Security",
    "X-Frame-Options",
    "X-Content-Type-Options",
    "Content-Security-Policy",
    "Referrer-Policy",
    "Permissions-Policy"
)

function Get-FinalHeaderBlock {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $lines = @(Get-Content -LiteralPath $Path)
    $lastHttpIndex = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^HTTP/') {
            $lastHttpIndex = $i
        }
    }

    if ($lastHttpIndex -lt 0) {
        return @()
    }

    return @($lines[$lastHttpIndex..($lines.Count - 1)])
}

function Get-HeaderValue {
    param(
        [Parameter(Mandatory = $false)]
        $HeaderBlock,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $HeaderBlock) {
        return ""
    }

    foreach ($lineObject in @($HeaderBlock)) {
        $line = [string]$lineObject
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match ('^{0}\s*:\s*(.*)$' -f [regex]::Escape($Name))) {
            return $Matches[1].Trim()
        }
    }

    return ""
}

if (-not (Test-Path -LiteralPath $HostsFile)) {
    throw "No se encuentra el archivo de hosts: $HostsFile"
}

$items = foreach ($line in Get-Content -LiteralPath $HostsFile) {
    $clean = $line.Trim()
    if (-not $clean -or $clean.StartsWith('#')) {
        continue
    }

    $parts = $clean.Split('|', 2)
    if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) {
        throw "Linea invalida en ${HostsFile}: $line"
    }

    [pscustomobject]@{
        Hallazgo = $parts[0].Trim()
        Host = $parts[1].Trim().ToLowerInvariant()
    }
}

$resultados = foreach ($item in $items) {
    $tempHeaders = [System.IO.Path]::GetTempFileName()
    $tempError = [System.IO.Path]::GetTempFileName()

    try {
        $arguments = @(
            '-k', '-sS', '-L', '--compressed',
            '--http1.1', '--tlsv1.2', '--tls-max', '1.2',
            '--retry', '2', '--retry-delay', '1', '--retry-all-errors',
            '--max-redirs', '5', '--connect-timeout', '15', '--max-time', '60',
            '-A', $userAgent,
            '-H', 'Accept: text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
            '-H', 'Accept-Language: es-CO,es;q=0.9,en;q=0.8',
            '-D', $tempHeaders,
            '-o', 'NUL',
            '-w', '%{http_code}|%{url_effective}',
            "https://$($item.Host)/"
        )

        # Windows PowerShell 5.1 convierte la salida STDERR de programas nativos
        # en NativeCommandError cuando ErrorActionPreference=Stop. Curl usa STDERR
        # para reportar fallos TLS esperados durante la auditoria; deben registrarse
        # en el CSV sin detener la evaluacion de los siguientes hosts.
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $meta = & $curl.Source @arguments 2> $tempError
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $metaText = ($meta -join '').Trim()

        if ($metaText -match '^(\d{3})\|(.*)$') {
            $httpCode = $Matches[1]
            $finalUrl = $Matches[2]
        }
        else {
            $httpCode = '000'
            $finalUrl = "https://$($item.Host)/"
        }

        $block = @(Get-FinalHeaderBlock -Path $tempHeaders)
        $server = Get-HeaderValue -HeaderBlock $block -Name 'Server'
        $cfRay = Get-HeaderValue -HeaderBlock $block -Name 'CF-Ray'

        $values = @{}
        $missing = [System.Collections.Generic.List[string]]::new()
        foreach ($headerName in $headersEvaluados) {
            $value = Get-HeaderValue -HeaderBlock $block -Name $headerName
            $values[$headerName] = $value
            if (-not $value) {
                $missing.Add($headerName)
            }
        }

        if ($exitCode -ne 0 -or $httpCode -eq '000') {
            $status = 'ERROR_CONEXION'
        }
        elseif ($httpCode -match '^[45]') {
            $status = 'NO_CONCLUYENTE_HTTP'
        }
        elseif ($missing.Count -eq 0) {
            $status = 'COMPLETO'
        }
        else {
            $status = 'INCOMPLETO'
        }

        $errorText = ""
        if (Test-Path -LiteralPath $tempError) {
            $errorText = [string](Get-Content -LiteralPath $tempError -Raw -ErrorAction SilentlyContinue)
            $errorText = ($errorText -replace "`r?`n", ' ').Trim()
        }

        [pscustomobject]@{
            fecha_hora = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
            hallazgo = $item.Hallazgo
            host = $item.Host
            http_codigo = $httpCode
            url_final = $finalUrl
            servidor = $server
            cf_ray = $cfRay
            hsts_valor = $values['Strict-Transport-Security']
            x_frame_options_valor = $values['X-Frame-Options']
            x_content_type_options_valor = $values['X-Content-Type-Options']
            content_security_policy_valor = $values['Content-Security-Policy']
            referrer_policy_valor = $values['Referrer-Policy']
            permissions_policy_valor = $values['Permissions-Policy']
            cantidad_faltantes = $missing.Count
            cabeceras_faltantes = ($missing -join ';')
            resultado = $status
            curl_exit_code = $exitCode
            error = $errorText
        }
    }
    finally {
        Remove-Item -LiteralPath $tempHeaders, $tempError -Force -ErrorAction SilentlyContinue
    }
}

$resultados | Export-Csv -LiteralPath $Output -NoTypeInformation -Encoding UTF8
$resultados | Format-Table hallazgo, host, http_codigo, resultado, cantidad_faltantes -AutoSize
Write-Host "`nResultado detallado: $Output"

if (@($resultados | Where-Object resultado -ne 'COMPLETO').Count -gt 0) {
    exit 40
}

exit 0
