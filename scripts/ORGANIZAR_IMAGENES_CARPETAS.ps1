$rutaCapturas = $PSScriptRoot
if (-not $rutaCapturas) { $rutaCapturas = Get-Location }

$archivos = Get-ChildItem -Path $rutaCapturas -File | Where-Object { $_.Extension -match "\.(png|jpg|jpeg|bmp)$" }

if ($archivos.Count -eq 0) {
    Write-Host "No hay capturas sueltas para organizar." -ForegroundColor Yellow
} else {
    Write-Host "Organizando $($archivos.Count) archivos..." -ForegroundColor Cyan

    foreach ($archivo in $archivos) {
        $fecha = $archivo.CreationTime
        $año = $fecha.ToString("yyyy")
        $mes = $fecha.ToString("MM")
        $dia = $fecha.ToString("dd")

        $carpetaDestino = Join-Path -Path $rutaCapturas -ChildPath "$año\$mes\$dia"

        if (-not (Test-Path -Path $carpetaDestino)) {
            New-Item -Path $carpetaDestino -ItemType Directory | Out-Null
        }

        Move-Item -Path $archivo.FullName -Destination $carpetaDestino -Force
        Write-Host "[OK] Movido: $($archivo.Name) -> $año/$mes/$dia" -ForegroundColor Green
    }

    Write-Host "`n¡Organización completada con éxito!" -ForegroundColor Cyan
}
pause
