// ✅ ATUALIZADO: Agora segue o padrão do Admin e iFood para exibição premium
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';

class PaymentMethodsWidget extends StatelessWidget {
  final List<PaymentMethodGroup> paymentGroups;

  const PaymentMethodsWidget({super.key, required this.paymentGroups});

  @override
  Widget build(BuildContext context) {
    if (paymentGroups.isEmpty) return const SizedBox.shrink();

    // ✅ SEPARAÇÃO DE VALES: Divide grupos de Vales em Refeição e Alimentação
    final List<PaymentMethodGroup> expandedGroups = [];
    for (final group in paymentGroups) {
      final title = (group.title ?? group.name).toLowerCase();
      if (title.contains('vale') ||
          title.contains('benefício') ||
          title.contains('beneficio')) {
        final vrList = <PlatformPaymentMethod>[];
        final vaList = <PlatformPaymentMethod>[];

        for (final m in group.methods) {
          final n = m.name.toLowerCase();
          final ik = (m.iconKey ?? '').toLowerCase();

          if (n.contains('refeição') ||
              n.contains('refeicao') ||
              n.contains(' meal') ||
              n.contains('vr') ||
              ik.contains('vr')) {
            vrList.add(m);
          } else if (n.contains('alimentação') ||
              n.contains('alimentacao') ||
              n.contains(' food') ||
              n.contains('va') ||
              ik.contains('va') ||
              ik.contains('alelo') ||
              ik.contains('sodexo') ||
              ik.contains('ticket')) {
            vaList.add(m);
          } else {
            vaList.add(m);
          }
        }

        if (vrList.isNotEmpty) {
          expandedGroups.add(
            group.copyWith(title: 'Vale Refeição', methods: vrList),
          );
        }
        if (vaList.isNotEmpty) {
          expandedGroups.add(
            group.copyWith(title: 'Vale Alimentação', methods: vaList),
          );
        }
      } else {
        expandedGroups.add(group);
      }
    }

    // ✅ ORDENAÇÃO: Garante que os grupos sigam a prioridade (Dinheiro > Pix > Crédito > Débito > Vales)
    final sortedGroups = List<PaymentMethodGroup>.from(expandedGroups);
    sortedGroups.sort((a, b) {
      final nameA = a.title ?? a.name;
      final nameB = b.title ?? b.name;
      return _getGroupPriority(nameA).compareTo(_getGroupPriority(nameB));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          "Formas de pagamento",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...sortedGroups.map((group) => _buildPaymentGroup(context, group)),
      ],
    );
  }

  Widget _buildPaymentGroup(BuildContext context, PaymentMethodGroup group) {
    // Filtra apenas métodos ativos
    final activeMethods =
        group.methods
            .where((method) => method.activation?.isActive == true)
            .toList();

    if (activeMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    String groupTitle = group.title ?? group.name;

    // ✅ SIMPLIFICAÇÃO: "Cartão de crédito" -> "Crédito"
    if (groupTitle.toLowerCase().contains('crédito') ||
        groupTitle.toLowerCase().contains('credito')) {
      groupTitle = 'Crédito';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                activeMethods.map((m) {
                  final String displayName = _formatFlagName(
                    m.name,
                    groupTitle,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50], // Fundo muito suave
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPaymentIcon(m.iconKey),
                        const SizedBox(width: 8),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3F3E3E),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  /// Helper para definir a ordem dos grupos (Sincronizado com mobile/backend)
  int _getGroupPriority(String title) {
    final t = title.toLowerCase();
    if (t.contains('dinheiro')) return 1;
    if (t.contains('pix') || t.contains('digital')) return 2;
    if (t.contains('crédito') || t.contains('credito')) return 3;
    if (t.contains('débito') || t.contains('debito')) return 4;
    if (t.contains('refeição') || t.contains('refeicao')) return 5;
    if (t.contains('alimentação') || t.contains('alimentacao')) return 6;
    if (t.contains('vale') ||
        t.contains('benefício') ||
        t.contains('beneficio')) {
      return 7;
    }
    return 8;
  }

  /// Limpa redundâncias no nome da flag
  String _formatFlagName(String methodName, String groupTitle) {
    final title = groupTitle.toLowerCase();
    if (title.contains('dinheiro') || title.contains('pix')) return methodName;

    final regex = RegExp(
      r'crédito|credito|débito|debito|vale|alimentação|alimentacao|refeição|refeicao|voucher',
      caseSensitive: false,
    );

    String cleaned = methodName.replaceAll(regex, '').trim();
    return cleaned.isEmpty ? methodName : cleaned;
  }

  Widget _buildPaymentIcon(String? iconKey) {
    if (iconKey != null && iconKey.isNotEmpty) {
      final cleanKey = iconKey.replaceAll('.svg', '').toLowerCase();
      // Mapeamento simples
      final Map<String, String> iconMap = {
        'visa': 'visa',
        'master': 'mastercard',
        'mastercard': 'mastercard',
        'elo': 'elo',
        'hiper': 'hipercard',
        'hipercard': 'hipercard',
        'amex': 'amex',
        'pix': 'pix',
        'cash': 'cash',
        'dinheiro': 'cash',
      };

      final String mapped = iconMap[cleanKey] ?? cleanKey;
      final String assetPath = 'assets/icons/$mapped.svg';

      return SizedBox(
        width: 20,
        height: 20,
        child: SvgPicture.asset(
          assetPath,
          placeholderBuilder:
              (context) => const Icon(Icons.credit_card, size: 16),
        ),
      );
    }
    return const Icon(Icons.payment, size: 16, color: Colors.black45);
  }
}
