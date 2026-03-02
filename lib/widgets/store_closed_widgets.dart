// lib/widgets/store_closed_widgets.dart
// ✅ Widget unificado para validação de loja fechada - estilo com ilustração (Imagem 2)

import 'package:flutter/material.dart';
import 'package:totem/widgets/ds_button.dart';

/// Widget unificado para quando a loja está fechada - estilo com ilustração (Imagem 2)
class StoreClosedModal extends StatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onSeeOtherOptions;
  final String? nextOpenTime;

  const StoreClosedModal({
    super.key,
    this.onDismiss,
    this.onSeeOtherOptions,
    this.nextOpenTime,
  });

  @override
  State<StoreClosedModal> createState() => _StoreClosedModalState();

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
      builder:
          (context) => StoreClosedModal(
            onDismiss: () => Navigator.pop(context),
            onSeeOtherOptions:
                onSeeOtherOptions ?? () => Navigator.pop(context),
            nextOpenTime: nextOpenTime,
          ),
    );
  }
}

class _StoreClosedModalState extends State<StoreClosedModal> {
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
                ? 'Mas você pode olhar os itens à vontade e\nvoltar quando ela estiver aberta.\n\nAbre ${widget.nextOpenTime}'
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
            child: DsButton(
              onPressed: widget.onSeeOtherOptions ?? widget.onDismiss,
              backgroundColor: Colors.black,
              label: 'Ok, entendi',
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
      builder:
          (context) => StoreClosedDesktopDialog(
            nextOpenTime: nextOpenTime,
            onDismiss: () => Navigator.pop(context),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

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
              child: DsButton(
                onPressed: onDismiss ?? () => Navigator.pop(context),
                backgroundColor: Colors.black,
                label: 'Entendi',
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
    } else {
      // Unificado para o novo StoreClosedModal (Imagem 2)
      return StoreClosedModal.show(
        context,
        onSeeOtherOptions: onSeeOtherOptions,
        nextOpenTime: nextOpenTime,
      );
    }
  }
}

// ✅ Type Aliases para compatibilidade com o resto do código
typedef StoreClosedProductModal = StoreClosedModal;
typedef StoreClosedCartModal = StoreClosedModal;
