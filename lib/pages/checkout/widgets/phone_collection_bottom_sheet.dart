// Em: lib/pages/checkout/widgets/phone_collection_bottom_sheet.dart
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ Bottom sheet para coletar telefone do cliente (estilo similar ao do troco)
class PhoneCollectionBottomSheet extends StatefulWidget {
  final String? initialPhone;

  const PhoneCollectionBottomSheet({
    super.key,
    this.initialPhone,
  });

  @override
  State<PhoneCollectionBottomSheet> createState() => _PhoneCollectionBottomSheetState();
}

class _PhoneCollectionBottomSheetState extends State<PhoneCollectionBottomSheet> {
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

    return Container(
      padding: const EdgeInsets.all(24),
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
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TelefoneInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Telefone',
              hintText: '(00) 00000-0000',
              prefixIcon: const Icon(Icons.phone),
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _validateAndSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Confirmar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
      setState(() => _errorMessage = 'Telefone inválido. Informe um número completo.');
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

