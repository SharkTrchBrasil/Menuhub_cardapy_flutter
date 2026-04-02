import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/models/store.dart';

import 'package:totem/widgets/ds_button.dart'; // Importe seus modelos atualizados

class PaymentMethodSelectionList extends StatefulWidget {
  final List<PaymentMethodGroup> paymentGroups;
  final PlatformPaymentMethod? initialSelectedMethod;
  final double orderTotal; // ✅ NOVO: Total do pedido para pagamento online
  final Store store; // ✅ NOVO: Loja para pagamento online

  const PaymentMethodSelectionList({
    super.key,
    required this.paymentGroups,
    this.initialSelectedMethod,
    required this.orderTotal, // ✅ NOVO
    required this.store, // ✅ NOVO
  });

  @override
  State<PaymentMethodSelectionList> createState() =>
      _PaymentMethodSelectionListState();
}

class _PaymentMethodSelectionListState
    extends State<PaymentMethodSelectionList> {
  // Guarda o método de pagamento selecionado
  PlatformPaymentMethod? _selectedMethod;

  // ✅ NOVO: Variáveis de instância para grupos (acessíveis em todos os métodos)
  late final List<PaymentMethodGroup> offlineGroups;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialSelectedMethod;

    // ✅ NOVO: Separa métodos em "Pagamento na Entrega" e "Pagamento Online"
    final activeGroups =
        widget.paymentGroups
            .where(
              (group) => group.methods.any(
                (method) => method.activation?.isActive == true,
              ),
            )
            .toList();

    // ✅ CORREÇÃO: Filtra métodos ONLINE individualmente, não o grupo inteiro.
    // Antes: se o grupo "Crédito" tinha 1 método ONLINE (ex: Stripe), o grupo
    // inteiro era excluído — perdendo flags offline como Visa, Mastercard, Elo.
    final offline = <PaymentMethodGroup>[];

    for (final group in activeGroups) {
      final offlineMethods =
          group.methods.where((m) {
            return m.method_type != 'ONLINE' &&
                (m.activation?.details?['is_online'] != true);
          }).toList();

      if (offlineMethods.isNotEmpty) {
        offline.add(group.copyWith(methods: offlineMethods));
      }
    }

    offlineGroups = offline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fundo branco conforme solicitado
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Escolha o Pagamento',
          style: TextStyle(
            color: Color(0xFF3F3E3E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildOfflinePaymentTab(),
      // ✅ Botão de confirmação movido para bottomNavigationBar (Estilo iFood limpo)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DsButton(
            onPressed:
                _selectedMethod == null
                    ? null
                    : () {
                      Navigator.pop(context, _selectedMethod);
                    },
            label: 'Confirmar',
            minimumSize: const Size(
              double.infinity,
              56,
            ), // ✅ Botão bem grande (altura 56)
          ),
        ),
      ),
    );
  }

  /// ✅ FIX: Aba de pagamento na entrega usando a estrutura real do Admin (Grupo > Flags)
  Widget _buildOfflinePaymentTab() {
    // ✅ SEPARAÇÃO DE VALES: Divide grupos de Vales em Refeição e Alimentação
    final List<PaymentMethodGroup> expandedGroups = [];
    for (final group in offlineGroups) {
      final nameStr = (group.title ?? group.name).toLowerCase();

      if (nameStr.contains('vale') ||
          nameStr.contains('benefício') ||
          nameStr.contains('beneficio')) {
        final vrList = <PlatformPaymentMethod>[];
        final vaList = <PlatformPaymentMethod>[];

        for (final m in group.methods) {
          final n = m.name.toLowerCase();
          final ik = (m.iconKey ?? '').toLowerCase();

          // Detecção de VR (Refeição)
          if (n.contains('refeição') ||
              n.contains('refeicao') ||
              n.contains(' meal') ||
              n.contains('vr') ||
              ik.contains('vr')) {
            vrList.add(m);
          }
          // Detecção de VA (Alimentação)
          else if (n.contains('alimentação') ||
              n.contains('alimentacao') ||
              n.contains(' food') ||
              n.contains('va') ||
              ik.contains('va') ||
              ik.contains('alelo') ||
              ik.contains('sodexo') ||
              ik.contains('ticket')) {
            vaList.add(m);
          }
          // Fallback: Se não detectou nada, joga no grupo que fizer mais sentido ou no Alimentação se for Sodexo/Alelo genérico
          else {
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

    // 1. Ordena os grupos pela prioridade solicitada (Dinheiro primeiro, Pix depois...)
    final sortedGroups = List<PaymentMethodGroup>.from(expandedGroups);
    sortedGroups.sort((a, b) {
      final nameA = a.title ?? a.name;
      final nameB = b.title ?? b.name;
      return _getGroupPriority(nameA).compareTo(_getGroupPriority(nameB));
    });

    final widgets = <Widget>[];

    for (final group in sortedGroups) {
      final String groupTitle = group.title ?? group.name;
      if (groupTitle.isEmpty) continue;

      // Filtra os métodos ativos deste grupo
      final methods =
          group.methods.where((m) => m.activation?.isActive == true).toList();
      if (methods.isEmpty) continue;

      // Adiciona o Cabeçalho do Grupo (Seção)
      String effectiveTitle = groupTitle;
      final etLower = effectiveTitle.toLowerCase();
      if (etLower.contains('crédito') || etLower.contains('credito')) {
        effectiveTitle = 'Crédito';
      } else if (etLower.contains('débito') || etLower.contains('debito')) {
        effectiveTitle = 'Débito';
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
          child: Text(
            effectiveTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -0.4,
            ),
          ),
        ),
      );

      // Adiciona as "Flags" (métodos filhos) dentro deste grupo
      for (final m in methods) {
        final nameLower = m.name.toLowerCase();

        // Validação de Chave PIX
        if (nameLower == 'pix') {
          final pixKey = m.activation?.details?['pix_key'];
          if (pixKey == null || pixKey.toString().isEmpty) continue;
        }

        // Limpa redundâncias no nome da flag
        String displayName = _formatFlagName(m.name, groupTitle);

        widgets.add(_buildPaymentMethodCard(m, displayName: displayName));
      }
    }

    if (widgets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Nenhuma forma de pagamento disponível para este tipo de pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: widgets,
    );
  }

  /// Formata o nome da flag para evitar redundância com o título da seção
  String _formatFlagName(String methodName, String groupTitle) {
    final title = groupTitle.toLowerCase();

    // Se for Dinheiro ou Pix, mantém o nome original
    if (title.contains('dinheiro') || title.contains('pix')) return methodName;

    final regex = RegExp(
      r'crédito|credito|débito|debito|vale|alimentação|alimentacao|refeição|refeicao|voucher',
      caseSensitive: false,
    );

    String cleaned = methodName.replaceAll(regex, '').trim();
    return cleaned.isEmpty ? methodName : cleaned;
  }

  /// Helper para definir a ordem dos grupos conforme o padrão do Admin/iFood
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

  /// ✅ NOVO: Item de pagamento estilo card premium
  Widget _buildPaymentMethodCard(
    PlatformPaymentMethod method, {
    String? displayName,
  }) {
    // Consideramos selecionado se ID e Nome batem
    bool isSelected =
        _selectedMethod?.id == method.id &&
        _selectedMethod?.name == method.name;

    // Usa displayName se fornecido, senão usa method.name
    final String label = displayName ?? method.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.black : const Color(0xFFF2F2F2),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Ícone lateral
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPaymentIcon(method.iconKey),
              ),
              const SizedBox(width: 16),
              // Nome do método
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3F3E3E),
                  ),
                ),
              ),
              // Radio customizado estilo iFood
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.black : const Color(0xFFF2F2F2),
                  border:
                      isSelected
                          ? null
                          : Border.all(
                            color: const Color(0xFFE8E8E8),
                            width: 1,
                          ),
                ),
                child:
                    isSelected
                        ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Os itens são agora construídos via _buildPaymentMethodCard para layout flat

  Widget _buildPaymentIcon(String? iconKey) {
    if (iconKey != null && iconKey.isNotEmpty) {
      // ✅ Mapeamento de iconKeys para arquivos reais
      final String mappedIconKey = _mapIconKey(iconKey);
      final String assetPath = 'assets/icons/$mappedIconKey';

      return SizedBox(
        width: 24,
        height: 24,
        child: _SafeSvgPicture(
          assetPath: assetPath,
          fallback: const Icon(Icons.credit_card, size: 24),
        ),
      );
    }
    return const Icon(Icons.payment, size: 24);
  }

  // ✅ Mapeia iconKeys do backend para arquivos de ícones existentes
  String _mapIconKey(String iconKey) {
    // Remove extensão se houver
    final cleanKey = iconKey.replaceAll('.svg', '').toLowerCase();

    // Mapeamento de iconKeys comuns para arquivos reais
    final iconMap = {
      'credit': 'visa', // Fallback genérico para crédito
      'debit': 'visa_debit', // Fallback genérico para débito
      'hiper': 'hipercard',
      'hipercard': 'hipercard',
      'master': 'mastercard',
      'mastercard': 'mastercard',
      'visa': 'visa',
      'elo': 'elo',
      'amex': 'amex',
      'american_express': 'amex',
      'pix': 'pix',
      'cash': 'cash',
      'dinheiro': 'cash',
      'sodexo': 'sodexo',
      'alelo': 'alelo',
      'ticket': 'ticket',
      'vr': 'vr',
      'diners': 'diners',
      'discover': 'discover',
      'va': 'ticket', // Vale alimentação -> Ticket como fallback
      'vr_refeicao': 'vr',
    };

    // Se existe mapeamento, usa ele
    if (iconMap.containsKey(cleanKey)) {
      return '${iconMap[cleanKey]}.svg';
    }

    // Se não tem extensão, adiciona .svg
    if (!cleanKey.endsWith('.svg')) {
      return '$cleanKey.svg';
    }

    return iconKey; // Retorna original se já tiver extensão
  }
}

// ✅ Widget helper para carregar SVG com tratamento de erro
class _SafeSvgPicture extends StatelessWidget {
  final String assetPath;
  final Widget fallback;

  const _SafeSvgPicture({required this.assetPath, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      placeholderBuilder: (context) => fallback,
      // ✅ Se o asset não existir, o placeholder será usado
    );
  }
}
