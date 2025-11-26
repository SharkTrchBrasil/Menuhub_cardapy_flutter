# Script de Auditoria de Segurança - Sistema de Carrinho
# MenuHub Totem - v1.0
# Data: 23/11/2025

Write-Host "🔍 AUDITORIA DE SEGURANÇA - SISTEMA DE CARRINHO" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$projectRoot = $PSScriptRoot
$backendPath = Join-Path (Split-Path $projectRoot) "Backend"
$results = @()

# Função para adicionar resultado
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

# ========================================
# 1. SEGURANÇA - VALIDAÇÃO DE PREÇOS
# ========================================
Write-Host "1️⃣  Verificando Validação de Preços..." -ForegroundColor Yellow

# Verificar se preços são recalculados no backend
$cartRoutes = Get-Content "$backendPath\src\api\app\routes\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartRoutes) {
    if ($cartRoutes -match "recalculate|calculate_total|calculate_subtotal") {
        Add-Result "Segurança" "Recálculo de Preços" "✅ PASS" "CRÍTICO" "Backend recalcula preços"
    } else {
        Add-Result "Segurança" "Recálculo de Preços" "❌ FAIL" "CRÍTICO" "Não encontrado recálculo explícito de preços"
    }
    
    # Verificar se há validação de ownership
    if ($cartRoutes -match "current_user|get_current_user|Depends.*auth") {
        Add-Result "Segurança" "Validação de Ownership" "✅ PASS" "CRÍTICO" "Autenticação encontrada"
    } else {
        Add-Result "Segurança" "Validação de Ownership" "⚠️  WARN" "CRÍTICO" "Autenticação não claramente identificada"
    }
} else {
    Add-Result "Segurança" "Arquivo cart.py" "❌ FAIL" "CRÍTICO" "Arquivo não encontrado: $backendPath\src\api\app\routes\cart.py"
}

# ========================================
# 2. SEGURANÇA - SANITIZAÇÃO DE INPUTS
# ========================================
Write-Host "2️⃣  Verificando Sanitização de Inputs..." -ForegroundColor Yellow

# Verificar schemas Pydantic
$cartSchema = Get-Content "$backendPath\src\api\schemas\orders\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartSchema) {
    if ($cartSchema -match "validator|Field.*max_length|constr") {
        Add-Result "Segurança" "Validação de Inputs (Pydantic)" "✅ PASS" "ALTO" "Validadores encontrados"
    } else {
        Add-Result "Segurança" "Validação de Inputs (Pydantic)" "⚠️  WARN" "ALTO" "Validadores não identificados"
    }
} else {
    Add-Result "Segurança" "Schema cart.py" "❌ FAIL" "ALTO" "Arquivo não encontrado"
}

# Verificar XSS no frontend
$updatePayload = Get-Content "$projectRoot\lib\models\update_cart_payload.dart" -Raw -ErrorAction SilentlyContinue
if ($updatePayload) {
    if ($updatePayload -match "sanitize|htmlEscape|validator") {
        Add-Result "Segurança" "Sanitização XSS (Frontend)" "✅ PASS" "ALTO" "Sanitização encontrada"
    } else {
        Add-Result "Segurança" "Sanitização XSS (Frontend)" "⚠️  WARN" "ALTO" "Sanitização não identificada no payload"
    }
}

# ========================================
# 3. PERFORMANCE - QUERIES N+1
# ========================================
Write-Host "3️⃣  Verificando Otimização de Queries..." -ForegroundColor Yellow

$cartModel = Get-Content "$backendPath\src\core\models\business\cart.py" -Raw -ErrorAction SilentlyContinue
if ($cartModel) {
    if ($cartModel -match "lazy=|joinedload|selectinload|relationship.*lazy") {
        Add-Result "Performance" "Eager Loading" "✅ PASS" "ALTO" "Estratégias de loading identificadas"
    } else {
        Add-Result "Performance" "Eager Loading" "⚠️  WARN" "ALTO" "Eager loading não claramente definido"
    }
}

# ========================================
# 4. VALIDAÇÕES DE NEGÓCIO
# ========================================
Write-Host "4️⃣  Verificando Validações de Negócio..." -ForegroundColor Yellow

$checkoutCubit = Get-Content "$projectRoot\lib\pages\checkout\checkout_cubit.dart" -Raw -ErrorAction SilentlyContinue
if ($checkoutCubit) {
    # Verificar validação de horário
    if ($checkoutCubit -match "isOpen|store.*open|working.*hours") {
        Add-Result "Negócio" "Validação de Horário" "✅ PASS" "CRÍTICO" "Validação de horário encontrada"
    } else {
        Add-Result "Negócio" "Validação de Horário" "⚠️  WARN" "CRÍTICO" "Validação de horário não identificada"
    }
    
    # Verificar valor mínimo
    if ($checkoutCubit -match "minimum.*order|valor.*minimo|min.*value") {
        Add-Result "Negócio" "Validação de Valor Mínimo" "✅ PASS" "ALTO" "Validação encontrada"
    } else {
        Add-Result "Negócio" "Validação de Valor Mínimo" "⚠️  WARN" "ALTO" "Validação não identificada"
    }
}

# ========================================
# 5. TRATAMENTO DE ERROS
# ========================================
Write-Host "5️⃣  Verificando Tratamento de Erros..." -ForegroundColor Yellow

$cartCubit = Get-Content "$projectRoot\lib\pages\cart\cart_cubit.dart" -Raw -ErrorAction SilentlyContinue
if ($cartCubit) {
    $tryCount = ([regex]::Matches($cartCubit, "try\s*\{")).Count
    $catchCount = ([regex]::Matches($cartCubit, "catch\s*\(")).Count
    
    if ($tryCount -eq $catchCount -and $tryCount -gt 0) {
        Add-Result "Qualidade" "Try-Catch Balance" "✅ PASS" "MÉDIO" "$tryCount blocos try-catch encontrados"
    } else {
        Add-Result "Qualidade" "Try-Catch Balance" "⚠️  WARN" "MÉDIO" "Try: $tryCount, Catch: $catchCount"
    }
    
    # Verificar se há re-throw de erros
    if ($cartCubit -match "rethrow") {
        Add-Result "Qualidade" "Propagação de Erros" "✅ PASS" "MÉDIO" "Erros são propagados corretamente"
    }
}

# ========================================
# 6. TESTES
# ========================================
Write-Host "6️⃣  Verificando Cobertura de Testes..." -ForegroundColor Yellow

$testDir = Join-Path $projectRoot "test"
if (Test-Path $testDir) {
    $testFiles = Get-ChildItem -Path $testDir -Filter "*cart*test.dart" -Recurse
    if ($testFiles.Count -gt 0) {
        Add-Result "Testes" "Testes de Carrinho" "✅ PASS" "ALTO" "$($testFiles.Count) arquivos de teste encontrados"
    } else {
        Add-Result "Testes" "Testes de Carrinho" "❌ FAIL" "ALTO" "Nenhum teste de carrinho encontrado"
    }
} else {
    Add-Result "Testes" "Diretório de Testes" "❌ FAIL" "ALTO" "Diretório test/ não encontrado"
}

# ========================================
# 7. LOGS E MONITORAMENTO
# ========================================
Write-Host "7️⃣  Verificando Logs..." -ForegroundColor Yellow

if ($cartCubit -match "print\(") {
    $printCount = ([regex]::Matches($cartCubit, "print\(")).Count
    Add-Result "Monitoramento" "Logs de Debug" "⚠️  WARN" "MÉDIO" "$printCount prints encontrados (usar logger estruturado)"
}

# Verificar se há logger estruturado
if ($cartCubit -match "logger\.|log\.|Logger") {
    Add-Result "Monitoramento" "Logger Estruturado" "✅ PASS" "MÉDIO" "Logger estruturado encontrado"
} else {
    Add-Result "Monitoramento" "Logger Estruturado" "❌ FAIL" "MÉDIO" "Logger estruturado não encontrado"
}

# ========================================
# 8. RATE LIMITING
# ========================================
Write-Host "8️⃣  Verificando Rate Limiting..." -ForegroundColor Yellow

if ($cartRoutes) {
    if ($cartRoutes -match "limiter|rate_limit|RateLimiter|slowapi") {
        Add-Result "Segurança" "Rate Limiting" "✅ PASS" "ALTO" "Rate limiting implementado"
    } else {
        Add-Result "Segurança" "Rate Limiting" "❌ FAIL" "ALTO" "Rate limiting não encontrado"
    }
}

# ========================================
# 9. TRANSAÇÕES ACID
# ========================================
Write-Host "9️⃣  Verificando Transações..." -ForegroundColor Yellow

if ($cartRoutes) {
    if ($cartRoutes -match "transaction|commit|rollback|db\.begin") {
        Add-Result "Integridade" "Transações ACID" "✅ PASS" "CRÍTICO" "Transações identificadas"
    } else {
        Add-Result "Integridade" "Transações ACID" "⚠️  WARN" "CRÍTICO" "Transações não claramente identificadas"
    }
}

# ========================================
# 10. DOCUMENTAÇÃO
# ========================================
Write-Host "🔟 Verificando Documentação..." -ForegroundColor Yellow

$readme = Get-Content "$projectRoot\README.md" -Raw -ErrorAction SilentlyContinue
if ($readme -and $readme.Length -gt 100) {
    Add-Result "Documentação" "README.md" "✅ PASS" "BAIXO" "README existe e tem conteúdo"
} else {
    Add-Result "Documentação" "README.md" "⚠️  WARN" "BAIXO" "README vazio ou inexistente"
}

# ========================================
# RELATÓRIO FINAL
# ========================================
Write-Host ""
Write-Host "📊 RELATÓRIO DE AUDITORIA" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Agrupar por severidade
$critical = $results | Where-Object { $_.Severity -eq "CRÍTICO" }
$high = $results | Where-Object { $_.Severity -eq "ALTO" }
$medium = $results | Where-Object { $_.Severity -eq "MÉDIO" }
$low = $results | Where-Object { $_.Severity -eq "BAIXO" }

# Contar status
$passed = ($results | Where-Object { $_.Status -eq "✅ PASS" }).Count
$warned = ($results | Where-Object { $_.Status -eq "⚠️  WARN" }).Count
$failed = ($results | Where-Object { $_.Status -eq "❌ FAIL" }).Count
$total = $results.Count

Write-Host "RESUMO GERAL" -ForegroundColor White
Write-Host "  Total de Verificacoes: $total" -ForegroundColor White
$passedPct = [math]::Round($passed/$total*100, 1)
$warnedPct = [math]::Round($warned/$total*100, 1)
$failedPct = [math]::Round($failed/$total*100, 1)
Write-Host "  Passou: $passed ($passedPct%)" -ForegroundColor Green
Write-Host "  Aviso: $warned ($warnedPct%)" -ForegroundColor Yellow
Write-Host "  Falhou: $failed ($failedPct%)" -ForegroundColor Red
Write-Host ""

# Mostrar itens críticos
if ($critical.Count -gt 0) {
    Write-Host "🔴 ITENS CRÍTICOS ($($critical.Count))" -ForegroundColor Red
    $critical | ForEach-Object {
        Write-Host "  $($_.Status) $($_.Category) - $($_.Item)" -ForegroundColor $(
            if ($_.Status -eq "✅ PASS") { "Green" }
            elseif ($_.Status -eq "⚠️  WARN") { "Yellow" }
            else { "Red" }
        )
        Write-Host "     $($_.Details)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Mostrar itens de alta prioridade com falha
$highFailed = $high | Where-Object { $_.Status -ne "✅ PASS" }
if ($highFailed.Count -gt 0) {
    Write-Host "🟠 ITENS DE ALTA PRIORIDADE COM PROBLEMAS ($($highFailed.Count))" -ForegroundColor DarkYellow
    $highFailed | ForEach-Object {
        Write-Host "  $($_.Status) $($_.Category) - $($_.Item)" -ForegroundColor $(
            if ($_.Status -eq "⚠️  WARN") { "Yellow" } else { "Red" }
        )
        Write-Host "     $($_.Details)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Salvar relatório em arquivo
$reportPath = Join-Path $projectRoot "AUDITORIA_RESULTADO_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

# Construir relatório linha por linha
$reportLines = @()
$reportLines += "# Relatorio de Auditoria - Sistema de Carrinho"
$reportLines += "**Data**: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$reportLines += "**Projeto**: MenuHub Totem"
$reportLines += ""
$reportLines += "## Resumo Executivo"
$reportLines += "- Total de Verificacoes: $total"
$reportLines += "- Passou: $passed ($passedPct`%)"
$reportLines += "- Aviso: $warned ($warnedPct`%)"
$reportLines += "- Falhou: $failed ($failedPct`%)"
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

$criticalFailed = $critical | Where-Object { $_.Status -ne "✅ PASS" }
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

Write-Host "SCORE DE SEGURANCA: $score pct" -ForegroundColor $scoreColor
Write-Host ""

if ($score -lt 70) {
    Write-Host "ATENCAO: Score abaixo de 70 pct. Recomenda-se revisao antes do deploy em producao." -ForegroundColor Red
} elseif ($score -lt 85) {
    Write-Host "Score aceitavel, mas ha melhorias importantes a fazer." -ForegroundColor Yellow
} else {
    Write-Host "Score bom! Continue monitorando e melhorando." -ForegroundColor Green
}

Write-Host ""
Write-Host "Para mais detalhes, consulte: AUDITORIA_CARRINHO_CHECKOUT.md" -ForegroundColor Cyan
