# Build Otimizado - Flutter Web + WASM

Write-Host "========================================"
Write-Host "  FLUTTER WEB - BUILD WASM OTIMIZADO   "
Write-Host "========================================"
Write-Host ""

# Limpar
Write-Host "[1/4] Limpando build anterior..." -ForegroundColor Yellow
flutter clean

# Dependências
Write-Host ""
Write-Host "[2/4] Obtendo dependências..." -ForegroundColor Yellow
flutter pub get

# Build
Write-Host ""
Write-Host "[3/4] Construindo com WASM..." -ForegroundColor Yellow
flutter build web --wasm --release --tree-shake-icons -O4 --source-maps

# Resultado
Write-Host ""
Write-Host "[4/4] ✅ Build concluído!" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Cyan
Write-Host "1. Testar: flutter run -d chrome --release"
Write-Host "2. Deploy: Copiar build\web\ para servidor"
Write-Host ""
