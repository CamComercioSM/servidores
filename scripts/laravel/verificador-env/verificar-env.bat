@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SELF=%~f0"
set "TMP_PS1=%TEMP%\verificar-env-%RANDOM%-%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$raw = Get-Content -Raw -LiteralPath $env:SELF; $marker = '# POWERSHELL-BEGIN'; $i = $raw.IndexOf($marker); if ($i -lt 0) { exit 2 }; $code = $raw.Substring($i + $marker.Length); [IO.File]::WriteAllText($env:TMP_PS1, $code, [Text.UTF8Encoding]::new($false))"
if errorlevel 1 (
  echo [ERROR] No fue posible preparar el verificador embebido.
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"
del /q "%TMP_PS1%" >nul 2>&1
exit /b %EXIT_CODE%

# POWERSHELL-BEGIN
param(
    [Parameter(Position=0)][string]$Project = ".",
    [string]$Env = ".env",
    [string]$Example = ".env.example",
    [switch]$OnlyProblems,
    [switch]$Strict,
    [switch]$ShowValues,
    [switch]$NoInteractive,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Help {
@"
Verificador de .env para Laravel

Uso:
  verificar-env.bat [RUTA_PROYECTO]
  verificar-env.bat -Project RUTA -Env .env -Example .env.example

Opciones:
  -OnlyProblems   Oculta variables correctamente ajustadas.
  -Strict         Considera por defecto/vacias como problema.
  -ShowValues     Muestra valores sensibles.
  -NoInteractive  Solo informa; no ofrece correcciones.
  -Help           Muestra esta ayuda.
"@
}

if ($Help) { Show-Help; exit 0 }

$ProjectPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Project))
$EnvPath = Join-Path $ProjectPath $Env
$ExamplePath = Join-Path $ProjectPath $Example
if (-not (Test-Path -LiteralPath $ExamplePath)) { Write-Host "[ERROR] No existe $ExamplePath" -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $EnvPath)) { Write-Host "[ERROR] No existe $EnvPath" -ForegroundColor Red; exit 2 }

function Get-KeyFromLine([string]$Line) {
    if ($Line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=') { return $Matches[1] }
    return $null
}

function Normalize-Value([string]$Value) {
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[$v.Length-1] -eq '"') -or ($v[0] -eq "'" -and $v[$v.Length-1] -eq "'"))) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    return $v
}

function Parse-EnvFile([string]$Path) {
    $lines = [IO.File]::ReadAllLines($Path)
    $items = @()
    $invalid = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }
        if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
            $items += [pscustomobject]@{ Key=$Matches[1]; RawValue=$Matches[2]; Value=(Normalize-Value $Matches[2]); Line=$i+1; Raw=$line }
        } else {
            $invalid += [pscustomobject]@{ Line=$i+1; Raw=$line }
        }
    }
    $groups = $items | Group-Object Key
    $effective = @{}
    foreach ($g in $groups) { $effective[$g.Name] = $g.Group[-1] }
    [pscustomobject]@{ Lines=$lines; Items=$items; Groups=$groups; Effective=$effective; Invalid=$invalid }
}

function Is-Sensitive([string]$Key) {
    return $Key -match '(?i)(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APP_KEY|PRIVATE|CREDENTIAL|DATABASE_URL|DSN)'
}

function Display-Value([string]$Key, [string]$Value) {
    if (-not $ShowValues -and (Is-Sensitive $Key)) { return "<oculto, $($Value.Length) caracteres>" }
    if ([string]::IsNullOrEmpty($Value)) { return '<vacio>' }
    return $Value
}

function Analyze {
    $script:Guide = Parse-EnvFile $ExamplePath
    $script:Current = Parse-EnvFile $EnvPath
    $gKeys = @($Guide.Effective.Keys)
    $cKeys = @($Current.Effective.Keys)
    $script:Missing = @($gKeys | Where-Object { -not $Current.Effective.ContainsKey($_) } | Sort-Object)
    $script:Extra = @($cKeys | Where-Object { -not $Guide.Effective.ContainsKey($_) } | Sort-Object)
    $script:Defaults = @()
    $script:Adjusted = @()
    $script:Empty = @()
    foreach ($key in $gKeys | Where-Object { $Current.Effective.ContainsKey($_) } | Sort-Object) {
        $cv = $Current.Effective[$key].Value
        $gv = $Guide.Effective[$key].Value
        if ([string]::IsNullOrWhiteSpace($cv) -or $cv -match '^(?i:null)$') { $script:Empty += $key }
        if ($cv -eq $gv) { $script:Defaults += $key } else { $script:Adjusted += $key }
    }
    $script:Duplicates = @($Current.Groups | Where-Object Count -gt 1 | Sort-Object Name)
}

function Print-Report {
    Clear-Host
    Write-Host '========================================================================' -ForegroundColor Cyan
    Write-Host ' VERIFICACION DE VARIABLES DE ENTORNO - LARAVEL' -ForegroundColor Cyan
    Write-Host '========================================================================' -ForegroundColor Cyan
    Write-Host "Proyecto: $ProjectPath"
    Write-Host "Guia:     $Example"
    Write-Host "Actual:   $Env"
    Write-Host ''
    Write-Host "Resumen: guia=$($Guide.Effective.Count) actual=$($Current.Effective.Count) faltan=$($Missing.Count) sobran=$($Extra.Count) por_defecto=$($Defaults.Count) ajustadas=$($Adjusted.Count) vacias=$($Empty.Count) duplicadas=$($Duplicates.Count) invalidas=$($Current.Invalid.Count)"

    if ($Missing.Count) { Write-Host "`nFALTAN EN $Env" -ForegroundColor Red; $Missing | ForEach-Object { Write-Host "  - $_ = $(Display-Value $_ $Guide.Effective[$_].Value)" } }
    if ($Extra.Count) { Write-Host "`nSOBRAN EN $Env" -ForegroundColor Yellow; $Extra | ForEach-Object { Write-Host "  - $_ = $(Display-Value $_ $Current.Effective[$_].Value)" } }
    if ($Defaults.Count) { Write-Host "`nSIGUEN CON VALOR POR DEFECTO" -ForegroundColor Yellow; $Defaults | ForEach-Object { Write-Host "  - $_ = $(Display-Value $_ $Current.Effective[$_].Value)" } }
    if ($Empty.Count) { Write-Host "`nVACIAS O NULAS" -ForegroundColor Yellow; $Empty | ForEach-Object { Write-Host "  - $_" } }
    if ($Duplicates.Count) { Write-Host "`nDUPLICADAS" -ForegroundColor Red; foreach ($d in $Duplicates) { Write-Host "  - $($d.Name): lineas $(($d.Group.Line -join ', '))" } }
    if ($Current.Invalid.Count) { Write-Host "`nLINEAS NO INTERPRETADAS" -ForegroundColor Red; $Current.Invalid | ForEach-Object { Write-Host "  - linea $($_.Line): $($_.Raw)" } }
    if (-not $OnlyProblems -and $Adjusted.Count) { Write-Host "`nVALORES AJUSTADOS" -ForegroundColor Green; $Adjusted | ForEach-Object { Write-Host "  - $_: $(Display-Value $_ $Current.Effective[$_].Value)" } }
}

$script:BackupCreated = $false
function Ensure-Backup {
    if ($BackupCreated) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$EnvPath.bak-$stamp"
    Copy-Item -LiteralPath $EnvPath -Destination $backup -Force
    $script:BackupCreated = $true
    Write-Host "[OK] Copia de seguridad: $backup" -ForegroundColor Green
}

function Save-Lines([string[]]$Lines) {
    Ensure-Backup
    [IO.File]::WriteAllLines($EnvPath, $Lines, [Text.UTF8Encoding]::new($false))
}

function Add-Missing {
    if (-not $Missing.Count) { Write-Host '[OK] No faltan variables.'; return }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]]$Current.Lines)
    if ($lines.Count -and $lines[$lines.Count-1] -ne '') { $lines.Add('') }
    $lines.Add('# Variables agregadas automaticamente desde .env.example')
    foreach ($key in $Missing) { $lines.Add("$key=$($Guide.Effective[$key].RawValue)") }
    Save-Lines $lines.ToArray()
    Write-Host "[OK] Se agregaron $($Missing.Count) variables faltantes." -ForegroundColor Green
}

function Remove-Extra {
    if (-not $Extra.Count) { Write-Host '[OK] No sobran variables.'; return }
    $set = @{}; $Extra | ForEach-Object { $set[$_] = $true }
    $new = foreach ($line in $Current.Lines) { $key = Get-KeyFromLine $line; if (-not $key -or -not $set.ContainsKey($key)) { $line } }
    Save-Lines ([string[]]$new)
    Write-Host "[OK] Se quitaron $($Extra.Count) variables no documentadas." -ForegroundColor Green
}

function Remove-Duplicates {
    if (-not $Duplicates.Count) { Write-Host '[OK] No hay duplicadas.'; return }
    $last = @{}
    for ($i=0; $i -lt $Current.Lines.Count; $i++) { $k=Get-KeyFromLine $Current.Lines[$i]; if ($k) { $last[$k]=$i } }
    $new = for ($i=0; $i -lt $Current.Lines.Count; $i++) { $k=Get-KeyFromLine $Current.Lines[$i]; if (-not $k -or $last[$k] -eq $i) { $Current.Lines[$i] } }
    Save-Lines ([string[]]$new)
    Write-Host '[OK] Duplicadas resueltas conservando la ultima definicion efectiva.' -ForegroundColor Green
}

function Set-EnvValue([string]$Key, [string]$Value) {
    $lines = [string[]](Parse-EnvFile $EnvPath).Lines
    $indices = @()
    for ($i=0; $i -lt $lines.Count; $i++) { if ((Get-KeyFromLine $lines[$i]) -eq $Key) { $indices += $i } }
    if (-not $indices.Count) { return }
    $last = $indices[-1]
    $out = for ($i=0; $i -lt $lines.Count; $i++) {
        if ($indices -contains $i -and $i -ne $last) { continue }
        if ($i -eq $last) { "$Key=$Value" } else { $lines[$i] }
    }
    Save-Lines ([string[]]$out)
}

function Review-Values {
    Analyze
    $keys = @($Defaults + $Empty | Sort-Object -Unique)
    if (-not $keys.Count) { Write-Host '[OK] No hay valores por defecto o vacios para revisar.'; return }
    foreach ($key in $keys) {
        Analyze
        $currentValue = $Current.Effective[$key].Value
        $guideValue = $Guide.Effective[$key].Value
        Write-Host "`n$key" -ForegroundColor Cyan
        Write-Host "  actual: $(Display-Value $key $currentValue)"
        Write-Host "  guia:   $(Display-Value $key $guideValue)"
        $answer = Read-Host 'Nuevo valor (ENTER=dejar igual, !default=usar valor de la guia)'
        if ($answer -eq '') { continue }
        if ($answer -eq '!default') { $answer = $Guide.Effective[$key].RawValue }
        Set-EnvValue $key $answer
        Write-Host "[OK] $key actualizado." -ForegroundColor Green
    }
}

function Interactive-Menu {
    while ($true) {
        Analyze; Print-Report
        Write-Host "`nCORREGIR CONFIGURACION" -ForegroundColor Cyan
        Write-Host '  1) Agregar variables faltantes desde .env.example'
        Write-Host '  2) Quitar variables sobrantes de .env'
        Write-Host '  3) Resolver variables duplicadas (conservar ultima)'
        Write-Host '  4) Revisar valores por defecto o vacios uno por uno'
        Write-Host '  5) Aplicar correcciones seguras: 1 + 2 + 3'
        Write-Host '  6) Volver a verificar'
        Write-Host '  0) Salir sin mas cambios'
        $choice = Read-Host 'Seleccione una opcion'
        switch ($choice) {
            '1' { Add-Missing }
            '2' { Remove-Extra }
            '3' { Remove-Duplicates }
            '4' { Review-Values }
            '5' { Add-Missing; Analyze; Remove-Extra; Analyze; Remove-Duplicates }
            '6' { continue }
            '0' { return }
            default { Write-Host '[AVISO] Opcion no valida.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
        Analyze
        Write-Host "`nPresione ENTER para volver a verificar..."
        [void](Read-Host)
    }
}

Analyze
Print-Report
$baseProblems = $Missing.Count + $Extra.Count + $Duplicates.Count + $Current.Invalid.Count
$strictProblems = $baseProblems + $Defaults.Count + $Empty.Count
if (-not $NoInteractive -and [Environment]::UserInteractive) { Interactive-Menu; Analyze; Print-Report }

if ($Strict) { if ($strictProblems -gt 0) { exit 1 } } else { if ($baseProblems -gt 0) { exit 1 } }
exit 0
