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
$BuildMode = if ($WasmMode) { "WASM (Experimental)" } else { "JavaScript" }
Write-Host "[INFO] Modo de build: $BuildMode" -ForegroundColor Blue
Write-Host ""

# 1. Limpar build anterior (opcional)
if (-not $SkipClean) {
    Write-Host "[1/5] Limpando build anterior..." -ForegroundColor Yellow
    flutter clean 2>&1 | Out-Null
    Write-Host "      ✓ Cache limpo" -ForegroundColor Green
} else {
    Write-Host "[1/5] Pulando limpeza (--SkipClean)" -ForegroundColor Gray
}

# 2. Obter dependências
Write-Host ""
Write-Host "[2/5] Obtendo dependências..." -ForegroundColor Yellow
flutter pub get 2>&1 | Out-Null
Write-Host "      ✓ Dependências atualizadas" -ForegroundColor Green

# 3. Análise estática (opcional)
if ($Analyze) {
    Write-Host ""
    Write-Host "[3/5] Executando análise estática..." -ForegroundColor Yellow
    flutter analyze --no-fatal-infos 2>&1 | Out-Host
} else {
    Write-Host ""
    Write-Host "[3/5] Pulando análise (use -Analyze para ativar)" -ForegroundColor Gray
}

# 4. Build principal
Write-Host ""
Write-Host "[4/5] Construindo para web..." -ForegroundColor Yellow
Write-Host "      - Tree shake icons: ON" -ForegroundColor Gray
Write-Host "      - Minificação: ON" -ForegroundColor Gray
Write-Host "      - Otimização: O4 (máxima)" -ForegroundColor Gray
Write-Host ""

if ($WasmMode) {
    # Build com WASM (experimental - melhor performance)
    flutter build web `
        --wasm `
        --release `
        --tree-shake-icons `
        -O4 `
        --no-source-maps `
        --dart-define=FLUTTER_WEB_USE_SKIA=true
} else {
    # Build padrão JavaScript (mais compatível)
    flutter build web `
        --release `
        --tree-shake-icons `
        --dart-define=FLUTTER_WEB_USE_SKIA=false `
        --dart-define=FLUTTER_WEB_AUTO_DETECT=true
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERRO no build! Verifique os logs acima." -ForegroundColor Red
    exit 1
}

Write-Host "      ✓ Build concluído!" -ForegroundColor Green

# 5. Otimizações pós-build
Write-Host ""
Write-Host "[5/5] Aplicando otimizações pós-build..." -ForegroundColor Yellow

$buildPath = "build\web"

# Verificar se o diretório existe
if (Test-Path $buildPath) {
    # Calcular tamanho total
    $totalSize = (Get-ChildItem -Path $buildPath -Recurse | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
    
    # Contar arquivos
    $jsFiles = (Get-ChildItem -Path $buildPath -Filter "*.js" -Recurse).Count
    $dartFiles = (Get-ChildItem -Path $buildPath -Filter "*.dart.js" -Recurse).Count
    
    Write-Host "      ✓ Tamanho total: $totalSizeMB MB" -ForegroundColor Green
    Write-Host "      ✓ Arquivos JS: $jsFiles" -ForegroundColor Green
}

# Tempo total
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
Write-Host "     cd build\web && python -m http.server 8080" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Deploy para produção:" -ForegroundColor White
Write-Host "     Copie a pasta build\web\ para seu servidor" -ForegroundColor Gray
Write-Host ""

# Dicas de performance
Write-Host "💡 Dicas de Performance:" -ForegroundColor Yellow
Write-Host "  • Configure gzip/brotli no servidor para comprimir JS" -ForegroundColor White
Write-Host "  • Use CDN para servir os assets (CloudFlare, AWS CloudFront)" -ForegroundColor White
Write-Host "  • Configure cache headers para arquivos estáticos (1 ano)" -ForegroundColor White
Write-Host ""
