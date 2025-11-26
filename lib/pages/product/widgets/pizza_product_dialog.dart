import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem/models/category.dart';
import 'package:totem/models/option_group.dart';
import 'package:totem/models/option_item.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/flavor_price.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/models/update_cart_payload.dart';
import 'package:totem/models/cart_item.dart';

// Classe para representar a combinação de massa + borda
class DoughEdgeCombo {
  final OptionItem dough;
  final OptionItem edge;
  
  const DoughEdgeCombo(this.dough, this.edge);
  
  String get displayName => '${dough.name} + ${edge.name}';
  
  // Preços são armazenados em centavos, então dividimos por 100 para obter reais
  double get totalPrice => (dough.price + edge.price) / 100.0;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoughEdgeCombo &&
          runtimeType == other.runtimeType &&
          dough.id == other.dough.id &&
          edge.id == other.edge.id;
  
  @override
  int get hashCode => dough.id.hashCode ^ edge.id.hashCode;
}

class PizzaProductDialog extends StatefulWidget {
  final Category category;
  final OptionItem size;
  final List<Product> availableFlavors;

  const PizzaProductDialog({
    super.key,
    required this.category,
    required this.size,
    required this.availableFlavors,
  });

  @override
  State<PizzaProductDialog> createState() => _PizzaProductDialogState();
}

class _PizzaProductDialogState extends State<PizzaProductDialog> {
  int maxFlavors = 1;
  List<Product?> selectedFlavors = [];
  DoughEdgeCombo? selectedPreference; // Combinação de massa + borda

  OptionGroup? doughGroup;
  OptionGroup? edgeGroup;
  List<DoughEdgeCombo> availableCombos = [];

  @override
  void initState() {
    super.initState();
    _parseMaxFlavors();
    _findGroups();
    _generateCombos();
    // Initialize selected flavors list with nulls
    selectedFlavors = List.filled(maxFlavors, null, growable: false);
  }

  void _parseMaxFlavors() {
    // Try to find "X SABORES" in the size name
    final regex = RegExp(r'(\d+)\s*SABORES?', caseSensitive: false);
    final match = regex.firstMatch(widget.size.name);
    if (match != null) {
      maxFlavors = int.parse(match.group(1)!);
    } else {
      maxFlavors = 1;
    }
  }

  void _findGroups() {
    try {
      doughGroup = widget.category.optionGroups.firstWhere(
            (g) => g.name.toLowerCase().contains('massa'),
      );
    } catch (_) {}

    try {
      edgeGroup = widget.category.optionGroups.firstWhere(
            (g) => g.name.toLowerCase().contains('borda'),
      );
    } catch (_) {}
  }

  void _generateCombos() {
    if (doughGroup == null || edgeGroup == null) return;
    
    // Gera todas as combinações de massa + borda
    for (var dough in doughGroup!.items.where((item) => item.isActive)) {
      for (var edge in edgeGroup!.items.where((item) => item.isActive)) {
        availableCombos.add(DoughEdgeCombo(dough, edge));
      }
    }
    
    // Seleciona a primeira combinação por padrão (a opção gratuita, geralmente)
    if (availableCombos.isNotEmpty) {
      selectedPreference = availableCombos.first;
    }
  }

  double get _totalPrice {
    double maxFlavorPrice = 0.0;
    
    // Find the most expensive flavor among selected ones
    for (var flavor in selectedFlavors) {
      if (flavor != null) {
        final flavorPrice = flavor.prices.firstWhere(
              (fp) => fp.sizeOptionId == widget.size.id,
          orElse: () => const FlavorPrice.empty(),
        );
        if (flavorPrice.id != null) {
          double price = flavorPrice.price / 100.0;
          if (price > maxFlavorPrice) {
            maxFlavorPrice = price;
          }
        }
      }
    }
    
    // Fallback: Use size price if flavor price is 0
    if (maxFlavorPrice == 0 && widget.size.price > 0) {
      maxFlavorPrice = widget.size.price / 100.0;
    }
    
    double total = maxFlavorPrice;

    // Adiciona o preço da combinação de massa + borda
    if (selectedPreference != null) {
      total += selectedPreference!.totalPrice;
    }
    
    return total;
  }

  bool get _isValid {
    // Todos os sabores devem ser preenchidos
    if (selectedFlavors.contains(null)) return false;
    
    // Se há combinações disponíveis, uma deve ser selecionada
    if (availableCombos.isNotEmpty && selectedPreference == null) return false;
    
    return true;
  }

  void _addToCart() {
    if (!_isValid) return;

    final mainProduct = selectedFlavors[0]!;
    final note = StringBuffer();

    // Add other flavors to note
    if (maxFlavors > 1) {
      List<String> flavorNames = selectedFlavors.map((p) => p!.name).toList();
      note.write("Sabores: ${flavorNames.join(' / ')}. ");
    }

    // Adiciona informações da preferência selecionada
    if (selectedPreference != null) {
      note.write("${selectedPreference!.displayName}. ");
    }

    List<CartItemVariant> variants = [];
    
    // Add Dough and Edge as variants from the selected combo
    if (selectedPreference != null && doughGroup != null && edgeGroup != null) {
        // Adiciona a massa como variant
        variants.add(CartItemVariant(
            variantId: doughGroup!.id ?? 0, 
            name: doughGroup!.name, 
            options: [
                CartItemVariantOption(
                    variantOptionId: selectedPreference!.dough.id ?? 0, 
                    quantity: 1, 
                    name: selectedPreference!.dough.name, 
                    price: selectedPreference!.dough.price // Já está em centavos
                )
            ]
        ));
        
        // Adiciona a borda como variant
        variants.add(CartItemVariant(
            variantId: edgeGroup!.id ?? 0, 
            name: edgeGroup!.name, 
            options: [
                CartItemVariantOption(
                    variantOptionId: selectedPreference!.edge.id ?? 0, 
                    quantity: 1, 
                    name: selectedPreference!.edge.name, 
                    price: selectedPreference!.edge.price // Já está em centavos
                )
            ]
        ));
    }

    final payload = UpdateCartItemPayload(
      productId: mainProduct.id!,
      categoryId: widget.category.id!,
      quantity: 1,
      note: note.toString().trim(),
      sizeName: widget.size.name,
      variants: variants,
    );

    context.read<CartCubit>().updateItem(payload);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    // Image source: Category image or first available flavor image
    String? imageUrl = widget.category.image?.url;
    if (imageUrl == null && widget.availableFlavors.isNotEmpty) {
        imageUrl = widget.availableFlavors.first.coverImageUrl;
    }

    bool showImageSide = imageUrl != null && imageUrl.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 800,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Barra de Título
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.size.name.toUpperCase(),
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLUNA DA ESQUERDA (Imagem e Resumo)
                  if (showImageSide)
                  Container(
                    width: 350,
                    color: Colors.grey.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 4/3,
                          child: Image.network(imageUrl!, fit: BoxFit.cover),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Importante:",
                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "A pizza de mais de 1 sabor será cobrada pelo preço cheio do sabor mais caro.",
                                style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                currencyFormat.format(_totalPrice),
                                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // COLUNA DA DIREITA (Opções)
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              // Flavor Sections
                              if (!showImageSide) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Importante:",
                                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "A pizza de mais de 1 sabor será cobrada pelo preço cheio do sabor mais caro.",
                                        style: textTheme.bodySmall?.copyWith(color: Colors.amber.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              for (int i = 0; i < maxFlavors; i++)
                                _buildFlavorSection(i, theme, textTheme),

                              // Grupo único de Preferências (Massa + Borda)
                              if (availableCombos.isNotEmpty) ...[ const SizedBox(height: 32),
                                _buildHeader("Escolha a sua Preferência", "Escolha 1 opção", true),
                                const SizedBox(height: 16),
                                ...availableCombos.map((combo) => _buildComboTile(theme, textTheme, combo)),
                              ],
                            ],
                          ),
                        ),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const IconButton(onPressed: null, icon: Icon(Icons.remove, color: Colors.grey)),
                                    const Text("1", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(onPressed: null, icon: Icon(Icons.add, color: theme.primaryColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isValid ? _addToCart : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 16),
                                        child: Text("Adicionar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 16),
                                        child: Text(currencyFormat.format(_totalPrice), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle, bool isRequired) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
          if (isRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(4)),
              child: const Text("OBRIGATÓRIO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildFlavorSection(int index, DsTheme theme, TextTheme textTheme) {
    String title = index == 0 ? "Escolha um sabor" : "Escolha o ${index == 1 ? 'segundo' : '${index + 1}º'} sabor";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0) const SizedBox(height: 32),
        _buildHeader(title, "Escolha 1 opção.", true),
        const SizedBox(height: 16),
        ...widget.availableFlavors.map((flavor) => _buildFlavorTile(theme, textTheme, flavor, index)),
      ],
    );
  }

  Widget _buildFlavorTile(DsTheme theme, TextTheme textTheme, Product flavor, int slotIndex) {
    final isSelected = selectedFlavors[slotIndex] == flavor;
    
    // Calculate price for this flavor/size
    final flavorPrice = flavor.prices.firstWhere(
            (fp) => fp.sizeOptionId == widget.size.id,
        orElse: () => const FlavorPrice.empty(),
    );
    
    // If flavor not available for this size (no price entry), skip rendering.
    if (flavorPrice.id == null) {
        return const SizedBox.shrink(); 
    }
    
    // If unavailable, show with opacity.
    double opacity = flavorPrice.isAvailable ? 1.0 : 0.6;
    
    double price = flavorPrice.price / 100.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedFlavors[slotIndex] = flavor;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                  image: (flavor.coverImageUrl != null && flavor.coverImageUrl!.isNotEmpty) ? DecorationImage(image: NetworkImage(flavor.coverImageUrl!), fit: BoxFit.cover) : null,
                ),
                child: (flavor.coverImageUrl == null || flavor.coverImageUrl!.isEmpty) ? Icon(Icons.local_pizza, color: Colors.grey.shade400) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flavor.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    if (flavor.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(flavor.description!, style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text("+ R\$ ${price.toStringAsFixed(2)}", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.shade400, width: 2),
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile(DsTheme theme, TextTheme textTheme, OptionItem item, OptionItem? selected, Function(OptionItem) onSelect) {
    final isSelected = selected == item;
    return InkWell(
      onTap: () => onSelect(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "${item.name}${item.price > 0 ? ' (+ R\$ ${item.price})' : ''}",
                style: textTheme.bodyLarge?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.shade400, width: 2),
              ),
              child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle))) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboTile(DsTheme theme, TextTheme textTheme, DoughEdgeCombo combo) {
    final isSelected = selectedPreference == combo;
    final priceText = combo.totalPrice > 0 ? '+ R\$ ${combo.totalPrice.toStringAsFixed(2)}' : '';
    
    return InkWell(
      onTap: () => setState(() => selectedPreference = combo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combo.displayName,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  if (priceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        priceText,
                        style: textTheme.bodySmall?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.shade400, width: 2),
              ),
              child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle))) : null,
            ),
          ],
        ),
      ),
    );
  }
}
