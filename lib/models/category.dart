import 'package:equatable/equatable.dart';
// Removido o import de 'image_model.dart' que não será mais usado diretamente aqui.

class Category extends Equatable {
  const Category({
    this.id,
    required this.name,
    this.imageUrl, // ✅ CORRIGIDO: de 'image' para 'imageUrl' (String)
    required this.priority,
    required this.isActive,
  });

  final int? id;
  final String name;
  final int priority;
  final String? imageUrl; // ✅ TIPO ALTERADO: para String anulável
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? true,
      priority: map['priority'] as int? ?? 1,
      // ✅ ADICIONADO: Lógica para ler a URL da imagem.
      // O backend deve enviar a chave 'image_path' ou 'image_url' no JSON da categoria.
      // Estou assumindo 'image_path' para manter consistência com o modelo Product.
      imageUrl: map['image_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'priority': priority,
      'is_active': isActive,
      'image_url': imageUrl, // ✅ Adicionado ao toJson também
    };
  }

  // ✅ CORRIGIDO: Adicionado imageUrl ao construtor empty
  factory Category.empty() => Category(id: 0, name: '', priority: 0, isActive: false, imageUrl: null);

  @override
  List<Object?> get props => [id];
}