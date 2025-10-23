// ✅ NOVO MODELO PARA OS COMPONENTES DE UM KIT
import 'package:totem/models/product.dart';

class KitComponent {
  final int quantity;
  final Product component; // O produto que faz parte do kit

  KitComponent({required this.quantity, required this.component});

  factory KitComponent.fromJson(Map<String, dynamic> json) {
    return KitComponent(
      quantity: json['quantity'] as int? ?? 1,
      // Assume que o componente vem aninhado como um objeto de produto completo
      component: Product.fromJson(json['component'] as Map<String, dynamic>? ?? {}),
    );
  }
}