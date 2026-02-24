// lib/pages/order/widgets/order_address_widget.dart
// ✅ Widget Endereço - Estilo Menuhub
// Endereço completo de entrega/retirada

import 'package:flutter/material.dart';
import 'package:totem/models/order.dart';

class OrderAddressWidget extends StatelessWidget {
  final Address? address;
  final String? streetName;
  final String? streetNumber;
  final String? neighborhood;
  final String? city;
  final String? complement;
  final bool isPickup;

  const OrderAddressWidget({
    super.key,
    this.address,
    this.streetName,
    this.streetNumber,
    this.neighborhood,
    this.city,
    this.complement,
    this.isPickup = false,
  });

  @override
  Widget build(BuildContext context) {
    // Usa address se fornecido, senão usa campos individuais
    final street = address?.streetName ?? streetName ?? '';
    final number = address?.streetNumber ?? streetNumber ?? '';
    final bairro = address?.neighborhood ?? neighborhood ?? '';
    final cidade = address?.city ?? city ?? '';
    final comp = address?.complement ?? complement;

    // Monta linha 1: Rua, Número
    String line1 = street;
    if (number.isNotEmpty) {
      line1 += ', $number';
    }

    // Monta linha 2: Bairro, Cidade - Complemento
    String line2 = bairro;
    if (cidade.isNotEmpty) {
      line2 += ', $cidade';
    }
    if (comp != null && comp.isNotEmpty) {
      line2 += ' - $comp';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            isPickup ? 'Endereço de retirada' : 'Endereço de entrega',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Endereço
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Icon(
                Icons.location_on,
                color: Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 12),
              
              // Texto do endereço
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linha 1: Rua, Número
                    if (line1.isNotEmpty)
                      Text(
                        line1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    // Linha 2: Bairro, Cidade - Complemento
                    if (line2.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line2,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
