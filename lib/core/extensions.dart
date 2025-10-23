import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../themes/ds_theme.dart';
import '../themes/ds_theme_switcher.dart';

extension IntX on int {
  String get toCurrency => UtilBrasilFields.obterReal(this/100);
}


String? formatTime(TimeOfDay? time) {
  if (time == null) return null;
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
int compareTime(TimeOfDay t1, TimeOfDay t2) {
  return (t1.hour * 60 + t1.minute) - (t2.hour * 60 + t2.minute);
}

// Em algum lugar útil, talvez um arquivo de 'utils' ou 'helpers'
extension StringExtension on String {
  String toSlug() {
    String slug = toLowerCase(); // Converte para minúsculas
    slug = slug.replaceAll(RegExp(r'\s+'), '-'); // Substitui espaços por hífens
    slug = slug.replaceAll(RegExp(r'[^\w-]+'), ''); // Remove caracteres não-alfanuméricos (exceto hífens)
    // Opcional: Remover acentos
    const acentos = 'áàãâéèêíìóòõôúùûç';
    const semAcentos = 'aaaaeeeiioooouuuc';
    for (int i = 0; i < acentos.length; i++) {
      slug = slug.replaceAll(acentos[i], semAcentos[i]);
    }
    return slug;
  }
}

extension ThemeExtension on BuildContext {
  DsTheme get dsTheme => watch<DsThemeSwitcher>().theme;
}

void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), entry.remove);





}



extension CurrencyFormatExtension on num {
  String toCurrency({String locale = 'pt_BR', String symbol = 'R\$'}) {
    final format = NumberFormat.currency(locale: locale, symbol: symbol);
    return format.format(this);
  }
}