// Em: lib/pages/checkout/widgets/phone_collection_bottom_sheet.dart
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive_builder.dart';
import '../../../widgets/ds_button.dart';

/// ✅ Helper para mostrar dialog no desktop e bottomsheet no mobile
Future<String?> showPhoneCollectionDialog(
  BuildContext context, {
  String? initialPhone,
}) {
  final isDesktop = ResponsiveBuilder.isDesktop(context);

  if (isDesktop) {
    // ✅ Desktop: Mostra como Dialog
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: PhoneCollectionWidget(initialPhone: initialPhone),
            ),
          ),
    );
  } else {
    // ✅ Mobile: Mostra como BottomSheet
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ✅ CORREÇÃO: Remove fundo cinza
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: PhoneCollectionWidget(initialPhone: initialPhone),
          ),
    );
  }
}

/// ✅ Widget reutilizável para coletar telefone (usado em dialog e bottomsheet)
class PhoneCollectionWidget extends StatefulWidget {
  final String? initialPhone;

  const PhoneCollectionWidget({super.key, this.initialPhone});

  @override
  State<PhoneCollectionWidget> createState() => _PhoneCollectionWidgetState();
}

class _PhoneCollectionWidgetState extends State<PhoneCollectionWidget> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _controller.text = widget.initialPhone!;
    }
    _controller.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    // ✅ CORREÇÃO: Container branco explícito para evitar fundo cinza
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Informe seu telefone',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Precisamos do seu número de telefone para enviar atualizações e o resumo do seu pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Telefone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TelefoneInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '(00) 00000-0000',
                  prefixIcon: const Icon(Icons.phone),
                  errorText: _errorMessage,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                enabled: !_isSubmitting,
                autofocus:
                    isDesktop, // ✅ Desktop: foca automaticamente no campo
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                DsButton(
                  onPressed: _isSubmitting ? null : _validateAndSubmit,
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  label: 'Confirmar',
                  isLoading: _isSubmitting,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DsButton(
                onPressed: _isSubmitting ? null : _validateAndSubmit,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                label: 'Confirmar',
                isLoading: _isSubmitting,
              ),
            ),
        ],
      ),
    );
  }

  void _validateAndSubmit() {
    final phoneText = _controller.text.replaceAll(RegExp(r'[^\d]'), '');

    if (phoneText.isEmpty) {
      setState(() => _errorMessage = 'Por favor, informe seu telefone.');
      return;
    }

    if (phoneText.length < 10) {
      setState(
        () => _errorMessage = 'Telefone inválido. Informe um número completo.',
      );
      return;
    }

    // Formata o telefone para enviar (apenas dígitos)
    final formattedPhone = phoneText;

    setState(() => _isSubmitting = true);

    // Retorna o telefone formatado
    Navigator.pop(context, formattedPhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// ✅ DEPRECATED: Mantido para compatibilidade
/// Use showPhoneCollectionDialog() que detecta automaticamente desktop/mobile
@Deprecated('Use showPhoneCollectionDialog() instead')
class PhoneCollectionBottomSheet extends StatelessWidget {
  final String? initialPhone;

  const PhoneCollectionBottomSheet({super.key, this.initialPhone});

  @override
  Widget build(BuildContext context) {
    return PhoneCollectionWidget(initialPhone: initialPhone);
  }
}
