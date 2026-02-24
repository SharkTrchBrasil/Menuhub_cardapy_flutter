/// Helper global para parsear valores monetários que podem vir como:
/// - int (centavos direto)
/// - double (reais, precisa converter para centavos)
/// - Map com {'value': int, 'currency': 'BRL'} (MoneyAmount do backend)
/// - String (tenta parsear)
/// - null (retorna null para campos opcionais)
///
/// Retorna int? para ser flexível com campos obrigatórios e opcionais.
/// Use `parseMoneyAmount(value) ?? 0` quando precisar de valor não-null.
int? parseMoneyAmount(dynamic value) {
  if (value == null) return null;

  // Se já é int (centavos), retorna direto
  if (value is int) return value;

  // Se é double (reais), converte para centavos
  if (value is double) return (value * 100).round();

  // Se é Map (MoneyAmount do backend)
  if (value is Map) {
    final val = value['value'] ?? value['amount'];
    if (val is int) return val;
    if (val is double) return (val * 100).round();
    if (val is num) return val.toInt();
    return 0;
  }

  // Se é String, tenta parsear
  if (value is String) {
    // Se tem ponto decimal, é valor em reais
    if (value.contains('.') || value.contains(',')) {
      final normalized = value.replaceAll(',', '.');
      final d = double.tryParse(normalized);
      if (d != null) return (d * 100).round();
    }
    // Senão, tenta como int (centavos)
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

/// Alias para retrocompatibilidade - use parseMoneyAmount diretamente
@Deprecated('Use parseMoneyAmount diretamente, ele já retorna int?')
int? parseMoneyAmountNullable(dynamic value) => parseMoneyAmount(value);

/// Formata valor em centavos para exibição em reais
String formatMoneyAmount(int cents, {String currency = 'BRL'}) {
  final reais = cents / 100.0;

  if (currency == 'BRL') {
    return 'R\$ ${reais.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Para outras moedas, usa formato internacional
  return '\$${reais.toStringAsFixed(2)}';
}

/// Converte centavos para reais (double)
double centsToReais(int cents) {
  return cents / 100.0;
}

/// Converte reais para centavos (int)
int reaisToCents(double reais) {
  return (reais * 100).round();
}
