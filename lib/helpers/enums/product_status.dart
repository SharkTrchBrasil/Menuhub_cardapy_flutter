// lib/helpers/enums/product_status.dart
// Alinhado com Backend e Admin

enum ProductStatus {
  ACTIVE,
  INACTIVE,
  ARCHIVED,
  UNKNOWN;

  static ProductStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return ACTIVE;
      case 'INACTIVE':
        return INACTIVE;
      case 'ARCHIVED':
        return ARCHIVED;
      default:
        return UNKNOWN;
    }
  }
  
  /// Nome para exibição ao usuário
  String get displayName {
    switch (this) {
      case ACTIVE:
        return 'Ativo';
      case INACTIVE:
        return 'Inativo';
      case ARCHIVED:
        return 'Arquivado';
      case UNKNOWN:
        return 'Desconhecido';
    }
  }
}