// Em: lib/pages/checkout/widgets/cash_options.dart
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/widgets/app_text_field.dart';
import '../checkout_cubit.dart';

class CashChangeOption extends StatelessWidget {
  const CashChangeOption({super.key});

  @override
  Widget build(BuildContext context) {
    // O widget agora ouve o CheckoutCubit para saber seu estado
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      // buildWhen foca em reconstruir apenas quando estas propriedades mudam
      buildWhen: (previous, current) =>
      previous.needsChange != current.needsChange ||
          previous.changeFor != current.changeFor,
      builder: (context, state) {
        final checkoutCubit = context.read<CheckoutCubit>();

        return Column(
          children: [
            CheckboxListTile(
              title: const Text('Precisa de troco?'),
              value: state.needsChange,
              onChanged: (value) {
                // Informa o cubit diretamente sobre a mudança
                checkoutCubit.updateNeedsChange(value ?? false);
              },
            ),
            if (state.needsChange)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: AppTextField(
                  title: 'Troco para quanto?',
                  hint: 'Ex: R\$ 50,00',
                  // O valor inicial é formatado a partir do estado do cubit
                  initialValue: state.changeFor != null
                      ? UtilBrasilFields.obterReal(state.changeFor!)
                      : '',
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CentavosInputFormatter(moeda: true),
                  ],
                  keyboardType: TextInputType.number,
                  // A validação agora é SÓ sobre o formato do campo
                  validator: (value) {
                    if (state.needsChange && (value == null || value.isEmpty)) {
                      return 'Informe o valor para troco';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Informa o cubit sobre o novo valor
                    final doubleValue = UtilBrasilFields.converterMoedaParaDouble(value!);
                    checkoutCubit.updateChangeFor(doubleValue);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}