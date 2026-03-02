# Build Ultra-Otimizado - Flutter Web Performance
# ================================================
# Execute com: .\build_web_optimized.ps1

param(
    [switch]$WasmMode = $false,
    [switch]$SkipClean = $false,
    [switch]$Analyze = $false
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FLUTTER WEB - BUILD OTIMIZADO        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Configurações
if ($WasmMode) { $BuildMode = "WASM (Experimental)" } else { $BuildMode = "JavaScript" }
Write-Host "[INFO] Modo de build: $BuildMode" -ForegroundColor Blue
Write-Host ""

# 1. Limpar build anterior (opcional)
if (-not $SkipClean) {
    Write-Host "[1/5] Limpando build anterior..." -ForegroundColor Yellow
    flutter clean
    Write-Host "      + Cache limpo" -ForegroundColor Green
} else {
    Write-Host "[1/5] Pulando limpeza" -ForegroundColor Gray
}

# 2. Obter dependências
Write-Host ""
Write-Host "[2/5] Obtendo dependencias..." -ForegroundColor Yellow
flutter pub get
Write-Host "      + Dependencias atualizadas" -ForegroundColor Green

# 3. Análise estática (opcional)
if ($Analyze) {
    Write-Host ""
    Write-Host "[3/5] Executando analise estatica..." -ForegroundColor Yellow
    flutter analyze --no-fatal-infos
} else {
    Write-Host ""
    Write-Host "[3/5] Pulando analise (use -Analyze para ativar)" -ForegroundColor Gray
}

# 4. Build principal
Write-Host ""
Write-Host "[4/5] Construindo para web..." -ForegroundColor Yellow
Write-Host "      - Tree shake icons: ON" -ForegroundColor Gray
Write-Host "      - Minificacao: ON" -ForegroundColor Gray
Write-Host "      - Otimizacao: O4" -ForegroundColor Gray
Write-Host ""

if ($WasmMode) {
    # Build com WASM
    flutter build web `
        --wasm `
        --release `
        --tree-shake-icons `
        -O4 `
        --no-source-maps `
        --dart-define=FLUTTER_WEB_USE_SKIA=true
} else {
    # Build padrão JavaScript
    flutter build web `
        --release `
        --tree-shake-icons `
        --dart-define=FLUTTER_WEB_USE_SKIA=false `
        --dart-define=FLUTTER_WEB_AUTO_DETECT=true
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "X ERRO no build! Verifique os logs acima." -ForegroundColor Red
    exit 1
}

Write-Host "      + Build concluido!" -ForegroundColor Green

# 5. Otimizações pós-build
Write-Host ""
Write-Host "[5/5] Analisando build..." -ForegroundColor Yellow

$buildPath = "build\web"

if (Test-Path $buildPath) {
    $totalSize = (Get-ChildItem -Path $buildPath -Recurse | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
    Write-Host "      + Tamanho total: $totalSizeMB MB" -ForegroundColor Green
}

$endTime = Get-Date
$duration = $endTime - $startTime
$durationSec = [math]::Round($duration.TotalSeconds, 1)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BUILD FINALIZADO ($durationSec s)  " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output: $buildPath" -ForegroundColor White
Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Blue
Write-Host "  1. Testar localmente:" -ForegroundColor White
Write-Host "     flutter run -d chrome --release" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Servir build:" -ForegroundColor White
Write-Host "     cd build\web ; python -m http.server 8080" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Deploy para producao:" -ForegroundColor White
Write-Host "     Copie a pasta build\web\ para seu servidor" -ForegroundColor Gray
Write-Host ""

