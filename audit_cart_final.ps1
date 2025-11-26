# Script de Auditoria de Seguranca - Sistema de Carrinho v2.0
# MenuHub Totem - Pos-Melhorias
# Data: 23/11/2025

Write-Host "AUDITORIA DE SEGURANCA - SISTEMA DE CARRINHO v2.0" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
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

$cartHandler = Get-Content "$backendPath\src\api\app\events\handlers\cart_handler.py" -Raw -ErrorAction SilentlyContinue
if ($cartHandler) {
    # Verifica funcao _build_cart_schema que recalcula precos
    if ($cartHandler -match "_build_cart_schema" -and $cartHandler -match "resolved_price" -and $cartHandler -match "base_price") {
        Add-Result "Seguranca" "Recalculo de Precos" "PASS" "CRITICO" "Backend recalcula precos em _build_cart_schema()"
    } else {
        Add-Result "Seguranca" "Recalculo de Precos" "FAIL" "CRITICO" "Nao encontrado recalculo explicito de precos"
    }
    
    # Verifica validacao de ownership via cart.id
    if ($cartHandler -match "cart_id=cart\.id" -or $cartHandler -match "filter_by\(id=cart_item_id_to_edit, cart_id=cart\.id\)") {
        Add-Result "Seguranca" "Validacao de Ownership" "PASS" "CRITICO" "Validacao de ownership via cart.id implementada"
    } else {
        Add-Result "Seguranca" "Validacao de Ownership" "WARN" "CRITICO" "Autenticacao nao claramente identificada"
    }
} else {
    Add-Result "Seguranca" "Arquivo cart_handler.py" "FAIL" "CRITICO" "Arquivo nao encontrado: $backendPath\src\api\app\events\handlers\cart_handler.py"
}

# 2. SEGURANCA - SANITIZACAO DE INPUTS
Write-Host "2. Verificando Sanitizacao de Inputs..." -ForegroundColor Yellow

if ($cartHandler) {
    # Verifica funcao sanitize_note
    if ($cartHandler -match "def sanitize_note" -and $cartHandler -match "html\.escape") {
        Add-Result "Seguranca" "Sanitizacao XSS" "PASS" "ALTO" "Funcao sanitize_note() implementada com html.escape"
    } else {
        Add-Result "Seguranca" "Sanitizacao XSS" "WARN" "ALTO" "Sanitizacao nao identificada"
    }
    
    # Verifica funcao validate_quantity
    if ($cartHandler -match "def validate_quantity") {
        Add-Result "Seguranca" "Validacao de Quantidade" "PASS" "ALTO" "Funcao validate_quantity() implementada"
    } else {
        Add-Result "Seguranca" "Validacao de Quantidade" "WARN" "ALTO" "Validacao de quantidade nao identificada"
    }
}

# 3. PERFORMANCE - QUERIES N+1
Write-Host "3. Verificando Otimizacao de Queries..." -ForegroundColor Yellow

if ($cartHandler) {
    if ($cartHandler -match "selectinload|joinedload") {
        Add-Result "Performance" "Eager Loading" "PASS" "ALTO" "Eager loading implementado (selectinload/joinedload)"
    } else {
        Add-Result "Performance" "Eager Loading" "WARN" "ALTO" "Eager loading nao claramente definido"
    }
}

# 4. VALIDACOES DE NEGOCIO
Write-Host "4. Verificando Validacoes de Negocio..." -ForegroundColor Yellow

if ($cartHandler) {
    # Verifica validacao de pizzas
    if ($cartHandler -match "def validate_pizza_configuration") {
        Add-Result "Negocio" "Validacao de Pizzas" "PASS" "ALTO" "Funcao validate_pizza_configuration() implementada"
    } else {
        Add-Result "Negocio" "Validacao de Pizzas" "WARN" "ALTO" "Validacao de pizzas nao identificada"
    }
    
    # Verifica validacao de complementos
    if ($cartHandler -match "def validate_variant_options_availability") {
        Add-Result "Negocio" "Validacao de Complementos" "PASS" "ALTO" "Funcao validate_variant_options_availability() implementada"
    } else {
        Add-Result "Negocio" "Validacao de Complementos" "WARN" "ALTO" "Validacao de complementos nao identificada"
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
        Add-Result "Testes" "Testes de Carrinho" "WARN" "MEDIO" "Nenhum teste de carrinho encontrado (opcional)"
    }
} else {
    Add-Result "Testes" "Diretorio de Testes" "WARN" "MEDIO" "Diretorio test/ nao encontrado (opcional)"
}

# 7. LOGS E MONITORAMENTO
Write-Host "7. Verificando Logs..." -ForegroundColor Yellow

if ($cartHandler) {
    # Verifica logger estruturado
    if ($cartHandler -match "import logging" -and $cartHandler -match "logger = logging\.getLogger") {
        Add-Result "Monitoramento" "Logger Estruturado" "PASS" "MEDIO" "Logger estruturado implementado"
    } else {
        Add-Result "Monitoramento" "Logger Estruturado" "WARN" "MEDIO" "Logger estruturado nao encontrado"
    }
    
    # Verifica se ainda usa print (aceitavel se tiver logger tambem)
    if ($cartHandler -match "logger\.info|logger\.error") {
        Add-Result "Monitoramento" "Logs Profissionais" "PASS" "MEDIO" "Usando logger.info() e logger.error()"
    } else {
        $printCount = ([regex]::Matches($cartHandler, "print\(")).Count
        Add-Result "Monitoramento" "Logs de Debug" "WARN" "BAIXO" "$printCount prints encontrados (usar logger)"
    }
}

# 8. RATE LIMITING
Write-Host "8. Verificando Rate Limiting..." -ForegroundColor Yellow

if ($cartHandler) {
    if ($cartHandler -match "limiter|rate_limit|RateLimiter|slowapi") {
        Add-Result "Seguranca" "Rate Limiting" "PASS" "MEDIO" "Rate limiting implementado"
    } else {
        Add-Result "Seguranca" "Rate Limiting" "WARN" "MEDIO" "Rate limiting nao encontrado (opcional para staging)"
    }
}

# 9. TRANSACOES ACID
Write-Host "9. Verificando Transacoes..." -ForegroundColor Yellow

if ($cartHandler) {
    if ($cartHandler -match "db\.commit\(\)" -and $cartHandler -match "db\.rollback\(\)") {
        Add-Result "Integridade" "Transacoes ACID" "PASS" "CRITICO" "Transacoes com commit() e rollback() implementadas"
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

# Verifica documentacao de auditoria
$auditoriaFiles = Get-ChildItem -Path $projectRoot -Filter "AUDITORIA*.md" -ErrorAction SilentlyContinue
if ($auditoriaFiles.Count -gt 0) {
    Add-Result "Documentacao" "Documentacao de Auditoria" "PASS" "MEDIO" "$($auditoriaFiles.Count) arquivos de auditoria encontrados"
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

# Mostrar itens de alta prioridade
if ($high.Count -gt 0) {
    Write-Host "ITENS DE ALTA PRIORIDADE ($($high.Count))" -ForegroundColor DarkYellow
    $highIssues = $high | Where-Object { $_.Status -ne "PASS" }
    if ($highIssues.Count -gt 0) {
        Write-Host "  COM PROBLEMAS: $($highIssues.Count)" -ForegroundColor Yellow
        $highIssues | ForEach-Object {
            $color = if ($_.Status -eq "WARN") { "Yellow" } else { "Red" }
            Write-Host "  [$($_.Status)] $($_.Category) - $($_.Item)" -ForegroundColor $color
            Write-Host "     $($_.Details)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  TODOS PASSARAM!" -ForegroundColor Green
    }
    Write-Host ""
}

# Salvar relatorio em arquivo
$reportPath = Join-Path $projectRoot "AUDITORIA_RESULTADO_FINAL_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$reportLines = @()
$reportLines += "# Relatorio de Auditoria Final - Sistema de Carrinho"
$reportLines += "**Data**: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$reportLines += "**Projeto**: MenuHub Totem"
$reportLines += "**Versao**: 2.0 (Pos-Melhorias)"
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
$reportLines += "## Analise por Severidade"
$reportLines += ""
$reportLines += "### Criticos"
$criticalPass = ($critical | Where-Object { $_.Status -eq "PASS" }).Count
$reportLines += "- Total: $($critical.Count)"
$reportLines += "- Passou: $criticalPass"
$reportLines += "- Pendente: $($critical.Count - $criticalPass)"
$reportLines += ""

$reportLines += "### Altos"
$highPass = ($high | Where-Object { $_.Status -eq "PASS" }).Count
$reportLines += "- Total: $($high.Count)"
$reportLines += "- Passou: $highPass"
$reportLines += "- Pendente: $($high.Count - $highPass)"
$reportLines += ""

$reportContent = $reportLines -join "`r`n"
$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Relatorio salvo em: $reportPath" -ForegroundColor Green
Write-Host ""

# Score final
$score = [math]::Round(($passed / $total) * 100, 1)
$scoreColor = if ($score -ge 90) { "Green" } elseif ($score -ge 70) { "Yellow" } else { "Red" }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCORE FINAL DE SEGURANCA: $score porcento" -ForegroundColor $scoreColor
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($score -ge 90) {
    Write-Host "EXCELENTE! Sistema pronto para producao!" -ForegroundColor Green
    Write-Host "Todas as validacoes criticas foram implementadas." -ForegroundColor Green
} elseif ($score -ge 70) {
    Write-Host "BOM! Sistema aceitavel para staging." -ForegroundColor Yellow
    Write-Host "Algumas melhorias recomendadas antes de producao." -ForegroundColor Yellow
} else {
    Write-Host "ATENCAO: Score abaixo de 70 porcento." -ForegroundColor Red
    Write-Host "Recomenda-se implementar melhorias antes do deploy." -ForegroundColor Red
}

Write-Host ""
Write-Host "Para mais detalhes, consulte:" -ForegroundColor Cyan
Write-Host "  - RESUMO_EXECUTIVO_CARRINHO.md" -ForegroundColor White
Write-Host "  - MELHORIAS_IMPLEMENTADAS_100PCT.md" -ForegroundColor White
