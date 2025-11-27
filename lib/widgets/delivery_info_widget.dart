import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/core/extensions.dart';

/// Widget que exibe informações de entrega (tempo e taxa)
/// Similar ao iFood: "Hoje | 33-43 min • R$ 2,99"
class DeliveryInfoWidget extends StatelessWidget {
  final bool showDeliveryTypeSelector;
  final VoidCallback? onTap;

  const DeliveryInfoWidget({
    super.key,
    this.showDeliveryTypeSelector = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        final store = state.store;
        final config = store?.store_operation_config;
        
        if (config == null) return const SizedBox.shrink();
        
        // Tempo estimado de entrega (usa valores médios da config)
        final deliveryMin = config.deliveryEstimatedMin ?? 30;
        final deliveryMax = config.deliveryEstimatedMax ?? 50;
        
        // Taxa de entrega (usa valor padrão da config)
        // Para clientes logados com endereço, será calculado dinamicamente
        final deliveryFee = config.deliveryFee ?? 0;
        
        final isDeliveryEnabled = config.isDeliveryAvailable;
        final isPickupEnabled = config.isPickupAvailable;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDeliveryTypeSelector && (isDeliveryEnabled || isPickupEnabled))
              _DeliveryTypeButton(
                isDeliveryEnabled: isDeliveryEnabled,
                isPickupEnabled: isPickupEnabled,
                onTap: onTap,
              ),
            if (showDeliveryTypeSelector) const SizedBox(width: 12),
            // Card de tempo e taxa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hoje',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$deliveryMin-$deliveryMax min',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  if (deliveryFee > 0) ...[
                    Text(
                      ' • ',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      'R\$ ${deliveryFee.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    Text(
                      ' • ',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      'Grátis',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeliveryTypeButton extends StatelessWidget {
  final bool isDeliveryEnabled;
  final bool isPickupEnabled;
  final VoidCallback? onTap;

  const _DeliveryTypeButton({
    required this.isDeliveryEnabled,
    required this.isPickupEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _showDeliveryTypeDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delivery_dining_outlined,
              size: 20,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              'Entrega',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DeliveryTypeDialog(
        isDeliveryEnabled: isDeliveryEnabled,
        isPickupEnabled: isPickupEnabled,
      ),
    );
  }
}

/// Dialog para selecionar tipo de entrega
class DeliveryTypeDialog extends StatefulWidget {
  final bool isDeliveryEnabled;
  final bool isPickupEnabled;

  const DeliveryTypeDialog({
    super.key,
    required this.isDeliveryEnabled,
    required this.isPickupEnabled,
  });

  @override
  State<DeliveryTypeDialog> createState() => _DeliveryTypeDialogState();
}

class _DeliveryTypeDialogState extends State<DeliveryTypeDialog> {
  String _selectedType = 'delivery';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como quer receber o pedido?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (widget.isDeliveryEnabled)
              _DeliveryOption(
                icon: Icons.delivery_dining,
                title: 'Entrega',
                subtitle: 'A gente leva até você',
                isSelected: _selectedType == 'delivery',
                onTap: () => setState(() => _selectedType = 'delivery'),
              ),
            if (widget.isDeliveryEnabled && widget.isPickupEnabled)
              const SizedBox(height: 12),
            if (widget.isPickupEnabled)
              _DeliveryOption(
                icon: Icons.directions_walk,
                title: 'Retirada',
                subtitle: 'Você retira no local',
                isSelected: _selectedType == 'pickup',
                onTap: () => setState(() => _selectedType = 'pickup'),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Salvar no cubit a preferência de entrega/retirada
                  Navigator.of(context).pop(_selectedType);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _selectedType == 'delivery' ? 'Confirmar entrega' : 'Confirmar retirada',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

