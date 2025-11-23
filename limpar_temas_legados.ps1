# Script de Limpeza - Remover Arquivos Legados de Temas
# Execute este script para remover os arquivos não utilizados

Write-Host "🧹 Iniciando limpeza de arquivos legados..." -ForegroundColor Cyan

$arquivosParaRemover = @(
    "lib\themes\HomeSelectorPage.dart",
    "lib\themes\HomeModernPage.dart",
    "lib\themes\HomeDarkBurguerPage.dart",
    "lib\themes\classic\Classic.dart"
)

$removidos = 0
$erros = 0

foreach ($arquivo in $arquivosParaRemover) {
    $caminhoCompleto = Join-Path $PSScriptRoot $arquivo
    
    if (Test-Path $caminhoCompleto) {
        try {
            Remove-Item $caminhoCompleto -Force
            Write-Host "✅ Removido: $arquivo" -ForegroundColor Green
            $removidos++
        }
        catch {
            Write-Host "❌ Erro ao remover: $arquivo" -ForegroundColor Red
            Write-Host "   Motivo: $_" -ForegroundColor Yellow
            $erros++
        }
    }
    else {
        Write-Host "⚠️  Arquivo não encontrado: $arquivo" -ForegroundColor Yellow
    }
}

Write-Host "`n📊 Resumo da Limpeza:" -ForegroundColor Cyan
Write-Host "   Arquivos removidos: $removidos" -ForegroundColor Green
Write-Host "   Erros: $erros" -ForegroundColor $(if ($erros -gt 0) { "Red" } else { "Green" })

if ($removidos -gt 0) {
    Write-Host "`n✅ Limpeza concluída com sucesso!" -ForegroundColor Green
    Write-Host "   Execute 'flutter clean' e 'flutter pub get' para atualizar o projeto." -ForegroundColor Yellow
}
else {
    Write-Host "`n⚠️  Nenhum arquivo foi removido." -ForegroundColor Yellow
}
