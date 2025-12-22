enum PricingStrategyType {
  sumOfItems,
  highestPrice,
  lowestPrice;

  /// Converte uma string vinda da API para o nosso Enum.
  static PricingStrategyType fromString(String? value) {
    if (value == null) return PricingStrategyType.sumOfItems;
    switch (value.toUpperCase()) {
      case 'SUM_OF_ITEMS':
        return PricingStrategyType.sumOfItems;
      case 'HIGHEST_PRICE':
        return PricingStrategyType.highestPrice;
      case 'LOWEST_PRICE':
        return PricingStrategyType.lowestPrice;
      default:
        return PricingStrategyType.sumOfItems;
    }
  }

  /// Converte para string compatível com a API
  String toApiString() {
    switch (this) {
      case PricingStrategyType.sumOfItems:
        return 'SUM_OF_ITEMS';
      case PricingStrategyType.highestPrice:
        return 'HIGHEST_PRICE';
      case PricingStrategyType.lowestPrice:
        return 'LOWEST_PRICE';
    }
  }
}
















