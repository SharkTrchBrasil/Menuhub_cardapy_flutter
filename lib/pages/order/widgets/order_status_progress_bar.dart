import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/order.dart';
import 'package:totem/core/services/timezone_service.dart';
import 'package:totem/cubit/store_cubit.dart';

class OrderStatusProgressBar extends StatefulWidget {
  final Order order;

  const OrderStatusProgressBar({super.key, required this.order});

  @override
  State<OrderStatusProgressBar> createState() => _OrderStatusProgressBarState();
}

class _OrderStatusProgressBarState extends State<OrderStatusProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var displayStatuses = [
      'PENDING',
      'PREPARING',
      'READY',
      'DISPATCHED',
      'CONCLUDED',
    ];

    // Se for retirada e não tiver entrega no meio
    if (widget.order.deliveryType != 'delivery') {
      displayStatuses.remove('DISPATCHED');
    }

    final currentStatus = widget.order.lastStatus.toUpperCase();

    // Mapeamento de status para índice
    int currentStatusIndex = -1;
    if (currentStatus == 'CANCELLED') {
      currentStatusIndex = -1; // Permanecerá -1
    } else if (currentStatus == 'CONCLUDED' || currentStatus == 'FINALIZED') {
      currentStatusIndex = displayStatuses.length - 1;
    } else if (currentStatus == 'CONFIRMED') {
      currentStatusIndex = displayStatuses.indexOf('PREPARING');
    } else {
      currentStatusIndex = displayStatuses.indexOf(currentStatus);
    }

    // Se não encontrou, talvez seja um status intermediário ou especial
    if (currentStatusIndex == -1 && currentStatus != 'CANCELLED') {
      // Fallback
      if (currentStatus.contains('PREPAR'))
        currentStatusIndex = displayStatuses.indexOf('PREPARING');
      else if (currentStatus.contains('READY'))
        currentStatusIndex = displayStatuses.indexOf('READY');
      else if (currentStatus.contains('DISPATCH'))
        currentStatusIndex = displayStatuses.indexOf('DISPATCHED');
      else if (currentStatus.contains('ROUTE'))
        currentStatusIndex = displayStatuses.indexOf('DISPATCHED');
    }

    final Color statusColor = _getStatusColor(currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF717171),
                  ),
                  children: [
                    const TextSpan(text: 'Status do pedido: '),
                    TextSpan(
                      text:
                          currentStatus == 'CANCELLED'
                              ? 'Cancelado'
                              : widget.order.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentStatus == 'CONCLUDED' ||
                        currentStatus == 'FINALIZED') ...[
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: TimezoneService.formatStoreDateTime(
                          widget.order.closedAt ?? widget.order.updatedAt,
                          context.read<StoreCubit>().state.store?.timezone ??
                              "America/Sao_Paulo",
                          format: 'HH:mm',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              if (currentStatus == 'CONCLUDED' || currentStatus == 'FINALIZED')
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(displayStatuses.length, (index) {
              final isPast =
                  index < currentStatusIndex ||
                  (currentStatusIndex == displayStatuses.length - 1 &&
                      index < displayStatuses.length);
              final isCurrent = index == currentStatusIndex;

              return Expanded(
                child:
                    isCurrent
                        ? AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Container(
                              height: 6,
                              margin: EdgeInsets.only(
                                right:
                                    index == displayStatuses.length - 1 ? 0 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  statusColor.withOpacity(0.3),
                                  statusColor,
                                  _animationController.value,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        )
                        : Container(
                          height: 6,
                          margin: EdgeInsets.only(
                            right: index == displayStatuses.length - 1 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPast ? statusColor : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
      case 'PREPARING':
        return Colors.blue;
      case 'READY':
        return Colors.purple;
      case 'DISPATCHED':
      case 'ON_ROUTE':
        return Colors.cyan;
      case 'CONCLUDED':
      case 'FINALIZED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
