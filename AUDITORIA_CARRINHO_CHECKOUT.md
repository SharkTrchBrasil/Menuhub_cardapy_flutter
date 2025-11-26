# 🛒 Auditoria do Sistema de Carrinho e Checkout - Totem MenuHub

> **Projeto**: MenuHub - Sistema de Cardápio Digital (Totem)  
> **Data de Criação**: 23/11/2025  
> **Versão**: 1.0  
> **Status**: 🔍 Auditoria Inicial

---

## 📋 ÍNDICE

1. [Visão Geral do Sistema](#visão-geral-do-sistema)
2. [Segurança](#segurança)
3. [Funcionalidades do Carrinho](#funcionalidades-do-carrinho)
4. [Performance e Escalabilidade](#performance-e-escalabilidade)
5. [UX/UI](#uxui)
6. [Integrações](#integrações)
7. [Pagamentos](#pagamentos)
8. [Banco de Dados](#banco-de-dados)
9. [APIs](#apis)
10. [Testes](#testes)
11. [Monitoramento e Logs](#monitoramento-e-logs)
12. [Mobile e Responsividade](#mobile-e-responsividade)
13. [Estado e Sincronização](#estado-e-sincronização)
14. [Compliance e Legal](#compliance-e-legal)
15. [Plano de Ação](#plano-de-ação)

---

## 🎯 VISÃO GERAL DO SISTEMA

### Arquitetura Identificada

**Frontend (Flutter - Totem)**
```
lib/
├── pages/cart/
│   ├── cart_cubit.dart          # Gerenciamento de estado (BLoC)
│   ├── cart_state.dart          # Estados do carrinho
│   ├── cart_page.dart           # Página principal
│   ├── cart_tab_page.dart       # Tab do carrinho
│   ├── desktop/desktop_cart.dart
│   ├── mobile/mobile_cart.dart
│   └── widgets/
│       ├── cart_bottom_bar.dart
│       ├── cart_itens_section.dart
│       ├── cart_product_list_item.dart
│       └── cart_quantity_control.dart
├── pages/checkout/
│   ├── checkout_cubit.dart      # Gerenciamento de checkout
│   ├── checkout_state.dart
│   └── checkout_page.dart
├── models/
│   ├── cart.dart
│   ├── cart_item.dart
│   ├── cart_product.dart
│   ├── cart_variant.dart
│   ├── cart_variant_option.dart
│   └── update_cart_payload.dart
└── services/
    └── pending_cart_service.dart
```

**Backend (Python/FastAPI)**
```
Backend/src/
├── api/app/routes/cart.py       # Endpoints REST
├── api/app/events/handlers/cart_handler.py
├── api/schemas/orders/cart.py   # Validação Pydantic
├── api/jobs/cart_recovery.py    # Recuperação de carrinhos
└── core/models/business/
    ├── cart.py
    ├── cart_item.py
    ├── cart_item_variant.py
    ├── cart_item_variant_option.py
    └── cart_item_variant_option.py
```

### Stack Tecnológica
- **Frontend**: Flutter (BLoC/Cubit pattern)
- **Backend**: Python + FastAPI
- **Banco de Dados**: PostgreSQL (inferido)
- **Real-time**: WebSocket/SSE via RealtimeRepository
- **Estado**: Equatable + BLoC

---

## 🔐 1. SEGURANÇA

### 1.1 Autenticação e Autorização

#### ✅ Implementado
- [x] Carrinho vinculado à sessão via `AuthState`
- [x] Integração com `AuthCubit` no checkout

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Validar se há proteção contra acesso ao carrinho de outros usuários no backend
- [ ] **ALTO**: Verificar validação de tokens JWT/sessões expiradas
- [ ] **ALTO**: Testar proteção contra session hijacking
- [ ] **MÉDIO**: Verificar CSRF protection em operações do carrinho

**Ações Recomendadas:**
```python
# Backend: Verificar em cart.py se há validação de ownership
@router.patch("/carts/{cart_id}")
async def update_cart(
    cart_id: int,
    current_user: User = Depends(get_current_user)  # ✅ Necessário
):
    # ⚠️ VERIFICAR: Validação de ownership
    cart = await get_cart(cart_id)
    if cart.user_id != current_user.id:
        raise HTTPException(403, "Acesso negado")
```

### 1.2 Validação de Dados

#### ✅ Implementado
- [x] Validação de quantidade no frontend (`UpdateCartItemPayload`)
- [x] Uso de Pydantic schemas no backend

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Confirmar que preços são SEMPRE recalculados no backend (não confiar no frontend)
- [ ] **CRÍTICO**: Testar injeção de SQL em campos do carrinho
- [ ] **ALTO**: Validar XSS em campos de observações (`observation`, `note`)
- [ ] **ALTO**: Verificar sanitização de inputs em complementos/adicionais
- [ ] **ALTO**: Testar manipulação de IDs de produtos (IDOR)

**Código Atual (Frontend):**
```dart
// totem/lib/models/update_cart_payload.dart
// ⚠️ VERIFICAR: Validação de quantidade mínima/máxima
class UpdateCartItemPayload {
  final int productId;
  final int categoryId;
  final int quantity;  // ⚠️ Sem validação explícita de limites
  final List<CartVariant>? variants;
  final String? note;  // ⚠️ Precisa sanitização XSS
}
```

**Ações Recomendadas:**
```dart
// Adicionar validação no payload
class UpdateCartItemPayload {
  static const int MIN_QUANTITY = 1;
  static const int MAX_QUANTITY = 99;
  
  final int quantity;
  
  UpdateCartItemPayload({required int quantity})
      : assert(quantity >= MIN_QUANTITY && quantity <= MAX_QUANTITY,
          'Quantidade deve estar entre $MIN_QUANTITY e $MAX_QUANTITY'),
        this.quantity = quantity;
}
```

### 1.3 Integridade de Preços

#### ⚠️ CRÍTICO - A Verificar
- [ ] **CRÍTICO**: Confirmar que `subtotal`, `discount`, `total` são calculados APENAS no backend
- [ ] **CRÍTICO**: Verificar se descontos/cupons são validados no servidor
- [ ] **CRÍTICO**: Testar manipulação de valores via DevTools/Proxy
- [ ] **ALTO**: Validar cálculo de taxas de entrega
- [ ] **MÉDIO**: Verificar proteção contra race conditions em promoções

**Código Atual (Frontend):**
```dart
// totem/lib/models/cart.dart
class Cart {
  // ✅ BOM: Campos são final e vêm do backend
  final int subtotal;
  final int discount;
  final int total;
  
  // ⚠️ VERIFICAR: Garantir que esses valores NUNCA são calculados no frontend
}
```

**Ação Necessária:**
```python
# Backend: Garantir recálculo em TODA operação
def update_cart_item(cart_id: int, payload: UpdateCartItemPayload):
    # ✅ SEMPRE recalcular
    cart = get_cart(cart_id)
    cart.recalculate_totals()  # ⚠️ Verificar se existe
    return cart
```

### 1.4 Rate Limiting e DDoS

#### ❌ Não Implementado
- [ ] **ALTO**: Implementar rate limiting em operações do carrinho
- [ ] **MÉDIO**: Proteger contra adição massiva de itens
- [ ] **MÉDIO**: Limitar requisições de cálculo de frete
- [ ] **BAIXO**: Implementar CAPTCHA em operações suspeitas

**Ações Recomendadas:**
```python
# Backend: Adicionar rate limiting
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.patch("/carts/{cart_id}/items")
@limiter.limit("10/minute")  # ✅ Máximo 10 atualizações por minuto
async def update_cart_item(...):
    pass
```

---

## 🐛 2. FUNCIONALIDADES DO CARRINHO

### 2.1 Operações Básicas

#### ✅ Implementado
- [x] Adicionar item ao carrinho (`updateItem`)
- [x] Remover item do carrinho (`updateItem` com quantity=0)
- [x] Atualizar quantidade de itens
- [x] Limpar carrinho completo (`clearCart`)
- [x] Persistência do carrinho (via `RealtimeRepository`)

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Recuperação de carrinho abandonado (`cart_recovery.py` existe, verificar implementação)
- [ ] **MÉDIO**: Testar persistência entre sessões
- [ ] **BAIXO**: Verificar comportamento em logout/login

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
Future<void> updateItem(UpdateCartItemPayload payload) async {
  emit(state.copyWith(isUpdating: true));
  try {
    final updatedCart = await _realtimeRepository.updateCartItem(payload);
    emit(state.copyWith(status: CartStatus.success, cart: updatedCart));
  } catch (e) {
    // ✅ BOM: Re-busca o carrinho em caso de erro
    await fetchCart();
    throw Exception('Erro interno ao atualizar item: ${e.toString()}');
  }
}
```

### 2.2 Customizações e Complementos

#### ✅ Implementado
- [x] Adicionar complementos/adicionais (`CartVariant`, `CartVariantOption`)
- [x] Campo de observações especiais (`note` no `UpdateCartItemPayload`)

#### ⚠️ A Verificar
- [ ] **ALTO**: Validar obrigatoriedade de complementos no backend
- [ ] **MÉDIO**: Testar limites de quantidade de complementos
- [ ] **MÉDIO**: Validar combinações inválidas de produtos
- [ ] **BAIXO**: Remover complementos/adicionais individualmente

**Estrutura Atual:**
```dart
// totem/lib/models/cart_variant.dart
class CartVariant {
  final int variantId;
  final List<CartVariantOption> options;
  // ⚠️ VERIFICAR: Validação de obrigatoriedade
}
```

### 2.3 Cálculos

#### ✅ Implementado
- [x] Cálculo de subtotal (backend)
- [x] Cálculo de total com complementos
- [x] Aplicação de descontos/cupons (`applyCoupon`, `removeCoupon`)
- [x] Exibição correta de moeda (R$)

#### ⚠️ A Verificar
- [ ] **ALTO**: Cálculo de taxa de entrega (integração com `DeliveryFeeState`)
- [ ] **MÉDIO**: Cálculo de taxa de serviço (se aplicável)
- [ ] **MÉDIO**: Arredondamento de valores monetários (verificar precisão)

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
Future<void> applyCoupon(String code) async {
  try {
    final updatedCart = await _realtimeRepository.applyCoupon(code);
    emit(state.copyWith(cart: updatedCart));
  } catch (e) {
    rethrow;  // ✅ BOM: Propaga erro para UI
  }
}
```

### 2.4 Validações de Negócio

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Verificar horário de funcionamento do restaurante (via `StoreStatusService`)
- [ ] **ALTO**: Validar valor mínimo do pedido
- [ ] **ALTO**: Verificar disponibilidade de produtos em estoque
- [ ] **ALTO**: Validar área de entrega (CEP/endereço)
- [ ] **MÉDIO**: Verificar produtos esgotados/indisponíveis
- [ ] **BAIXO**: Validar combinações incompatíveis de itens

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
void _onProductsUpdated(List<Product> updatedProducts) {
  // ✅ BOM: Atualiza carrinho quando produtos mudam
  if (isCartAffected) {
    print('🔄 Produtos no carrinho foram atualizados no servidor.');
    fetchCart();
  }
}
```

**Ações Recomendadas:**
```dart
// Adicionar validações no checkout
Future<void> validateCart(Store store) async {
  // Horário de funcionamento
  if (!store.isOpen) {
    throw Exception('Loja fechada no momento');
  }
  
  // Valor mínimo
  if (cart.total < store.minimumOrderValue) {
    throw Exception('Valor mínimo: R\$ ${store.minimumOrderValue / 100}');
  }
  
  // Disponibilidade de produtos
  for (var item in cart.items) {
    if (!item.product.isAvailable) {
      throw Exception('${item.product.name} não está disponível');
    }
  }
}
```

---

## ⚡ 3. PERFORMANCE E ESCALABILIDADE

### 3.1 Performance Frontend

#### ✅ Implementado
- [x] Debounce implícito (não emite `loading` em cada atualização)
- [x] Otimização de re-renders (uso de Equatable)
- [x] Separação desktop/mobile

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Tempo de carregamento do carrinho < 2s
- [ ] **MÉDIO**: Lazy loading de imagens de produtos
- [ ] **BAIXO**: Cache de dados estáticos
- [ ] **BAIXO**: Minificação de assets

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
Future<void> updateItem(UpdateCartItemPayload payload) async {
  // ✅ BOM: Não emite 'loading' para evitar piscar
  emit(state.copyWith(isUpdating: true));
  // ...
}
```

### 3.2 Performance Backend

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Tempo de resposta da API < 500ms
- [ ] **ALTO**: Queries otimizadas (sem N+1)
- [ ] **ALTO**: Índices adequados no banco de dados
- [ ] **MÉDIO**: Cache de cálculos frequentes (Redis)
- [ ] **BAIXO**: Compressão de respostas (gzip/brotli)

**Ações Recomendadas:**
```python
# Backend: Otimizar queries
def get_cart_with_items(cart_id: int):
    # ✅ Usar eager loading para evitar N+1
    return db.query(Cart).options(
        joinedload(Cart.items)
        .joinedload(CartItem.product)
        .joinedload(Product.variants)
    ).filter(Cart.id == cart_id).first()
```

### 3.3 Escalabilidade

#### ⚠️ A Verificar
- [ ] **ALTO**: Suporte a alta concorrência (load testing)
- [ ] **MÉDIO**: Gerenciamento eficiente de sessões
- [ ] **MÉDIO**: Estratégia de sharding/particionamento
- [ ] **BAIXO**: CDN para assets estáticos
- [ ] **BAIXO**: Auto-scaling configurado

### 3.4 Otimização de Recursos

#### ✅ Implementado
- [x] Cleanup de carrinhos abandonados (`cart_recovery.py`)

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Uso eficiente de memória
- [ ] **MÉDIO**: Gerenciamento de conexões do banco
- [ ] **BAIXO**: Pool de conexões adequado

---

## 🎨 4. UX/UI

### 4.1 Usabilidade

#### ✅ Implementado
- [x] Indicador visual de itens no carrinho (via `CartState`)
- [x] Feedback visual ao adicionar/remover itens (`isUpdating`)
- [x] Loading states em operações

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Badge com quantidade de itens (verificar implementação)
- [ ] **MÉDIO**: Toast/notificações de sucesso/erro
- [ ] **BAIXO**: Confirmação antes de limpar carrinho

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_state.dart
enum CartStatus { initial, loading, success, error }

class CartState extends Equatable {
  final CartStatus status;
  final Cart cart;
  final bool isUpdating;  // ✅ BOM: Estado separado para updates
  final String? errorMessage;
}
```

### 4.2 Informações Visuais

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Exibição clara de preços
- [ ] **MÉDIO**: Detalhamento de complementos/adicionais
- [ ] **MÉDIO**: Imagens dos produtos
- [ ] **MÉDIO**: Descrições claras
- [ ] **ALTO**: Total sempre visível
- [ ] **ALTO**: Breakdown de custos (subtotal, entrega, taxas)

**Widgets Identificados:**
- `cart_bottom_bar.dart` - ⚠️ Verificar se mostra breakdown
- `cart_product_list_item.dart` - ⚠️ Verificar detalhamento

### 4.3 Acessibilidade

#### ❌ A Implementar
- [ ] **MÉDIO**: Navegação por teclado funcional
- [ ] **MÉDIO**: Labels adequados para screen readers
- [ ] **MÉDIO**: Contraste de cores adequado (WCAG)
- [ ] **BAIXO**: Textos alternativos em imagens
- [ ] **BAIXO**: Foco visível em elementos interativos
- [ ] **BAIXO**: Anúncios de mudanças no carrinho (ARIA)

---

## 🔌 5. INTEGRAÇÕES

### 5.1 Sistema de Pagamento

#### ✅ Implementado
- [x] Múltiplas formas de pagamento (`PlatformPaymentMethod`)
- [x] Suporte a troco (`needsChange`, `changeFor`)

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Integração com gateway de pagamento
- [ ] **CRÍTICO**: Validação de dados do cartão
- [ ] **ALTO**: Tratamento de falhas de pagamento
- [ ] **MÉDIO**: Webhooks de confirmação
- [ ] **MÉDIO**: Timeout adequado em transações

**Código Atual:**
```dart
// totem/lib/pages/checkout/checkout_cubit.dart
class CheckoutCubit {
  void updatePaymentMethod(PlatformPaymentMethod newMethod) {
    emit(state.copyWith(paymentMethod: newMethod));
  }
  
  void updateNeedsChange(bool needs) {
    emit(state.copyWith(needsChange: needs));
  }
}
```

### 5.2 Sistema de Entrega

#### ✅ Implementado
- [x] Cálculo de frete (`DeliveryFeeState`)
- [x] Validação de endereço (`AddressState`)
- [x] Integração com geolocalização (`GeolocationService`)

#### ⚠️ A Verificar
- [ ] **ALTO**: Cálculo de frete em tempo real
- [ ] **MÉDIO**: Múltiplas opções de entrega
- [ ] **MÉDIO**: Estimativa de tempo de entrega
- [ ] **BAIXO**: Integração com APIs de geolocalização

### 5.3 Sistema de Estoque

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Verificação de disponibilidade em tempo real
- [ ] **ALTO**: Sincronização de produtos esgotados
- [ ] **MÉDIO**: Bloqueio temporário de estoque no carrinho
- [ ] **MÉDIO**: Liberação de estoque em carrinhos abandonados

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
void _onProductsUpdated(List<Product> updatedProducts) {
  // ✅ BOM: Escuta atualizações de produtos
  // ⚠️ VERIFICAR: Se inclui mudanças de estoque
}
```

### 5.4 CRM e Marketing

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Tracking de carrinho abandonado
- [ ] **BAIXO**: Integração com analytics (GA4, etc)
- [ ] **BAIXO**: Eventos de conversão
- [ ] **BAIXO**: Cupons e promoções (já implementado parcialmente)

---

## 💳 6. PAGAMENTOS

### 6.1 Segurança PCI-DSS

#### ⚠️ CRÍTICO - A Verificar
- [ ] **CRÍTICO**: Não armazenar dados de cartão no frontend
- [ ] **CRÍTICO**: Tokenização de dados sensíveis
- [ ] **CRÍTICO**: Comunicação via HTTPS obrigatório
- [ ] **CRÍTICO**: Compliance com PCI-DSS

### 6.2 Fluxo de Pagamento

#### ⚠️ A Verificar
- [ ] **ALTO**: Timeout de reserva do carrinho
- [ ] **ALTO**: Retentativa de pagamento
- [ ] **MÉDIO**: Cancelamento de pedido
- [ ] **MÉDIO**: Estorno/reembolso
- [ ] **MÉDIO**: Logs de transações

### 6.3 Métodos de Pagamento

#### ✅ Implementado (Parcial)
- [x] Estrutura para múltiplos métodos (`PlatformPaymentMethod`)
- [x] Dinheiro (troco)

#### ⚠️ A Verificar
- [ ] **ALTO**: Cartão de crédito
- [ ] **ALTO**: Cartão de débito
- [ ] **ALTO**: PIX
- [ ] **MÉDIO**: Vale-refeição
- [ ] **BAIXO**: Carteira digital

---

## 🗄️ 7. BANCO DE DADOS

### 7.1 Estrutura

#### ✅ Implementado
- [x] Modelagem de tabelas (SQLAlchemy models)
- [x] Relacionamentos (`Cart` -> `CartItem` -> `CartItemVariant`)

#### ⚠️ A Verificar
- [ ] **ALTO**: Constraints e validações
- [ ] **ALTO**: Índices em campos chave
- [ ] **MÉDIO**: Soft delete vs hard delete
- [ ] **BAIXO**: Foreign keys configuradas

**Modelos Identificados:**
```
cart.py
cart_item.py
cart_item_variant.py
cart_item_variant_option.py
```

### 7.2 Integridade

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Foreign keys configuradas
- [ ] **CRÍTICO**: Transações ACID quando necessário
- [ ] **ALTO**: Locks apropriados
- [ ] **MÉDIO**: Prevenção de deadlocks
- [ ] **MÉDIO**: Backup e recovery testados

### 7.3 Consultas

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Queries otimizadas
- [ ] **CRÍTICO**: Ausência de N+1 queries
- [ ] **MÉDIO**: Uso adequado de JOINs
- [ ] **MÉDIO**: Paginação implementada
- [ ] **BAIXO**: Explicação de queries lentas

---

## 🌐 8. APIs

### 8.1 Estrutura REST

#### ✅ Implementado
- [x] Endpoints definidos (`cart.py`)
- [x] Uso de Pydantic schemas

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Versionamento da API
- [ ] **MÉDIO**: Status HTTP corretos
- [ ] **MÉDIO**: Documentação (Swagger/OpenAPI)
- [ ] **BAIXO**: Rate limiting por endpoint

### 8.2 Respostas

#### ⚠️ A Verificar
- [ ] **ALTO**: Formato consistente de respostas
- [ ] **ALTO**: Mensagens de erro descritivas
- [ ] **MÉDIO**: Códigos de erro padronizados
- [ ] **MÉDIO**: Tratamento de exceções
- [ ] **MÉDIO**: Validação de payload

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
catch (e, stackTrace) {
  print("❌ [CartCubit] Erro ao atualizar item: $e");
  // ⚠️ VERIFICAR: Tratamento de erros específicos do backend
  throw Exception('Erro interno ao atualizar item: ${e.toString()}');
}
```

### 8.3 Segurança de API

#### ⚠️ A Verificar
- [ ] **CRÍTICO**: Autenticação em todos endpoints
- [ ] **CRÍTICO**: Autorização por recurso
- [ ] **ALTO**: Input validation
- [ ] **ALTO**: Output encoding
- [ ] **MÉDIO**: CORS configurado corretamente

---

## 🧪 9. TESTES

### 9.1 Testes Unitários

#### ❌ A Implementar
- [ ] **ALTO**: Cobertura mínima de 80%
- [ ] **ALTO**: Testes de cálculos de valores
- [ ] **ALTO**: Testes de validações
- [ ] **MÉDIO**: Testes de regras de negócio
- [ ] **MÉDIO**: Mocks de dependências externas

**Estrutura Atual:**
```
totem/test/  # ⚠️ Verificar conteúdo
```

### 9.2 Testes de Integração

#### ❌ A Implementar
- [ ] **CRÍTICO**: Fluxo completo de checkout
- [ ] **ALTO**: Integração com pagamento
- [ ] **MÉDIO**: Integração com estoque
- [ ] **MÉDIO**: Integração com entrega
- [ ] **MÉDIO**: Testes de API end-to-end

### 9.3 Testes de Interface

#### ❌ A Implementar
- [ ] **MÉDIO**: Testes E2E (Flutter integration tests)
- [ ] **MÉDIO**: Cenários críticos automatizados
- [ ] **BAIXO**: Testes em diferentes navegadores
- [ ] **BAIXO**: Testes mobile
- [ ] **BAIXO**: Testes de acessibilidade

### 9.4 Testes de Carga

#### ❌ A Implementar
- [ ] **ALTO**: Cenários de pico de acesso
- [ ] **MÉDIO**: Concorrência em operações críticas
- [ ] **MÉDIO**: Teste de limite de carrinho
- [ ] **BAIXO**: Degradação gradual sob carga

---

## 📊 10. MONITORAMENTO E LOGS

### 10.1 Monitoramento

#### ❌ A Implementar
- [ ] **ALTO**: APM configurado (New Relic, Datadog)
- [ ] **ALTO**: Métricas de tempo de resposta
- [ ] **MÉDIO**: Taxa de erro monitorada
- [ ] **MÉDIO**: Alertas configurados
- [ ] **BAIXO**: Dashboards de negócio

### 10.2 Logs

#### ✅ Implementado (Parcial)
- [x] Logs de debug no frontend (`print`)

#### ⚠️ A Melhorar
- [ ] **MÉDIO**: Logs estruturados (JSON)
- [ ] **MÉDIO**: Níveis de log adequados
- [ ] **MÉDIO**: Correlação de requisições (trace ID)
- [ ] **BAIXO**: Logs de auditoria
- [ ] **BAIXO**: Retenção de logs configurada
- [ ] **CRÍTICO**: Não logar dados sensíveis

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
print('🛒 [CartCubit] Atualizando item: productId=${payload.productId}');
// ⚠️ MELHORAR: Usar logger estruturado
```

### 10.3 Tratamento de Erros

#### ✅ Implementado (Parcial)
- [x] Try-catch em operações críticas
- [x] Re-fetch do carrinho em caso de erro

#### ⚠️ A Melhorar
- [ ] **MÉDIO**: Fallbacks implementados
- [ ] **MÉDIO**: Mensagens amigáveis ao usuário
- [ ] **BAIXO**: Erros rastreáveis (Sentry)

---

## 📱 11. MOBILE E RESPONSIVIDADE

### 11.1 Design Responsivo

#### ✅ Implementado
- [x] Layout adaptável (desktop/mobile separados)
- [x] Separação de widgets por plataforma

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Touch targets adequados (min 44x44px)
- [ ] **BAIXO**: Gestos nativos funcionam
- [ ] **BAIXO**: Orientação landscape e portrait
- [ ] **BAIXO**: Testes em dispositivos reais

**Estrutura Atual:**
```
pages/cart/
├── desktop/desktop_cart.dart  # ✅ Separação clara
├── mobile/mobile_cart.dart
└── cart_tab_page_adaptive.dart
```

### 11.2 Performance Mobile

#### ⚠️ A Verificar
- [ ] **ALTO**: Tempo de carregamento < 3s em 3G
- [ ] **MÉDIO**: Tamanho de imagens otimizado
- [ ] **MÉDIO**: Lazy loading implementado
- [ ] **BAIXO**: Service Worker para offline
- [ ] **BAIXO**: Progressive Web App (PWA)

### 11.3 Funcionalidades Mobile

#### ⚠️ A Verificar
- [ ] **BAIXO**: Deep linking funcional
- [ ] **BAIXO**: Push notifications (se aplicável)
- [ ] **BAIXO**: Geolocalização (já implementado via `GeolocationService`)
- [ ] **BAIXO**: Câmera para QR Code
- [ ] **BAIXO**: Biometria para pagamento

---

## 🔄 12. ESTADO E SINCRONIZAÇÃO

### 12.1 Gerenciamento de Estado

#### ✅ Implementado
- [x] Estado consistente (BLoC/Cubit)
- [x] Uso de Equatable para comparações

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Sincronização em múltiplas abas
- [ ] **MÉDIO**: Persistência em localStorage/IndexedDB
- [ ] **BAIXO**: Versionamento de estado
- [ ] **BAIXO**: Migração de dados antigos

**Código Atual:**
```dart
// totem/lib/models/cart.dart
class Cart extends Equatable {
  // ✅ BOM: Uso de Equatable para comparações eficientes
  @override
  List<Object?> get props => [id, status, items, subtotal, discount, total];
}
```

### 12.2 Tempo Real

#### ✅ Implementado
- [x] Atualização de disponibilidade de produtos (`_listenToProductUpdates`)
- [x] WebSocket/SSE via `RealtimeRepository`

#### ⚠️ A Verificar
- [ ] **MÉDIO**: Notificação de mudanças de preço
- [ ] **MÉDIO**: Reconnection automática
- [ ] **BAIXO**: Offline mode

**Código Atual:**
```dart
// totem/lib/pages/cart/cart_cubit.dart
void _listenToProductUpdates() {
  _productSubscription?.cancel();  // ✅ BOM: Evita duplicatas
  _productSubscription = _realtimeRepository.productsController.stream
      .listen(_onProductsUpdated);
}
```

---

## 📋 13. COMPLIANCE E LEGAL

### 13.1 LGPD/GDPR

#### ❌ A Implementar
- [ ] **ALTO**: Consentimento de dados coletados
- [ ] **ALTO**: Política de privacidade acessível
- [ ] **MÉDIO**: Direito de exclusão de dados
- [ ] **MÉDIO**: Anonimização de dados sensíveis
- [ ] **BAIXO**: Auditoria de acesso a dados

### 13.2 Notas Fiscais

#### ⚠️ A Verificar
- [ ] **ALTO**: Geração de NF-e
- [ ] **MÉDIO**: Envio automático ao email
- [ ] **MÉDIO**: Armazenamento seguro
- [ ] **BAIXO**: Integração com sistema fiscal

---

## 🚀 14. PLANO DE AÇÃO

### 🔴 Prioridade CRÍTICA (Bloqueante)

1. **Segurança de Preços**
   - [ ] Auditar backend para garantir que preços são SEMPRE recalculados no servidor
   - [ ] Testar manipulação de valores via DevTools
   - [ ] Implementar validação de ownership de carrinhos

2. **Validação de Dados**
   - [ ] Implementar proteção contra SQL Injection
   - [ ] Sanitizar campos de observação (XSS)
   - [ ] Validar IDs de produtos (IDOR)

3. **Integridade de Transações**
   - [ ] Implementar transações ACID no backend
   - [ ] Garantir rollback em caso de falha de pagamento

### 🟠 Prioridade ALTA (Pré-Produção)

4. **Performance**
   - [ ] Otimizar queries (evitar N+1)
   - [ ] Adicionar índices no banco de dados
   - [ ] Implementar cache de cálculos frequentes

5. **Validações de Negócio**
   - [ ] Verificar horário de funcionamento antes do checkout
   - [ ] Validar valor mínimo do pedido
   - [ ] Verificar disponibilidade em estoque em tempo real

6. **Rate Limiting**
   - [ ] Implementar rate limiting em endpoints críticos
   - [ ] Proteger contra adição massiva de itens

### 🟡 Prioridade MÉDIA (Pós-Lançamento)

7. **Testes**
   - [ ] Implementar testes unitários (cobertura 80%)
   - [ ] Criar testes de integração para fluxo completo
   - [ ] Testes E2E automatizados

8. **Monitoramento**
   - [ ] Configurar APM (Application Performance Monitoring)
   - [ ] Implementar logs estruturados
   - [ ] Configurar alertas de erro

9. **UX/UI**
   - [ ] Adicionar toast notifications
   - [ ] Implementar confirmação antes de limpar carrinho
   - [ ] Melhorar feedback visual

### 🟢 Prioridade BAIXA (Backlog)

10. **Acessibilidade**
    - [ ] Implementar navegação por teclado
    - [ ] Adicionar labels para screen readers
    - [ ] Garantir contraste WCAG

11. **Compliance**
    - [ ] Implementar consentimento LGPD
    - [ ] Adicionar política de privacidade
    - [ ] Implementar direito de exclusão

---

## 📊 MÉTRICAS DE SUCESSO

### KPIs Técnicos
- **Disponibilidade**: > 99.9%
- **Tempo de Resposta**: P95 < 500ms
- **Taxa de Erro**: < 0.1%
- **Cobertura de Testes**: > 80%

### KPIs de Negócio
- **Taxa de Conversão**: % de carrinhos que finalizam compra
- **Tempo Médio de Checkout**: < 3 minutos
- **Taxa de Abandono**: < 70%
- **Satisfação do Usuário**: NPS > 8

### Métricas de Monitoramento
```python
# Exemplo de métricas a coletar
metrics = {
    "cart_operations": {
        "add_item_duration_ms": [],
        "update_item_duration_ms": [],
        "checkout_duration_ms": [],
    },
    "errors": {
        "validation_errors": 0,
        "payment_failures": 0,
        "timeout_errors": 0,
    },
    "business": {
        "average_cart_value": 0,
        "items_per_cart": 0,
        "abandoned_carts": 0,
    }
}
```

---

## 📝 PRÓXIMOS PASSOS

### Fase 1: Auditoria Técnica (1-2 semanas)
1. Revisar código backend (`cart.py`, modelos)
2. Testar segurança (OWASP Top 10)
3. Analisar queries do banco de dados
4. Verificar logs e tratamento de erros

### Fase 2: Correções Críticas (2-3 semanas)
1. Implementar validações de segurança
2. Otimizar performance
3. Adicionar rate limiting
4. Implementar transações ACID

### Fase 3: Testes e Validação (1-2 semanas)
1. Criar suite de testes unitários
2. Implementar testes de integração
3. Realizar testes de carga
4. Validar fluxo completo

### Fase 4: Monitoramento e Deploy (1 semana)
1. Configurar APM
2. Implementar logs estruturados
3. Configurar alertas
4. Deploy gradual (canary)

---

## 🔗 REFERÊNCIAS

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PCI-DSS Compliance](https://www.pcisecuritystandards.org/)
- [LGPD - Lei Geral de Proteção de Dados](https://www.gov.br/cidadania/pt-br/acesso-a-informacao/lgpd)
- [Flutter Best Practices](https://docs.flutter.dev/perf/best-practices)
- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/)

---

**Última Atualização**: 23/11/2025  
**Versão**: 1.0  
**Responsável**: Equipe de Desenvolvimento MenuHub  
**Status**: 🔍 Auditoria em Andamento
