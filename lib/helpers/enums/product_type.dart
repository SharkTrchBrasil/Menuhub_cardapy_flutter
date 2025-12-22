// lib/helpers/enums/product_type.dart
// Alinhado com Backend e Admin

enum ProductType {
  INDIVIDUAL,
  KIT,
  COMBO,
  PREPARED,
  UNKNOWN;

  static ProductType fromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'INDIVIDUAL':
        return INDIVIDUAL;
      case 'KIT':
        return KIT;
      case 'COMBO':
        return COMBO;
      case 'PREPARED':
        return PREPARED;
      default:
        return UNKNOWN;
    }
  }
  
  /// Nome para exibição ao usuário
  String get displayName {
    switch (this) {
      case INDIVIDUAL:
        return 'Individual';
      case KIT:
        return 'Kit';
      case COMBO:
        return 'Combo';
      case PREPARED:
        return 'Preparado';
      case UNKNOWN:
        return 'Desconhecido';
    }
  }
}
