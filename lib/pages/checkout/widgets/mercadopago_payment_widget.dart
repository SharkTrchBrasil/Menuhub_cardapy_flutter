import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:totem/models/store.dart';
import 'package:totem/core/di.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Widget para criar pagamento online via Mercado Pago
class MercadoPagoPaymentWidget extends StatefulWidget {
  final Store store;
  final double orderTotal; // Total em reais
  final Function(String paymentId, Map<String, dynamic> paymentData)? onPaymentCreated;

  const MercadoPagoPaymentWidget({
    super.key,
    required this.store,
    required this.orderTotal,
    this.onPaymentCreated,
  });

  @override
  State<MercadoPagoPaymentWidget> createState() => _MercadoPagoPaymentWidgetState();
}

class _MercadoPagoPaymentWidgetState extends State<MercadoPagoPaymentWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _documentController = TextEditingController();
  final _documentTypeController = TextEditingController(text: 'CPF');
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _paymentId;
  String? _qrCodeBase64;
  String? _qrCode;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentController.dispose();
    _documentTypeController.dispose();
    super.dispose();
  }

  Future<void> _createPayment(String paymentMethod) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = getIt<Dio>();
      final apiUrl = dotenv.env['API_URL'] ?? '';
      
      // ✅ Cria pagamento via backend
      final response = await dio.post(
        '$apiUrl/admin/mercadopago/${widget.store.id}/order/temp/create-payment',
        data: {
          'amount': widget.orderTotal,
          'description': 'Pedido - ${widget.store.name}',
          'payer_email': _emailController.text.trim(),
          'payer_first_name': _firstNameController.text.trim(),
          'payer_last_name': _lastNameController.text.trim(),
          'payer_document_type': _documentTypeController.text,
          'payer_document_number': _documentController.text.replaceAll(RegExp(r'[^\d]'), ''),
          'payment_method_id': paymentMethod,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      final paymentData = response.data;
      setState(() {
        _paymentId = paymentData['payment_id'] as String?;
        _qrCodeBase64 = paymentData['qr_code_base64'] as String?;
        _qrCode = paymentData['qr_code'] as String?;
        _isLoading = false;
      });

      if (widget.onPaymentCreated != null && _paymentId != null) {
        widget.onPaymentCreated!(_paymentId!, paymentData);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao criar pagamento: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Se pagamento já foi criado, mostra QR Code ou status
    if (_paymentId != null) {
      if (_qrCodeBase64 != null) {
        return _buildQrCodeView();
      }
      return _buildPaymentStatusView();
    }

    // ✅ Formulário para criar pagamento
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'E-mail obrigatório';
              if (!value.contains('@')) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Nome obrigatório';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Sobrenome',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Sobrenome obrigatório';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _documentTypeController.text,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CPF', child: Text('CPF')),
                    DropdownMenuItem(value: 'CNPJ', child: Text('CNPJ')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _documentTypeController.text = value ?? 'CPF';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _documentController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    if (_documentTypeController.text == 'CPF')
                      CpfInputFormatter()
                    else
                      CnpjInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: _documentTypeController.text == 'CPF' ? 'CPF' : 'CNPJ',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Documento obrigatório';
                    final clean = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (_documentTypeController.text == 'CPF' && clean.length != 11) {
                      return 'CPF inválido';
                    }
                    if (_documentTypeController.text == 'CNPJ' && clean.length != 14) {
                      return 'CNPJ inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ✅ Botões para escolher método
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _createPayment('pix'),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Pagar com PIX'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _createPayment('credit_card'),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Cartão'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCodeView() {
    return Column(
      children: [
        const Text(
          'Escaneie o QR Code para pagar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _qrCodeBase64 != null
              ? Image.memory(
                  base64Decode(_qrCodeBase64!.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '')),
                  width: 250,
                  height: 250,
                )
              : const CircularProgressIndicator(),
        ),
        if (_qrCode != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _qrCode!,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _qrCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código PIX copiado!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Aguardando confirmação do pagamento...',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusView() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Pagamento processado!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'ID: $_paymentId',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

