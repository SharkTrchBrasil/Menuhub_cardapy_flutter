import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:totem/core/utils/pix_generator.dart';
import 'package:totem/models/order.dart';

/// Tela de Pagamento PIX com QR Code e Copia e Cola
/// 
/// Exibida após o cliente finalizar pedido com pagamento PIX Manual.
/// Mostra:
/// - QR Code do pagamento (padrão BR Code)
/// - Copia e Cola do código PIX
/// - Chave PIX da loja
/// - Valor total do pedido
class PixPaymentPage extends StatefulWidget {
  /// Valor total do pedido em centavos
  final int totalCents;
  
  /// Chave PIX da loja
  final String pixKey;
  
  /// Tipo da chave PIX ('cpf', 'cnpj', 'email', 'phone', 'random')
  final String? pixKeyType;
  
  /// Nome da loja
  final String storeName;
  
  /// Cidade da loja
  final String storeCity;
  
  /// Número do pedido para referência
  final String? orderNumber;
  
  /// ID do pedido para navegação posterior
  final int? orderId;
  
  /// Objeto Order completo para navegação
  final Order? order;

  const PixPaymentPage({
    super.key,
    required this.totalCents,
    required this.pixKey,
    this.pixKeyType,
    required this.storeName,
    required this.storeCity,
    this.orderNumber,
    this.orderId,
    this.order,
  });

  @override
  State<PixPaymentPage> createState() => _PixPaymentPageState();
}

class _PixPaymentPageState extends State<PixPaymentPage> with SingleTickerProviderStateMixin {
  late final String _pixPayload;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  
  bool _copiedPayload = false;
  bool _copiedKey = false;

  @override
  void initState() {
    super.initState();
    
    // Gera o payload PIX
    _pixPayload = PixGenerator.generatePayload(
      pixKey: widget.pixKey,
      pixKeyType: widget.pixKeyType,
      merchantName: widget.storeName,
      merchantCity: widget.storeCity,
      amount: widget.totalCents / 100.0,
      txId: widget.orderNumber,
      description: widget.orderNumber != null 
          ? 'Pedido ${widget.orderNumber}' 
          : null,
    );
    
    // Animação de entrada
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _copyPayload() {
    Clipboard.setData(ClipboardData(text: _pixPayload));
    setState(() => _copiedPayload = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Código PIX copiado!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Reset após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiedPayload = false);
    });
  }

  void _copyKey() {
    Clipboard.setData(ClipboardData(text: widget.pixKey));
    setState(() => _copiedKey = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Chave PIX copiada!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Reset após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiedKey = false);
    });
  }

  void _goToOrderDetails() {
    // ✅ CORREÇÃO: Passa o Order completo via extra para a página de detalhes
    if (widget.order != null) {
      context.go('/order/${widget.orderId ?? widget.order!.id}', extra: widget.order);
    } else {
      // Fallback: vai para histórico de pedidos
      context.go('/orders/history');
    }
  }
  
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedValue = _formatCurrency(widget.totalCents / 100.0);
    final keyTypeLabel = PixGenerator.getKeyTypeLabel(widget.pixKeyType);
    final formattedKey = PixGenerator.formatPixKeyForDisplay(
      widget.pixKey, 
      widget.pixKeyType,
    );
    
    return Scaffold(
      backgroundColor: const Color(0xFF00A884), // Verde PIX
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Pagamento PIX',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Ícone PIX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_2,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Valor
                Text(
                  formattedValue,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                if (widget.orderNumber != null)
                  Text(
                    'Pedido #${widget.orderNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Card com QR Code
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Escaneie o QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        'Abra o app do seu banco e escaneie',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00A884),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: _pixPayload,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Divider com texto
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'ou copie o código',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Botão Copia e Cola
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _copyPayload,
                          icon: Icon(_copiedPayload ? Icons.check : Icons.copy),
                          label: Text(
                            _copiedPayload ? 'Copiado!' : 'Copiar código PIX',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _copiedPayload 
                                ? Colors.green.shade600 
                                : const Color(0xFF00A884),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Card com Chave PIX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A884).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.key,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chave $keyTypeLabel',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedKey,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _copyKey,
                            icon: Icon(
                              _copiedKey ? Icons.check_circle : Icons.copy,
                              color: _copiedKey 
                                  ? Colors.green 
                                  : const Color(0xFF00A884),
                            ),
                            tooltip: 'Copiar chave',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Botão Já paguei
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToOrderDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00A884),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Já fiz o pagamento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Texto informativo
                Text(
                  'O lojista será notificado quando o pagamento for identificado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
