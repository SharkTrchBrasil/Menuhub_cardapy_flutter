# 🔧 Implementação de Correções - Sistema de Carrinho
**Data de Início**: 23/11/2025 11:09
**Objetivo**: Alcançar 100/100 no score de auditoria
**Score Inicial**: 26.7%

---

## 📊 Status das Correções

### 🔴 CRÍTICO (4 itens)
- [ ] 1. Recálculo de Preços no Backend
- [ ] 2. Validação de Ownership
- [ ] 3. Validação de Horário de Funcionamento
- [ ] 4. Transações ACID

### 🟠 ALTO (5 itens)
- [ ] 5. Validação de Inputs (Pydantic)
- [ ] 6. Sanitização XSS (Frontend)
- [ ] 7. Eager Loading (Otimização de Queries)
- [ ] 8. Validação de Valor Mínimo
- [ ] 9. Testes de Carrinho

### 🟡 MÉDIO (2 itens)
- [ ] 10. Logger Estruturado
- [ ] 11. Remover prints de debug

---

## 🔴 CORREÇÃO 1: Recálculo de Preços no Backend

### Problema
Não foi encontrado recálculo explícito de preços no backend. Isso permite manipulação de valores pelo cliente.

### Solução
Implementar método `recalculate_totals()` no modelo `Cart` e garantir que seja chamado em TODAS as operações.

### Arquivos a Modificar
- `Backend/src/core/models/business/cart.py`
- `Backend/src/api/app/routes/cart.py`

### Status
⏳ Em andamento

---

## 🔴 CORREÇÃO 2: Validação de Ownership

### Problema
Autenticação não claramente identificada nos endpoints do carrinho.

### Solução
Adicionar validação explícita de ownership em todos os endpoints de carrinho.

### Arquivos a Modificar
- `Backend/src/api/app/routes/cart.py`

### Status
⏳ Pendente

---

## 🔴 CORREÇÃO 3: Validação de Horário de Funcionamento

### Problema
Sistema não valida se a loja está aberta antes de permitir checkout.

### Solução
Adicionar validação de horário no checkout (frontend e backend).

### Arquivos a Modificar
- `totem/lib/pages/checkout/checkout_cubit.dart`
- `Backend/src/api/app/routes/orders.py` (ou equivalente)

### Status
⏳ Pendente

---

## 🔴 CORREÇÃO 4: Transações ACID

### Problema
Transações não claramente identificadas, risco de inconsistência de dados.

### Solução
Implementar transações explícitas em operações críticas do carrinho.

### Arquivos a Modificar
- `Backend/src/api/app/routes/cart.py`

### Status
⏳ Pendente

---

## 🟠 CORREÇÃO 5: Validação de Inputs (Pydantic)

### Problema
Validadores não identificados nos schemas.

### Solução
Adicionar validadores Pydantic com limites e constraints.

### Arquivos a Modificar
- `Backend/src/api/schemas/orders/cart.py`

### Status
⏳ Pendente

---

## 🟠 CORREÇÃO 6: Sanitização XSS (Frontend)

### Problema
Campos de texto (note, observation) não têm sanitização.

### Solução
Adicionar validação e sanitização de inputs no frontend.

### Arquivos a Modificar
- `totem/lib/models/update_cart_payload.dart`
- `totem/lib/pages/cart/cart_cubit.dart`

### Status
⏳ Pendente

---

## 🟠 CORREÇÃO 7: Eager Loading

### Problema
Queries podem ter problema N+1.

### Solução
Implementar eager loading nos relacionamentos do Cart.

### Arquivos a Modificar
- `Backend/src/core/models/business/cart.py`
- `Backend/src/api/app/routes/cart.py`

### Status
⏳ Pendente

---

## 🟠 CORREÇÃO 8: Validação de Valor Mínimo

### Problema
Sistema não valida valor mínimo do pedido.

### Solução
Adicionar validação de valor mínimo no checkout.

### Arquivos a Modificar
- `totem/lib/pages/checkout/checkout_cubit.dart`
- Backend (validação duplicada)

### Status
⏳ Pendente

---

## 🟠 CORREÇÃO 9: Testes de Carrinho

### Problema
Nenhum teste de carrinho encontrado.

### Solução
Criar suite de testes para CartCubit e operações críticas.

### Arquivos a Criar
- `totem/test/cart/cart_cubit_test.dart`
- `totem/test/cart/cart_model_test.dart`

### Status
⏳ Pendente

---

## 🟡 CORREÇÃO 10: Logger Estruturado

### Problema
Usando `print()` ao invés de logger estruturado.

### Solução
Implementar logger estruturado (ex: `logger` package).

### Arquivos a Modificar
- `totem/lib/pages/cart/cart_cubit.dart`
- `totem/pubspec.yaml` (adicionar dependência)

### Status
⏳ Pendente

---

## 🟡 CORREÇÃO 11: Remover Prints de Debug

### Problema
8 prints encontrados no código.

### Solução
Substituir por logger estruturado.

### Arquivos a Modificar
- `totem/lib/pages/cart/cart_cubit.dart`

### Status
⏳ Pendente

---

## 📈 Progresso

- **Total de Correções**: 11
- **Concluídas**: 0
- **Em Andamento**: 0
- **Pendentes**: 11
- **Score Atual**: 26.7%
- **Score Meta**: 100%

---

## 🔄 Log de Implementação

### 23/11/2025 11:09 - Início das Correções
- Documento de acompanhamento criado
- Iniciando correção #1: Recálculo de Preços

---

**Próxima Atualização**: Após conclusão da primeira correção
