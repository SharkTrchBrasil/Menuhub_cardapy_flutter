// widgets/clean_text_field.dart
import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';

class CleanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputType? keyboardType;

  const CleanTextField({
    super.key,
    required this.controller,
    required this.title,
    required this.hint,
    this.validator,
    this.enabled = true,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? colors.surfaceVariant.withOpacity(0.3) : colors.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // Sem borda no estado normal
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary, width: 2), // Borda colorida ao focar
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}



// O tipo genérico T representa o tipo dos itens na lista (ex: StoreCity)
class CleanSelectionFormField<T> extends StatelessWidget {
  final String title;
  final T? initialValue;
  final String hintText;
  final Future<Either<Exception, List<T>>> Function() fetch;
  final void Function(T?) onChanged;
  final FormFieldValidator<T>? validator;

  const CleanSelectionFormField({
    super.key,
    required this.title,
    this.initialValue,
    this.hintText = 'Selecione uma opção',
    required this.fetch,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Usamos um DropdownButtonFormField para a seleção
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<Either<Exception, List<T>>>(
          future: fetch(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && initialValue == null) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Erro ao carregar dados.');
            }

            return snapshot.data!.fold(
                  (error) => Text('Erro: ${error.toString()}'),
                  (items) {
                // Garante que o valor inicial, se existir, está na lista.
                final T? validInitialValue = (initialValue != null && items.contains(initialValue))
                    ? initialValue
                    : null;

                return DropdownButtonFormField<T>(
                  value: validInitialValue,

                  hint: Text(
                    hintText,
                    style: TextStyle(color: colors.onSurface.withOpacity(0.5)),
                  ),
                  items: items.map((item) {
                    // Assumimos que o item tem uma propriedade 'name'.
                    // Ajuste `(item as dynamic).name` se o nome da propriedade for outro.
                    return DropdownMenuItem<T>(
                      value: item,
                      child: Text((item as dynamic).name),
                    );
                  }).toList(),
                  onChanged: onChanged,
                  validator: validator,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  isExpanded: true,
                );
              },
            );
          },
        ),
      ],
    );
  }
}