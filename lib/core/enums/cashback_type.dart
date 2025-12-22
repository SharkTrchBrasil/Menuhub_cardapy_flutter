enum CashbackType {
  none,
  fixed,
  percentage;

  /// Converte uma string vinda da API para o nosso Enum.
  static CashbackType fromString(String? value) {
    if (value == null) return CashbackType.none;
    switch (value.toLowerCase()) {
      case 'fixed':
        return CashbackType.fixed;
      case 'percentage':
        return CashbackType.percentage;
      case 'none':
      default:
        return CashbackType.none;
    }
  }

  /// Retorna um nome amigável para exibição na UI.
  String get displayName {
    switch (this) {
      case CashbackType.none:
        return 'Nenhum';
      case CashbackType.fixed:
        return 'Valor Fixo (R\$)';
      case CashbackType.percentage:
        return 'Porcentagem (%)';
    }
  }
}
















