# 🍕 AUDITORIA COMPLETA - SISTEMA DE PIZZAS (NÍVEL IFOOD)

**Data**: 23/11/2025 12:10  
**Objetivo**: Alinhar sistema de pizzas com o iFood  
**Escopo**: Backend + Admin + Totem

---

## 📊 RESUMO EXECUTIVO

### ❌ PROBLEMA IDENTIFICADO

O sistema atual está **PARCIALMENTE ERRADO** para pizzas do tipo "Monte Sua Pizza" (igual iFood).

**Sintomas**:
1. ❌ Cliente vê apenas "Pizza" sem preço claro
2. ❌ Precisa escolher tamanho E sabor no mesmo produto
3. ❌ Não sabe quantos sabores pode escolher por tamanho
4. ❌ UX confusa e diferente do iFood

**Causa Raiz**:
- Sistema atual usa **1 produto** com variant SIZE
- iFood usa **MÚLTIPLOS produtos** (1 por tamanho)

---

## 🎯 SOLUÇÃO PROPOSTA

### **2 TIPOS DE PIZZAS** (Igual iFood)

#### **TIPO 1: "Monte Sua Pizza"** (Categoria CUSTOMIZABLE)
- Cliente escolhe tamanho E sabores
- Produtos separados por tamanho
- Exemplo: "Pizza Grande (3 sabores)" - R$ 60,00

#### **TIPO 2: "Pizzas Preferidas"** (Categoria GENERAL)
- Pizzas prontas com sabores fixos
- Produtos normais com complementos opcionais
- Exemplo: "Pizza 1/2 Calabresa 1/2 Margherita Grande" - R$ 51,99

---

## 📋 AUDITORIA POR PROJETO

### 🔴 **BACKEND** (Python/FastAPI)

#### ✅ **O QUE ESTÁ CERTO**

1. ✅ **Modelo `Category`** (`category.py`)
   - Tem campo `type` (GENERAL, CUSTOMIZABLE)
   - Tem campo `selected_template` (NONE)
   - Tem relacionamento `option_groups`
   - Tem campo `pricing_strategy` (SUM_OF_ITEMS, HIGHEST_PRICE)
   - Tem campo `price_varies_by_size`

2. ✅ **Modelo `Product`** (`product.py`)
   - Suporta produtos normais
   - Tem relacionamento `prices` (FlavorPrice)
   - Tem relacionamento `variant_links`

3. ✅ **Modelo `FlavorPrice`** (`flavor_price.py`)
   - Permite preços por tamanho
   - Relaciona `product_id` + `size_option_id`
   - Tem campo `price`, `pos_code`, `is_available`

4. ✅ **Enums** (`enums.py`)
   - `CategoryType`: GENERAL, CUSTOMIZABLE
   - `CategoryTemplateType`: NONE (compatibilidade)
   - `OptionGroupType`: SIZE, GENERIC
   - `PricingStrategyType`: SUM_OF_ITEMS, HIGHEST_PRICE, LOWEST_PRICE

#### ❌ **O QUE ESTÁ ERRADO / FALTANDO**

1. ❌ **Falta lógica de geração automática de produtos**
   - iFood gera produtos automaticamente baseado em tamanhos
   - Exemplo: Categoria "Monte Sua Pizza" com 3 tamanhos → gera 3 produtos

2. ❌ **Falta endpoint para listar produtos gerados**
   - Frontend precisa saber quais produtos foram gerados
   - Exemplo: `GET /categories/{id}/generated-products`

3. ❌ **Falta validação de sabores por tamanho**
   - Backend precisa validar quantos sabores são permitidos por tamanho
   - Exemplo: Pizza Pequena = 1 sabor, Média = 2, Grande = 3

4. ❌ **Falta schema para produtos de pizza**
   - Precisa de schema específico para retornar produtos com sabores
   - Exemplo: `PizzaProductOut` com lista de sabores disponíveis

#### 🔧 **CORREÇÕES NECESSÁRIAS**

##### **1. Criar lógica de geração automática de produtos**

**Arquivo**: `Backend/src/api/app/services/pizza_service.py` (NOVO)

```python
"""
Serviço para geração automática de produtos de pizza.
"""

from src.core import models
from sqlalchemy.orm import Session

def generate_pizza_products(db: Session, category_id: int):
    """
    Gera produtos automaticamente para categoria CUSTOMIZABLE.
    
    Para cada tamanho na categoria, cria um produto:
    - "Pizza {Tamanho} (1 sabor)"
    - "Pizza {Tamanho} (2 sabores)"
    - etc
    
    Args:
        db: Sessão do banco
        category_id: ID da categoria CUSTOMIZABLE
    
    Returns:
        List[Product]: Lista de produtos gerados
    """
    category = db.query(models.Category).filter_by(id=category_id).first()
    
    if not category or category.type != "CUSTOMIZABLE":
        return []
    
    # Busca grupo de tamanhos
    size_group = None
    for group in category.option_groups:
        if group.type == "SIZE":
            size_group = group
            break
    
    if not size_group:
        return []
    
    generated_products = []
    
    # Para cada tamanho, cria produtos
    for size_item in size_group.items:
        # Pega quantidade máxima de sabores deste tamanho
        max_flavors = size_item.max_flavors or 1
        
        # Cria produtos: "Pizza Grande (1 sabor)", "Pizza Grande (2 sabores)", etc
        for num_flavors in range(1, max_flavors + 1):
            product_name = f"Pizza {size_item.name} ({num_flavors} sabor{'es' if num_flavors > 1 else ''})"
            
            # Verifica se produto já existe
            existing = db.query(models.Product).filter_by(
                name=product_name,
                store_id=category.store_id
            ).first()
            
            if existing:
                generated_products.append(existing)
                continue
            
            # Cria novo produto
            product = models.Product(
                name=product_name,
                store_id=category.store_id,
                type="PREPARED",
                unit="UNIT",
                control_stock=False,
                is_active=True,
                # Metadados para identificar que é produto gerado
                metadata={
                    "generated": True,
                    "category_id": category_id,
                    "size_option_id": size_item.id,
                    "max_flavors": num_flavors
                }
            )
            
            db.add(product)
            db.flush()
            
            # Vincula produto à categoria
            link = models.ProductCategoryLink(
                product_id=product.id,
                category_id=category_id,
                price=0,  # Preço será definido pelos sabores
                is_on_promotion=False
            )
            db.add(link)
            
            generated_products.append(product)
    
    db.commit()
    return generated_products
```

##### **2. Adicionar endpoint para produtos gerados**

**Arquivo**: `Backend/src/api/app/routes/categories.py`

```python
@router.get("/{category_id}/products", response_model=List[ProductOut])
def get_category_products(
    category_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retorna produtos de uma categoria.
    
    Para categorias CUSTOMIZABLE, retorna produtos gerados automaticamente.
    Para categorias GENERAL, retorna produtos vinculados manualmente.
    """
    category = db.query(models.Category).filter_by(id=category_id).first()
    
    if not category:
        raise HTTPException(404, "Categoria não encontrada")
    
    if category.type == "CUSTOMIZABLE":
        # Gera produtos automaticamente
        from src.api.app.services.pizza_service import generate_pizza_products
        products = generate_pizza_products(db, category_id)
    else:
        # Retorna produtos vinculados
        products = [link.product for link in category.product_links if link.product.is_active]
    
    return products
```

##### **3. Adicionar validação de sabores por tamanho**

**Arquivo**: `Backend/src/api/app/events/handlers/cart_handler.py`

Já implementado! A função `validate_pizza_configuration()` já faz isso.

##### **4. Adicionar campo `max_flavors` em `OptionItem`**

**Arquivo**: `Backend/src/core/models/business/option_item.py`

```python
class OptionItem(Base, TimestampMixin):
    # ... campos existentes ...
    
    # ✅ NOVO CAMPO: Máximo de sabores permitidos (para tamanhos de pizza)
    max_flavors: Mapped[int | None] = mapped_column(Integer, nullable=True)
```

**Migration**:
```sql
ALTER TABLE option_items ADD COLUMN max_flavors INTEGER NULL;
```

---

### 🟡 **ADMIN** (Flutter Web)

#### ✅ **O QUE ESTÁ CERTO**

1. ✅ **Wizard de Categoria** (`category_wizard_cubit.dart`)
   - Tem abas: Detalhes, Tamanho, Massa, Borda, Disponibilidade
   - Suporta criação de grupos de opções
   - Suporta criação de itens de opções

2. ✅ **Modelo `Category`** (`category.dart`)
   - Tem campo `type` (GENERAL, CUSTOMIZABLE)
   - Tem campo `selectedTemplate`
   - Tem lista `optionGroups`

3. ✅ **Enum `CategoryTemplateType`** (`category_template_type.dart`)
   - Tem valor `none`

#### ❌ **O QUE ESTÁ ERRADO / FALTANDO**

1. ❌ **Falta campo `max_flavors` na UI de tamanhos**
   - Na aba "Tamanho", ao criar um tamanho, falta campo para definir quantos sabores são permitidos
   - Exemplo: Pequena = 1 sabor, Média = 2 sabores, Grande = 3 sabores

2. ❌ **Falta visualização de produtos gerados**
   - Após salvar categoria CUSTOMIZABLE, admin não vê os produtos gerados
   - Precisa de tela/lista mostrando os produtos criados automaticamente

3. ❌ **Falta explicação na UI**
   - Admin não entende que produtos serão gerados automaticamente
   - Precisa de tooltip/help text explicando

#### 🔧 **CORREÇÕES NECESSÁRIAS**

##### **1. Adicionar campo `max_flavors` na UI de tamanhos**

**Arquivo**: `Admin/lib/pages/categories/screens/tabs/size_tab.dart` (ou similar)

```dart
// Na UI de criação de tamanho, adicionar campo:

TextFormField(
  decoration: InputDecoration(
    labelText: 'Quantidade máxima de sabores',
    hintText: 'Ex: 1 para pequena, 2 para média, 3 para grande',
    helperText: 'Define quantos sabores o cliente pode escolher neste tamanho',
  ),
  keyboardType: TextInputType.number,
  initialValue: sizeItem.maxFlavors?.toString() ?? '1',
  validator: (value) {
    if (value == null || value.isEmpty) return 'Campo obrigatório';
    final num = int.tryParse(value);
    if (num == null || num < 1 || num > 4) {
      return 'Digite um número entre 1 e 4';
    }
    return null;
  },
  onSaved: (value) {
    sizeItem.maxFlavors = int.parse(value!);
  },
)
```

##### **2. Adicionar visualização de produtos gerados**

**Arquivo**: `Admin/lib/pages/categories/screens/category_products_preview.dart` (NOVO)

```dart
class CategoryProductsPreview extends StatelessWidget {
  final int categoryId;
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _fetchGeneratedProducts(categoryId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final products = snapshot.data!;
        
        return Column(
          children: [
            Text('Produtos gerados automaticamente:'),
            ...products.map((product) => ListTile(
              title: Text(product.name),
              subtitle: Text('Preço base: R\$ ${product.price}'),
            )),
          ],
        );
      },
    );
  }
  
  Future<List<Product>> _fetchGeneratedProducts(int categoryId) async {
    // Chamar endpoint GET /categories/{id}/products
    final response = await dio.get('/categories/$categoryId/products');
    return (response.data as List).map((e) => Product.fromJson(e)).toList();
  }
}
```

##### **3. Adicionar help text explicativo**

**Arquivo**: `Admin/lib/pages/categories/screens/tabs/details_tab.dart`

```dart
// Ao selecionar tipo CUSTOMIZABLE, mostrar:

if (category.type == CategoryType.customizable) {
  InfoCard(
    icon: Icons.info_outline,
    title: 'Categoria de Pizza (Monte Sua Pizza)',
    description: 'Produtos serão gerados automaticamente baseado nos tamanhos cadastrados.\n\n'
        'Exemplo: Se você cadastrar 3 tamanhos (Pequena, Média, Grande), '
        'o sistema criará automaticamente produtos como:\n'
        '• Pizza Pequena (1 sabor)\n'
        '• Pizza Média (2 sabores)\n'
        '• Pizza Grande (3 sabores)\n\n'
        'Os clientes escolherão os sabores ao adicionar ao carrinho.',
  ),
}
```

---

### 🟢 **TOTEM** (Flutter Mobile)

#### ✅ **O QUE ESTÁ CERTO**

1. ✅ **Modelo `Product`** (`product.dart`)
   - Suporta produtos normais
   - Tem lista `prices` (FlavorPrice)
   - Tem lista `variantLinks`

2. ✅ **Carrinho** (`cart_cubit.dart`, `cart_handler.py`)
   - Já suporta produtos com complementos
   - Já calcula preços corretamente
   - Já agrupa itens idênticos

#### ❌ **O QUE ESTÁ ERRADO / FALTANDO**

1. ❌ **Falta UI específica para pizzas geradas**
   - Quando cliente clica em "Pizza Grande (3 sabores)", precisa mostrar lista de sabores
   - Atualmente mostra variant genérico

2. ❌ **Falta validação de quantidade de sabores**
   - Cliente pode escolher mais ou menos sabores que o permitido
   - Precisa forçar min=max=3 para "Pizza Grande (3 sabores)"

3. ❌ **Falta exibição de preço por sabor**
   - Cliente não vê que "Camarão" custa +R$ 15
   - Precisa mostrar preço de cada sabor na lista

#### 🔧 **CORREÇÕES NECESSÁRIAS**

##### **1. Criar UI específica para produtos de pizza**

**Arquivo**: `totem/lib/pages/product_details/pizza_product_dialog.dart` (NOVO)

```dart
class PizzaProductDialog extends StatefulWidget {
  final Product product;  // Ex: "Pizza Grande (3 sabores)"
  
  @override
  _PizzaProductDialogState createState() => _PizzaProductDialogState();
}

class _PizzaProductDialogState extends State<PizzaProductDialog> {
  List<FlavorPrice> selectedFlavors = [];
  int get maxFlavors => widget.product.metadata['max_flavors'] ?? 1;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          // Título
          Text('${widget.product.name}'),
          Text('Escolha ${maxFlavors} sabor${maxFlavors > 1 ? 'es' : ''}'),
          
          // Lista de sabores
          Expanded(
            child: ListView.builder(
              itemCount: availableFlavors.length,
              itemBuilder: (context, index) {
                final flavor = availableFlavors[index];
                final isSelected = selectedFlavors.contains(flavor);
                
                return CheckboxListTile(
                  title: Text(flavor.product.name),
                  subtitle: Text('+R\$ ${flavor.price / 100}'),
                  value: isSelected,
                  enabled: isSelected || selectedFlavors.length < maxFlavors,
                  onChanged: (checked) {
                    setState(() {
                      if (checked!) {
                        selectedFlavors.add(flavor);
                      } else {
                        selectedFlavors.remove(flavor);
                      }
                    });
                  },
                );
              },
            ),
          ),
          
          // Botão adicionar
          ElevatedButton(
            onPressed: selectedFlavors.length == maxFlavors
                ? () => _addToCart()
                : null,
            child: Text('Adicionar - R\$ ${_calculateTotal()}'),
          ),
        ],
      ),
    );
  }
  
  void _addToCart() {
    // Adicionar ao carrinho com sabores selecionados
    context.read<CartCubit>().updateItem(
      UpdateCartItemPayload(
        productId: widget.product.id,
        categoryId: widget.product.categoryId,
        quantity: 1,
        variants: [
          UpdateCartItemVariant(
            variantId: flavorVariantId,
            options: selectedFlavors.map((f) => 
              UpdateCartItemVariantOption(
                variantOptionId: f.id,
                quantity: 1,
              )
            ).toList(),
          ),
        ],
      ),
    );
    Navigator.pop(context);
  }
  
  double _calculateTotal() {
    final basePrice = widget.product.basePrice;
    final maxFlavorPrice = selectedFlavors.isEmpty
        ? 0
        : selectedFlavors.map((f) => f.price).reduce(max);
    return (basePrice + maxFlavorPrice) / 100;
  }
}
```

##### **2. Detectar produtos de pizza e abrir dialog específico**

**Arquivo**: `totem/lib/pages/menu/product_card.dart`

```dart
void _onProductTap(Product product) {
  // Detecta se é produto gerado de pizza
  if (product.metadata?['generated'] == true) {
    showDialog(
      context: context,
      builder: (_) => PizzaProductDialog(product: product),
    );
  } else {
    // Produto normal
    showDialog(
      context: context,
      builder: (_) => ProductDetailsDialog(product: product),
    );
  }
}
```

---

## 📊 MATRIZ DE CORREÇÕES

| # | Componente | Arquivo | Ação | Prioridade | Tempo |
|---|------------|---------|------|------------|-------|
| 1 | Backend | `pizza_service.py` | Criar serviço de geração de produtos | 🔴 CRÍTICA | 2h |
| 2 | Backend | `categories.py` | Adicionar endpoint `/products` | 🔴 CRÍTICA | 30min |
| 3 | Backend | `option_item.py` | Adicionar campo `max_flavors` | 🔴 CRÍTICA | 15min |
| 4 | Backend | Migration | Criar migration para `max_flavors` | 🔴 CRÍTICA | 15min |
| 5 | Admin | `size_tab.dart` | Adicionar campo `max_flavors` na UI | 🟡 ALTA | 1h |
| 6 | Admin | `category_products_preview.dart` | Criar tela de preview de produtos | 🟡 ALTA | 1h |
| 7 | Admin | `details_tab.dart` | Adicionar help text explicativo | 🟢 MÉDIA | 30min |
| 8 | Totem | `pizza_product_dialog.dart` | Criar dialog específico para pizzas | 🔴 CRÍTICA | 2h |
| 9 | Totem | `product_card.dart` | Detectar e abrir dialog correto | 🔴 CRÍTICA | 30min |
| 10 | Totem | `product.dart` | Adicionar campo `metadata` | 🟡 ALTA | 15min |

**Tempo Total Estimado**: **8 horas**

---

## 🎯 PLANO DE IMPLEMENTAÇÃO

### **FASE 1: Backend (3h)**
1. ✅ Criar migration para `max_flavors`
2. ✅ Atualizar modelo `OptionItem`
3. ✅ Criar `pizza_service.py`
4. ✅ Adicionar endpoint `/categories/{id}/products`
5. ✅ Testar geração de produtos

### **FASE 2: Admin (2.5h)**
6. ✅ Adicionar campo `max_flavors` na UI
7. ✅ Criar tela de preview de produtos
8. ✅ Adicionar help text
9. ✅ Testar criação de categoria CUSTOMIZABLE

### **FASE 3: Totem (2.5h)**
10. ✅ Adicionar campo `metadata` no modelo
11. ✅ Criar `PizzaProductDialog`
12. ✅ Atualizar `ProductCard` para detectar pizzas
13. ✅ Testar fluxo completo de compra

---

## ✅ CRITÉRIOS DE ACEITAÇÃO

### **Backend**
- [ ] Ao salvar categoria CUSTOMIZABLE com 3 tamanhos, gera 3+ produtos automaticamente
- [ ] Endpoint `/categories/{id}/products` retorna produtos gerados
- [ ] Campo `max_flavors` é salvo e retornado corretamente

### **Admin**
- [ ] Ao criar tamanho, campo "Máximo de sabores" aparece
- [ ] Após salvar categoria, mostra lista de produtos gerados
- [ ] Help text explica claramente o funcionamento

### **Totem**
- [ ] Ao clicar em "Pizza Grande (3 sabores)", abre dialog específico
- [ ] Dialog força escolha de exatamente 3 sabores
- [ ] Preço é calculado corretamente (base + maior sabor)
- [ ] Item é adicionado ao carrinho com sabores corretos

---

## 📝 NOTAS IMPORTANTES

### **Compatibilidade com Pizzas Prontas**
- Pizzas do tipo "Preferidas" (categoria GENERAL) continuam funcionando normalmente
- Não precisa de alteração

### **Migração de Dados Existentes**
- Categorias CUSTOMIZABLE existentes precisarão ser recriadas
- OU executar script de migração para gerar produtos retroativamente

### **Performance**
- Geração de produtos é feita apenas ao salvar categoria
- Não impacta performance do cardápio

---

## 🚀 PRÓXIMOS PASSOS

1. **Revisar esta auditoria** com a equipe
2. **Aprovar plano de implementação**
3. **Criar branch** `feature/pizza-system-refactor`
4. **Implementar FASE 1** (Backend)
5. **Implementar FASE 2** (Admin)
6. **Implementar FASE 3** (Totem)
7. **Testes integrados**
8. **Deploy em staging**
9. **Testes de aceitação**
10. **Deploy em produção**

---

**Última Atualização**: 23/11/2025 12:15  
**Autor**: Equipe de Desenvolvimento MenuHub  
**Status**: ⚠️ AGUARDANDO APROVAÇÃO
