// lib/widgets/store_closed_widgets.dart
// ✅ Widgets de validação para loja fechada - estilo Menuhub

import 'package:flutter/material.dart';

/// Modal para página de detalhes do produto quando loja está fechada
/// Estilo: Bottom sheet com mensagem amigável
class StoreClosedProductModal extends StatelessWidget {
  final String? nextOpenTime;
  final VoidCallback? onDismiss;

  const StoreClosedProductModal({
    super.key,
    this.nextOpenTime,
    this.onDismiss,
  });

  /// Mostra o modal como bottom sheet
  static Future<void> show(BuildContext context, {String? nextOpenTime}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StoreClosedProductModal(
        nextOpenTime: nextOpenTime,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Título
          Text(
            'Esta loja está fechada no momento',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Subtítulo
          Text(
            nextOpenTime != null
                ? 'Mas você pode olhar os itens à vontade e\nvoltar quando ela estiver aberta.\n\nAbre $nextOpenTime'
                : 'Mas você pode olhar os itens à vontade e\nvoltar quando ela estiver aberta.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Botão
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss ?? () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4002B), // Vermelho Menuhub
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ok, entendi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal para carrinho/checkout quando loja está fechada
/// Estilo: Bottom sheet com ilustração
class StoreClosedCartModal extends StatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onSeeOtherOptions;
  final String? nextOpenTime;

  const StoreClosedCartModal({
    super.key,
    this.onDismiss,
    this.onSeeOtherOptions,
    this.nextOpenTime,
  });

  @override
  State<StoreClosedCartModal> createState() => _StoreClosedCartModalState();

  /// Mostra o modal como bottom sheet
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSeeOtherOptions,
    String? nextOpenTime,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StoreClosedCartModal(
        onDismiss: () => Navigator.pop(context),
        onSeeOtherOptions: onSeeOtherOptions ?? () => Navigator.pop(context),
        nextOpenTime: nextOpenTime,
      ),
    );
  }
}

class _StoreClosedCartModalState extends State<StoreClosedCartModal> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Ilustração (usando ícone estilizado como fallback)
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2), // Rosa claro
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pessoa com celular (ícone estilizado)
                Icon(
                  Icons.person,
                  size: 80,
                  color: const Color(0xFFE4002B),
                ),
                // Relógio no canto
                Positioned(
                  right: 30,
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.schedule,
                      size: 24,
                      color: const Color(0xFFE4002B),
                    ),
                  ),
                ),
                // Check no canto
                Positioned(
                  left: 35,
                  bottom: 50,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4002B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Título
          const Text(
            'Esta loja está fechada no momento',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Subtítulo
          Text(
            widget.nextOpenTime != null
                ? 'Mas você pode olhar os itens à vontade e\nvoltar quando ela estiver aberta.\n\n${widget.nextOpenTime}'
                : 'Mas você pode olhar os itens à vontade e\nvoltar quando ela estiver aberta.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Botão principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSeeOtherOptions ?? widget.onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4002B), // Vermelho Menuhub
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ok, entendi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog central para desktop quando loja está fechada
class StoreClosedDesktopDialog extends StatelessWidget {
  final String? nextOpenTime;
  final VoidCallback? onDismiss;

  const StoreClosedDesktopDialog({
    super.key,
    this.nextOpenTime,
    this.onDismiss,
  });

  /// Mostra o dialog centralizado (para desktop)
  static Future<void> show(BuildContext context, {String? nextOpenTime}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StoreClosedDesktopDialog(
        nextOpenTime: nextOpenTime,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustração
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.store,
                    size: 50,
                    color: const Color(0xFFE4002B),
                  ),
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.schedule,
                        size: 18,
                        color: const Color(0xFFE4002B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Título
            const Text(
              'Esta loja está fechada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Subtítulo
            Text(
              nextOpenTime != null
                  ? 'Você pode continuar navegando, mas não será possível finalizar pedidos até a loja abrir.\n\nAbre $nextOpenTime'
                  : 'Você pode continuar navegando, mas não será possível finalizar pedidos até a loja abrir.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Botão
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss ?? () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE4002B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Entendi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper para verificar se deve mostrar modal de loja fechada
/// e qual tipo de modal mostrar baseado no contexto
class StoreClosedHelper {
  /// Mostra o modal apropriado baseado no contexto
  /// [isProductPage] - true se estiver na página de produto
  /// [isCartPage] - true se estiver no carrinho/checkout
  /// [isDesktop] - true se for layout desktop
  static Future<void> showModal(
    BuildContext context, {
    bool isProductPage = false,
    bool isCartPage = false,
    bool isDesktop = false,
    String? nextOpenTime,
    VoidCallback? onSeeOtherOptions,
  }) {
    if (isDesktop) {
      return StoreClosedDesktopDialog.show(context, nextOpenTime: nextOpenTime);
    } else if (isCartPage) {
      return StoreClosedCartModal.show(
        context,
        onSeeOtherOptions: onSeeOtherOptions,
        nextOpenTime: nextOpenTime,
      );
    } else {
      return StoreClosedProductModal.show(context, nextOpenTime: nextOpenTime);
    }
  }
}
