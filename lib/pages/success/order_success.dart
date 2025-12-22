// lib/pages/success/order_success.dart
// ✅ DEPRECATED: Use OrderDetailsPage em vez desta página
// Esta página é mantida apenas para compatibilidade com código antigo

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:totem/models/order.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/helpers/payment_method.dart';

/// @deprecated Use OrderDetailsPage de pages/order/order_details_page.dart
class OrderSuccessPageLegacy extends StatelessWidget {
  final Order? order;
  final PlatformPaymentMethod? paymentMethod;

  const OrderConfirmationPage({
    super.key,
    this.order,
    this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        // Remove o botão de voltar padrão
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone de sucesso
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),

              // Título principal
              Text(
                'Pedido realizado com sucesso!',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Mensagem de subtítulo com o número do pedido
              if (order != null)
                Text(
                  'Seu pedido #${order!.id.toString().padLeft(4, '0')} já está sendo preparado e logo sairá para entrega.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                )
              else
                Text(
                  'Seu pedido já está sendo preparado e logo sairá para entrega.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),

              // ✅ NOVO: Exibe QR code para Pix estático se método for MANUAL_PIX
              if (paymentMethod != null && paymentMethod!.method_type == 'MANUAL_PIX') ...[
                _buildPixQrCode(context, paymentMethod!),
                const SizedBox(height: 24),
              ],

              const Spacer(), // Ocupa o espaço para empurrar os botões para baixo

              // Botão principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // ✅ Navega para detalhes do pedido
                  onPressed: () {
                    if (order != null) {
                      context.go('/order/${order!.id}');
                    } else {
                      context.go('/orders');
                    }
                  },
                  child: const Text('Acompanhar pedido'),
                ),
              ),
              const SizedBox(height: 12),

              // Botão secundário
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => context.go('/'),
                  child: const Text(
                    'Voltar para o início',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Espaço extra na parte inferior
            ],
          ),
        ),
      ),
    );
  }
  
  /// ✅ NOVO: Constrói widget com QR code para Pix estático
  Widget _buildPixQrCode(BuildContext context, PlatformPaymentMethod method) {
    final pixKey = method.getStaticPixKey();
    final pixKeyType = method.getStaticPixKeyType();
    
    if (pixKey == null || pixKey.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // ✅ Formata a chave conforme o tipo
    String formattedKey = pixKey;
    String keyTypeLabel = '';
    
    switch (pixKeyType?.toUpperCase()) {
      case 'CPF':
        keyTypeLabel = 'CPF';
        if (pixKey.length == 11) {
          formattedKey = '${pixKey.substring(0, 3)}.${pixKey.substring(3, 6)}.${pixKey.substring(6, 9)}-${pixKey.substring(9)}';
        }
        break;
      case 'CNPJ':
        keyTypeLabel = 'CNPJ';
        if (pixKey.length == 14) {
          formattedKey = '${pixKey.substring(0, 2)}.${pixKey.substring(2, 5)}.${pixKey.substring(5, 8)}/${pixKey.substring(8, 12)}-${pixKey.substring(12)}';
        }
        break;
      case 'PHONE':
        keyTypeLabel = 'Celular';
        if (pixKey.length == 11) {
          formattedKey = '(${pixKey.substring(0, 2)}) ${pixKey.substring(2, 7)}-${pixKey.substring(7)}';
        }
        break;
      case 'EMAIL':
        keyTypeLabel = 'E-mail';
        break;
      case 'RANDOM':
        keyTypeLabel = 'Chave aleatória';
        break;
      default:
        keyTypeLabel = 'Chave PIX';
    }
    
    // ✅ Gera QR code usando a chave PIX (sem formatação para o QR code)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Pague com PIX',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          // ✅ QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: pixKey, // ✅ Usa chave sem formatação para o QR code
              width: 200,
              height: 200,
              errorBuilder: (context, error) => Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.error_outline, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ✅ Chave formatada abaixo do QR code
          Text(
            'Chave PIX ${keyTypeLabel.isNotEmpty ? '($keyTypeLabel)' : ''}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            formattedKey,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // ✅ Botão para copiar
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pixKey));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chave PIX copiada!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar chave PIX'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}