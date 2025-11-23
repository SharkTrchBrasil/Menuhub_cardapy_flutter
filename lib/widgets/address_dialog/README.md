# 📍 Address Dialog - Estrutura Modular

## 🎯 Visão Geral

O **AddressSelectionDialog** foi refatorado para ter uma estrutura modular, onde cada step é um widget independente e customizável.

## 📁 Estrutura de Arquivos

```
lib/widgets/
├── address_selection_dialog.dart          # Dialog principal (orquestrador)
└── address_dialog/
    ├── address_search_and_list_step.dart  # Step 0: Busca + Lista
    ├── address_map_step.dart              # Step 1: Mapa
    └── address_complete_form_step.dart    # Step 2: Formulário
```

## 🧩 Widgets Separados

### 1. `AddressSearchAndListStep`
**Arquivo**: `lib/widgets/address_dialog/address_search_and_list_step.dart`

**Responsabilidade**: 
- Campo de busca ativo
- Lista de endereços salvos
- Resultados da busca

**Props**:
```dart
AddressSearchAndListStep({
  required TextEditingController searchController,
  required FocusNode searchFocusNode,
  required List<AddressSearchResult> searchResults,
  required bool isSearching,
  required bool showSearchResults,
  required VoidCallback onClearSearch,
  required Function(AddressSearchResult) onSearchResultSelected,
  required Function(CustomerAddress) onSavedAddressSelected,
})
```

**Customização**:
- Altere a ilustração do pin (linha 45)
- Customize o estilo do campo de busca (linhas 60-90)
- Modifique o layout dos resultados (linhas 130-180)
- Personalize os cards de endereços salvos (linhas 240-280)

---

### 2. `AddressMapStep`
**Arquivo**: `lib/widgets/address_dialog/address_map_step.dart`

**Responsabilidade**:
- Exibir mapa com Mapbox
- Pin de localização
- Botão de confirmação

**Props**:
```dart
AddressMapStep({
  required double latitude,
  required double longitude,
  required VoidCallback onConfirm,
})
```

**Customização**:
- Altere o estilo do mapa (linha 25)
- Customize o pin do mapa (linhas 50-60)
- Modifique a mensagem "Você está aqui?" (linhas 70-100)
- Personalize o botão de confirmação (linhas 110-130)

---

### 3. `AddressCompleteFormStep`
**Arquivo**: `lib/widgets/address_dialog/address_complete_form_step.dart`

**Responsabilidade**:
- Formulário de detalhes do endereço
- Dropdowns de cidade e bairro
- Botões de favoritar (Casa/Trabalho)

**Props**:
```dart
AddressCompleteFormStep({
  AddressSearchResult? searchResult,
  required VoidCallback onSave,
  required TextEditingController numberController,
  required TextEditingController complementController,
  required TextEditingController referenceController,
  required String favoriteLabel,
  required Function(String) onFavoriteLabelChanged,
  StoreCity? selectedCity,
  StoreNeighborhood? selectedNeighborhood,
  required Function(StoreCity?) onCityChanged,
  required Function(StoreNeighborhood?) onNeighborhoodChanged,
})
```

**Customização**:
- Adicione/remova campos do formulário (linhas 120-220)
- Customize os dropdowns (linhas 130-180)
- Modifique os botões de favoritar (linhas 240-280)
- Personalize o botão de salvar (linhas 300-320)

---

## 🎨 Como Customizar

### Exemplo 1: Mudar a Ilustração do Step 0

**Arquivo**: `address_search_and_list_step.dart`

```dart
// Linha 45 - Altere de:
Icon(
  Icons.location_on,
  size: 80,
  color: Theme.of(context).primaryColor,
)

// Para:
Image.asset(
  'assets/images/custom_location_illustration.png',
  width: 150,
  height: 150,
)
```

### Exemplo 2: Adicionar Campo Extra no Formulário

**Arquivo**: `address_complete_form_step.dart`

```dart
// Após a linha 220, adicione:
const SizedBox(height: 16),

const Text('CEP', style: TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
TextFormField(
  decoration: const InputDecoration(
    hintText: '00000-000',
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  keyboardType: TextInputType.number,
),
```

### Exemplo 3: Customizar Cores do Mapa

**Arquivo**: `address_map_step.dart`

```dart
// Linha 25 - Altere o estilo do mapa:
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
  // Outros estilos disponíveis:
  // streets-v12 (padrão)
  // dark-v11 (escuro)
  // light-v11 (claro)
  // satellite-v9 (satélite)
  userAgentPackageName: 'com.menuhub.totem',
  tileSize: 512,
  zoomOffset: -1,
),
```

### Exemplo 4: Adicionar Validação Customizada

**Arquivo**: `address_complete_form_step.dart`

```dart
// No widget pai (address_selection_dialog.dart), modifique _saveAddress():
Future<void> _saveAddress() async {
  // Adicione validação customizada
  if (_numberController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor, preencha o número')),
    );
    return;
  }
  
  // Resto do código...
}
```

---

## 🔄 Fluxo de Navegação

```
┌─────────────────────────────────────┐
│  AddressSelectionDialog             │
│  (Orquestrador)                     │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Step 0: SearchAndListStep     │ │
│  │ - Busca                       │ │
│  │ - Lista de endereços          │ │
│  └───────────────────────────────┘ │
│            ↓                        │
│  ┌───────────────────────────────┐ │
│  │ Step 1: MapStep               │ │
│  │ - Confirma localização        │ │
│  └───────────────────────────────┘ │
│            ↓                        │
│  ┌───────────────────────────────┐ │
│  │ Step 2: CompleteFormStep      │ │
│  │ - Completa detalhes           │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## 🎯 Benefícios da Estrutura Modular

1. **Separação de Responsabilidades**: Cada widget tem uma única responsabilidade
2. **Fácil Customização**: Modifique apenas o widget que precisa
3. **Reutilização**: Use os widgets em outros contextos
4. **Manutenção**: Código mais limpo e organizado
5. **Testabilidade**: Teste cada widget separadamente

---

## 📝 Checklist de Customização

- [ ] Customizar ilustração do Step 0
- [ ] Ajustar cores do tema
- [ ] Adicionar/remover campos do formulário
- [ ] Modificar estilo do mapa
- [ ] Personalizar mensagens de erro
- [ ] Adicionar validações customizadas
- [ ] Alterar layout dos cards de endereço
- [ ] Customizar botões de favoritar

---

## 🚀 Próximos Passos

1. **Testes**: Adicione testes unitários para cada widget
2. **Animações**: Adicione transições suaves entre steps
3. **Acessibilidade**: Adicione labels e hints para screen readers
4. **Internacionalização**: Adicione suporte a múltiplos idiomas

---

**Última atualização**: 2025-11-22
