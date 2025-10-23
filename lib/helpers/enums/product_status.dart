
enum ProductStatus {
  active,
  inactive,
  archived,
  unknown; // Um valor padrão para segurança

  static ProductStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return active;
      case 'inactive':
        return inactive;
      case 'archived':
        return archived;
      default:
        return unknown;
    }
  }
}