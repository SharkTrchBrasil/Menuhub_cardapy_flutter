import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';

import '../themes/ds_theme_switcher.dart';

class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    this.title,
    this.hint,
    this.onChanged,
    this.enabled = true,
    this.formatters,
    this.keyboardType,
    this.validator,
    this.initialValue,
    this.controller, // <-- Adicionado
  });

  final String? initialValue;
  final String? title;
  final String? hint;
  final void Function(String)? onChanged;
  final bool enabled;
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextEditingController? controller; // <-- Adicionado

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return TextFormField(
      controller: controller, // <-- Adicionado
      initialValue: controller == null ? initialValue : null, // evita conflito
      readOnly: !enabled,
      decoration: InputDecoration(
        labelText: title,
        labelStyle: theme.paragraphTextStyle.colored(theme.onBackgroundColor),
        hintText: hint,
        hintStyle: theme.paragraphTextStyle.colored(theme.onBackgroundColor.withAlpha(200)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
      style: theme.paragraphTextStyle.colored(theme.onBackgroundColor),
      keyboardType: keyboardType,
      inputFormatters: formatters,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
