# Script para Rodar o Totem em Release (Localhost)
# ================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      RODANDO TOTEM EM RELEASE          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$buildPath = "build\web"
$port = 8080

# 1. Verificar se o build existe ou se o usuário deseja reconstruir
if (Test-Path $buildPath) {
    $rebuild = Read-Host "O build já existe. Deseja reconstruir antes de rodar? (s/n)"
    if ($rebuild -eq "s") {
        Write-Host "[INFO] Reconstruindo..." -ForegroundColor Yellow
        .\build_web_optimized.ps1
    }
} else {
    Write-Host "[INFO] Build não encontrado. Iniciando build..." -ForegroundColor Yellow
    .\build_web_optimized.ps1
}

if (-not (Test-Path $buildPath)) {
    Write-Host "❌ Erro: Falha ao encontrar ou gerar o build em $buildPath" -ForegroundColor Red
    exit 1
}

# 2. Iniciar o Servidor Localhost
Write-Host ""
Write-Host "[INFO] Iniciando servidor localhost na porta $port..." -ForegroundColor Green
Write-Host "[INFO] Pressione Ctrl+C para encerrar o servidor quando terminar." -ForegroundColor Gray
Write-Host ""

# Abrir o navegador automaticamente
Start-Process "chrome" "http://localhost:$port"

# Rodar o servidor Python
Set-Location $buildPath
python -m http.server $port
