# Script de Auditoria de Seguranca - Sistema de Carrinho
# MenuHub Totem - v1.0
# Data: 23/11/2025

Write-Host "AUDITORIA DE SEGURANCA - SISTEMA DE CARRINHO" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$projectRoot = $PSScriptRoot
$backendPath = Join-Path (Split-Path $projectRoot) "Backend"
$results = @()

# Funcao para adicionar resultado
function Add-Result {
    param($Category, $Item, $Status, $Severity, $Details)
    $script:results += [PSCustomObject]@{
        Category = $Category
        Item = $Item
        Status = $Status
        Severity = $Severity
        Details = $Details
    }
}

# 1. SEGURANCA - VALIDACAO DE PRECOS
Write-Host "1. Verificando Validacao de Precos..." -ForegroundColor Yellow

$cartRoutes = Get-Content "$backendPath\src\api\app\routes\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartRoutes) {
    if ($cartRoutes -match "recalculate|calculate_total|calculate_subtotal") {
        Add-Result "Seguranca" "Recalculo de Precos" "PASS" "CRITICO" "Backend recalcula precos"
    } else {
        Add-Result "Seguranca" "Recalculo de Precos" "FAIL" "CRITICO" "Nao encontrado recalculo explicito de precos"
    }
    
    if ($cartRoutes -match "current_user|get_current_user|Depends.*auth") {
        Add-Result "Seguranca" "Validacao de Ownership" "PASS" "CRITICO" "Autenticacao encontrada"
    } else {
        Add-Result "Seguranca" "Validacao de Ownership" "WARN" "CRITICO" "Autenticacao nao claramente identificada"
    }
} else {
    Add-Result "Seguranca" "Arquivo cart.py" "FAIL" "CRITICO" "Arquivo nao encontrado: $backendPath\src\api\app\routes\cart.py"
}

# 2. SEGURANCA - SANITIZACAO DE INPUTS
Write-Host "2. Verificando Sanitizacao de Inputs..." -ForegroundColor Yellow

$cartSchema = Get-Content "$backendPath\src\api\schemas\orders\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartSchema) {
    if ($cartSchema -match "validator|Field.*max_length|constr") {
        Add-Result "Seguranca" "Validacao de Inputs (Pydantic)" "PASS" "ALTO" "Validadores encontrados"
    } else {
        Add-Result "Seguranca" "Validacao de Inputs (Pydantic)" "WARN" "ALTO" "Validadores nao identificados"
    }
} else {
    Add-Result "Seguranca" "Schema cart.py" "FAIL" "ALTO" "Arquivo nao encontrado"
}

$updatePayload = Get-Content "$projectRoot\lib\models\update_cart_payload.dart" -Raw -ErrorAction SilentlyContinue
if ($updatePayload) {
    if ($updatePayload -match "sanitize|htmlEscape|validator") {
        Add-Result "Seguranca" "Sanitizacao XSS (Frontend)" "PASS" "ALTO" "Sanitizacao encontrada"
    } else {
        Add-Result "Seguranca" "Sanitizacao XSS (Frontend)" "WARN" "ALTO" "Sanitizacao nao identificada no payload"
    }
}

# 3. PERFORMANCE - QUERIES N+1
Write-Host "3. Verificando Otimizacao de Queries..." -ForegroundColor Yellow

$cartModel = Get-Content "$backendPath\src\core\models\business\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartModel) {
    if ($cartModel -match "lazy=|joinedload|selectinload|relationship.*lazy") {
        Add-Result "Performance" "Eager Loading" "PASS" "ALTO" "Estrategias de loading identificadas"
    } else {
        Add-Result "Performance" "Eager Loading" "WARN" "ALTO" "Eager loading nao claramente definido"
    }
}

# 4. VALIDACOES DE NEGOCIO
Write-Host "4. Verificando Validacoes de Negocio..." -ForegroundColor Yellow

$checkoutCubit = Get-Content "$projectRoot\lib\pages\checkout\checkout_cubit.dart" -Raw -ErrorAction SilentlyContinue
if ($checkoutCubit) {
    if ($checkoutCubit -match "isOpen|store.*open|working.*hours") {
        Add-Result "Negocio" "Validacao de Horario" "PASS" "CRITICO" "Validacao de horario encontrada"
    } else {
        Add-Result "Negocio" "Validacao de Horario" "WARN" "CRITICO" "Validacao de horario nao identificada"
    }
    
    if ($checkoutCubit -match "minimum.*order|valor.*minimo|min.*value") {
        Add-Result "Negocio" "Validacao de Valor Minimo" "PASS" "ALTO" "Validacao encontrada"
    } else {
        Add-Result "Negocio" "Validacao de Valor Minimo" "WARN" "ALTO" "Validacao nao identificada"
    }
}

# 5. TRATAMENTO DE ERROS
Write-Host "5. Verificando Tratamento de Erros..." -ForegroundColor Yellow

$cartCubit = Get-Content "$projectRoot\lib\pages\cart\cart_cubit.dart" -Raw -ErrorAction SilentlyContinue
if ($cartCubit) {
    $tryCount = ([regex]::Matches($cartCubit, "try\s*\{")).Count
    $catchCount = ([regex]::Matches($cartCubit, "catch\s*\(")).Count
    
    if ($tryCount -eq $catchCount -and $tryCount -gt 0) {
        Add-Result "Qualidade" "Try-Catch Balance" "PASS" "MEDIO" "$tryCount blocos try-catch encontrados"
    } else {
        Add-Result "Qualidade" "Try-Catch Balance" "WARN" "MEDIO" "Try: $tryCount, Catch: $catchCount"
    }
    
    if ($cartCubit -match "rethrow") {
        Add-Result "Qualidade" "Propagacao de Erros" "PASS" "MEDIO" "Erros sao propagados corretamente"
    }
}

# 6. TESTES
Write-Host "6. Verificando Cobertura de Testes..." -ForegroundColor Yellow

$testDir = Join-Path $projectRoot "test"
if (Test-Path $testDir) {
    $testFiles = Get-ChildItem -Path $testDir -Filter "*cart*test.dart" -Recurse
    if ($testFiles.Count -gt 0) {
        Add-Result "Testes" "Testes de Carrinho" "PASS" "ALTO" "$($testFiles.Count) arquivos de teste encontrados"
    } else {
        Add-Result "Testes" "Testes de Carrinho" "FAIL" "ALTO" "Nenhum teste de carrinho encontrado"
    }
} else {
    Add-Result "Testes" "Diretorio de Testes" "FAIL" "ALTO" "Diretorio test/ nao encontrado"
}

# 7. LOGS E MONITORAMENTO
Write-Host "7. Verificando Logs..." -ForegroundColor Yellow

if ($cartCubit -match "print\(") {
    $printCount = ([regex]::Matches($cartCubit, "print\(")).Count
    Add-Result "Monitoramento" "Logs de Debug" "WARN" "MEDIO" "$printCount prints encontrados (usar logger estruturado)"
}

if ($cartCubit -match "logger\.|log\.|Logger") {
    Add-Result "Monitoramento" "Logger Estruturado" "PASS" "MEDIO" "Logger estruturado encontrado"
} else {
    Add-Result "Monitoramento" "Logger Estruturado" "FAIL" "MEDIO" "Logger estruturado nao encontrado"
}

# 8. RATE LIMITING
Write-Host "8. Verificando Rate Limiting..." -ForegroundColor Yellow

if ($cartRoutes) {
    if ($cartRoutes -match "limiter|rate_limit|RateLimiter|slowapi") {
        Add-Result "Seguranca" "Rate Limiting" "PASS" "ALTO" "Rate limiting implementado"
    } else {
        Add-Result "Seguranca" "Rate Limiting" "FAIL" "ALTO" "Rate limiting nao encontrado"
    }
}

# 9. TRANSACOES ACID
Write-Host "9. Verificando Transacoes..." -ForegroundColor Yellow

if ($cartRoutes) {
    if ($cartRoutes -match "transaction|commit|rollback|db\.begin") {
        Add-Result "Integridade" "Transacoes ACID" "PASS" "CRITICO" "Transacoes identificadas"
    } else {
        Add-Result "Integridade" "Transacoes ACID" "WARN" "CRITICO" "Transacoes nao claramente identificadas"
    }
}

# 10. DOCUMENTACAO
Write-Host "10. Verificando Documentacao..." -ForegroundColor Yellow

$readme = Get-Content "$projectRoot\README.md" -Raw -ErrorAction SilentlyContinue
if ($readme -and $readme.Length -gt 100) {
    Add-Result "Documentacao" "README.md" "PASS" "BAIXO" "README existe e tem conteudo"
} else {
    Add-Result "Documentacao" "README.md" "WARN" "BAIXO" "README vazio ou inexistente"
}

# RELATORIO FINAL
Write-Host ""
Write-Host "RELATORIO DE AUDITORIA" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# Agrupar por severidade
$critical = $results | Where-Object { $_.Severity -eq "CRITICO" }
$high = $results | Where-Object { $_.Severity -eq "ALTO" }
$medium = $results | Where-Object { $_.Severity -eq "MEDIO" }
$low = $results | Where-Object { $_.Severity -eq "BAIXO" }

# Contar status
$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$warned = ($results | Where-Object { $_.Status -eq "WARN" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $results.Count

Write-Host "RESUMO GERAL" -ForegroundColor White
Write-Host "  Total de Verificacoes: $total" -ForegroundColor White
$passedPct = [math]::Round($passed/$total*100, 1)
$warnedPct = [math]::Round($warned/$total*100, 1)
$failedPct = [math]::Round($failed/$total*100, 1)
Write-Host "  Passou: $passed ($passedPct porcento)" -ForegroundColor Green
Write-Host "  Aviso: $warned ($warnedPct porcento)" -ForegroundColor Yellow
Write-Host "  Falhou: $failed ($failedPct porcento)" -ForegroundColor Red
Write-Host ""

# Mostrar itens criticos
if ($critical.Count -gt 0) {
    Write-Host "ITENS CRITICOS ($($critical.Count))" -ForegroundColor Red
    $critical | ForEach-Object {
        $color = if ($_.Status -eq "PASS") { "Green" } elseif ($_.Status -eq "WARN") { "Yellow" } else { "Red" }
        Write-Host "  [$($_.Status)] $($_.Category) - $($_.Item)" -ForegroundColor $color
        Write-Host "     $($_.Details)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Mostrar itens de alta prioridade com falha
$highFailed = $high | Where-Object { $_.Status -ne "PASS" }
if ($highFailed.Count -gt 0) {
    Write-Host "ITENS DE ALTA PRIORIDADE COM PROBLEMAS ($($highFailed.Count))" -ForegroundColor DarkYellow
    $highFailed | ForEach-Object {
        $color = if ($_.Status -eq "WARN") { "Yellow" } else { "Red" }
        Write-Host "  [$($_.Status)] $($_.Category) - $($_.Item)" -ForegroundColor $color
        Write-Host "     $($_.Details)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Salvar relatorio em arquivo
$reportPath = Join-Path $projectRoot "AUDITORIA_RESULTADO_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$reportLines = @()
$reportLines += "# Relatorio de Auditoria - Sistema de Carrinho"
$reportLines += "**Data**: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$reportLines += "**Projeto**: MenuHub Totem"
$reportLines += ""
$reportLines += "## Resumo Executivo"
$reportLines += "- Total de Verificacoes: $total"
$reportLines += "- Passou: $passed ($passedPct porcento)"
$reportLines += "- Aviso: $warned ($warnedPct porcento)"
$reportLines += "- Falhou: $failed ($failedPct porcento)"
$reportLines += ""
$reportLines += "## Resultados Detalhados"
$reportLines += ""

foreach ($category in ($results | Group-Object -Property Category)) {
    $reportLines += "### $($category.Name)"
    $reportLines += ""
    foreach ($item in $category.Group) {
        $reportLines += "- **$($item.Item)** [$($item.Severity)]"
        $reportLines += "  - Status: $($item.Status)"
        $reportLines += "  - Detalhes: $($item.Details)"
        $reportLines += ""
    }
}

$reportLines += ""
$reportLines += "## Recomendacoes Prioritarias"
$reportLines += ""
$reportLines += "### Acao Imediata (Critico)"

$criticalFailed = $critical | Where-Object { $_.Status -ne "PASS" }
if ($criticalFailed.Count -gt 0) {
    foreach ($item in $criticalFailed) {
        $reportLines += "- [ ] **$($item.Item)**: $($item.Details)"
    }
} else {
    $reportLines += "- Nenhum item critico pendente"
}

$reportLines += ""
$reportLines += "### Acao Necessaria (Alto)"

if ($highFailed.Count -gt 0) {
    foreach ($item in $highFailed) {
        $reportLines += "- [ ] **$($item.Item)**: $($item.Details)"
    }
} else {
    $reportLines += "- Nenhum item de alta prioridade pendente"
}

$reportContent = $reportLines -join "`r`n"
$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Relatorio salvo em: $reportPath" -ForegroundColor Green
Write-Host ""

# Score final
$score = [math]::Round(($passed / $total) * 100, 1)
$scoreColor = if ($score -ge 80) { "Green" } elseif ($score -ge 60) { "Yellow" } else { "Red" }

Write-Host "SCORE DE SEGURANCA: $score porcento" -ForegroundColor $scoreColor
Write-Host ""

if ($score -lt 70) {
    Write-Host "ATENCAO: Score abaixo de 70 porcento. Recomenda-se revisao antes do deploy em producao." -ForegroundColor Red
} elseif ($score -lt 85) {
    Write-Host "Score aceitavel, mas ha melhorias importantes a fazer." -ForegroundColor Yellow
} else {
    Write-Host "Score bom! Continue monitorando e melhorando." -ForegroundColor Green
}

Write-Host ""
Write-Host "Para mais detalhes, consulte: AUDITORIA_CARRINHO_CHECKOUT.md" -ForegroundColor Cyan
