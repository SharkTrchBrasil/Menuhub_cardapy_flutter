import 'package:intl/intl.dart';

class CurrencyUtils {
  /// Formata um valor double diretamente.
  /// Ex: 10.0 -> R$ 10,00
  static String format(double value, {String symbol = 'R\$', String locale = 'pt_BR'}) {
    // Garante que o locale está disponível
    // Intl.defaultLocale = locale; // Pode causar efeitos colaterais, melhor passar no construtor
    
    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return currencyFormat.format(value);
  }

  /// Converte centavos (int) para valor formatado.
  /// Ex: 1500 -> R$ 15,00
  static String formatCents(int cents, {String symbol = 'R\$'}) {
    if (cents == 0) return format(0, symbol: symbol);
    return format(cents / 100.0, symbol: symbol);
  }
}
