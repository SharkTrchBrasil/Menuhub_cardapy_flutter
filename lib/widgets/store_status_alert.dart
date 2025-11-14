// lib/widgets/store_status_alert.dart
import 'package:flutter/material.dart';
import 'package:totem/models/store.dart';
import 'package:totem/services/store_status_service.dart';

/// Widget que exibe alerta sobre o status da loja
class StoreStatusAlert extends StatelessWidget {
  final Store? store;
  final bool showWhenOpen;

  const StoreStatusAlert({
    super.key,
    required this.store,
    this.showWhenOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = StoreStatusService.validateStoreStatus(store);

    // Se está aberto e não queremos mostrar quando aberto
    if (status.canReceiveOrders && !showWhenOpen) {
      return const SizedBox.shrink();
    }

    // Define cor e ícone baseado no status
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    if (!status.canReceiveOrders) {
      backgroundColor = Colors.orange.shade700;
      textColor = Colors.white;
      icon = _getIconForReason(status.reason);
      message = StoreStatusService.getFriendlyMessage(status);
    } else {
      backgroundColor = Colors.green.shade600;
      textColor = Colors.white;
      icon = Icons.check_circle;
      message = 'Loja aberta';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForReason(String reason) {
    switch (reason) {
      case 'store_closed':
        return Icons.store_mall_directory_outlined;
      case 'outside_hours':
        return Icons.schedule;
      case 'not_operational':
        return Icons.error_outline;
      case 'no_delivery_methods':
        return Icons.delivery_dining_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

/// Widget compacto para exibir status no header
class StoreStatusBadge extends StatelessWidget {
  final Store? store;

  const StoreStatusBadge({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final status = StoreStatusService.validateStoreStatus(store);

    if (status.canReceiveOrders) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'Indisponível',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

