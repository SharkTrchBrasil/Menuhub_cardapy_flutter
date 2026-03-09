// Em: lib/pages/checkout/desktop_checkout_page.dart
// ✅ NOVO: Checkout unificado para Desktop - tudo em uma tela

import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/helpers/payment_method.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';
import 'package:totem/pages/checkout/widgets/phone_collection_bottom_sheet.dart'
    show showPhoneCollectionDialog;
import '../../core/di.dart';
import '../../core/utils/app_logger.dart';
import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../models/delivery_type.dart';
import '../../repositories/customer_repository.dart';
import '../cart/cart_state.dart';
import '../../widgets/address_selection_dialog.dart';

/// Desktop Checkout Page - Layout unificado com duas colunas
/// Esquerda: Endereço + Pagamento
/// Direita: Resumo do Carrinho
class DesktopCheckoutPage extends StatelessWidget {
  const DesktopCheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final addressState = context.read<AddressCubit>().state;
    final cart = context.read<CartCubit>().state.cart;
    final deliveryFeeCubit = context.read<DeliveryFeeCubit>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      deliveryFeeCubit.calculate(
        address: addressState.selectedAddress,
        store: store,
        cartSubtotal: cart.subtotal / 100.0,
      );
    });

    return BlocProvider(
      create: (context) {
        final cubit = CheckoutCubit(
          realtimeRepository: getIt(),
          customerRepository: getIt<CustomerRepository>(),
        );
        final currentDeliveryType = deliveryFeeCubit.state.deliveryType;
        cubit.initialize(store, deliveryType: currentDeliveryType);
        return cubit;
      },
      child: const _DesktopCheckoutView(),
    );
  }
}

class _DesktopCheckoutView extends StatefulWidget {
  const _DesktopCheckoutView();

  @override
  State<_DesktopCheckoutView> createState() => _DesktopCheckoutViewState();
}

class _DesktopCheckoutViewState extends State<_DesktopCheckoutView> {
  int _deliveryTabIndex = 0;
  int _paymentTabIndex = 0;
  final _cpfController = TextEditingController();
  final _observationController = TextEditingController();

  @override
  void dispose() {
    _cpfController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return BlocListener<DeliveryFeeCubit, DeliveryFeeState>(
      listener: (context, feeState) {
        if (store != null && feeState.deliveryType != null) {
          context.read<CheckoutCubit>().updateForDeliveryType(
            store,
            feeState.deliveryType!,
          );
          // Atualiza tab de entrega/retirada
          setState(() {
            _deliveryTabIndex =
                feeState.deliveryType == DeliveryType.pickup ? 1 : 0;
          });
        }
      },
      child: BlocListener<CheckoutCubit, CheckoutState>(
        listenWhen:
            (previous, current) =>
                previous.status != current.status ||
                previous.selectedPaymentMethod != current.selectedPaymentMethod,
        listener: (context, state) {
          if (state.status == CheckoutStatus.success) {
            // ✅ VALIDAÇÃO: Verifica se finalOrder não é null antes de navegar
            if (state.finalOrder != null) {
              context.read<CartCubit>().clearCart().then((_) {
                context.go(
                  '/success',
                  extra: {
                    'order': state.finalOrder!,
                    'paymentMethod': state.selectedPaymentMethod,
                  },
                );
              });
            } else {
              AppLogger.error(
                '❌ [CHECKOUT] finalOrder é null ao tentar navegar para sucesso',
                tag: 'CHECKOUT',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pedido criado, mas houve um erro ao exibir os detalhes.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          if (state.status == CheckoutStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? "Ocorreu um erro."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Finalize seu pedido',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 24,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna Esquerda - Pagamento e Endereço
                    Expanded(
                      flex: 2,
                      child: _buildPaymentSection(context, primaryColor),
                    ),
                    const SizedBox(width: 24),
                    // Coluna Direita - Carrinho
                    SizedBox(
                      width: 420,
                      child: _buildCartSection(context, primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context, Color primaryColor) {
    final store = context.read<StoreCubit>().state.store!;
    final addressState = context.watch<AddressCubit>().state;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finalize seu pedido',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 24),

          // Tabs de Entrega/Retirada
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildDeliveryTab(context, 0, 'Entrega', primaryColor),
                _buildDeliveryTab(context, 1, 'Retirada', primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Endereço de entrega/retirada
          if (_deliveryTabIndex == 0)
            addressState.selectedAddress != null
                ? _buildAddressCard(context, primaryColor)
                : _buildNoAddressCard(context, primaryColor)
          else if (_deliveryTabIndex == 1)
            _buildPickupCard(context, store, primaryColor),

          const SizedBox(height: 20),

          // Método de entrega (somente se tiver endereço selecionado para delivery)
          if (_deliveryTabIndex == 0 && addressState.selectedAddress != null)
            _buildDeliveryMethod(context, store, primaryColor),

          const SizedBox(height: 30),

          // Tabs de Pagamento
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildPaymentTab(context, 0, 'Pague pelo site', primaryColor),
                _buildPaymentTab(context, 1, 'Pague na entrega', primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Métodos de pagamento
          _buildPaymentMethods(context, primaryColor),

          const SizedBox(height: 30),

          // Observações
          TextField(
            controller: _observationController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Observações do pedido',
              hintText: 'Ex: tirar a cebola, ponto da carne, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged:
                (text) => context.read<CheckoutCubit>().setObservation(text),
          ),

          // CPF/CNPJ na nota
          if (store.fiscalActive) ...[
            TextField(
              controller: _cpfController,
              decoration: InputDecoration(
                labelText: 'CPF/CNPJ na nota (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfOuCnpjFormatter(),
              ],
            ),
            const SizedBox(height: 30),
          ],

          // Botão Fazer Pedido
          _buildSubmitButton(context, primaryColor),
        ],
      ),
    );
  }

  Widget _buildDeliveryTab(
    BuildContext context,
    int index,
    String label,
    Color primaryColor,
  ) {
    final bool isSelected = _deliveryTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _deliveryTabIndex = index;
          });
          // Atualiza o tipo de entrega
          final deliveryType =
              index == 0 ? DeliveryType.delivery : DeliveryType.pickup;
          context.read<DeliveryFeeCubit>().updateDeliveryType(deliveryType);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab(
    BuildContext context,
    int index,
    String label,
    Color primaryColor,
  ) {
    final bool isSelected = _paymentTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _paymentTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, Color primaryColor) {
    final addressState = context.watch<AddressCubit>().state;
    final address = addressState.selectedAddress;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddressDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${address?.street ?? ""}, ${address?.number ?? ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (address?.complement != null &&
                          address!.complement!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address.complement!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${address?.neighborhood ?? ""} - ${address?.city ?? ""}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddressDialog(context),
                  child: Text(
                    'Trocar',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card para quando não há endereço selecionado
  Widget _buildNoAddressCard(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddressDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nenhum endereço selecionado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toque para escolher ou cadastrar',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddressDialog(context),
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: const Text('Selecionar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Abre dialog de seleção de endereço (igual ao da appbar)
  void _showAddressDialog(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final customer = authState.customer;

    // Se não está logado, redireciona para onboarding
    if (customer?.id == null) {
      context.push('/onboarding');
      return;
    }

    final addressCubit = context.read<AddressCubit>();

    // Garante que os endereços estão carregados
    if (addressCubit.state.status == AddressStatus.initial) {
      addressCubit.loadAddresses(customer!.id!);
    }

    showDialog(
      context: context,
      builder:
          (_) => BlocProvider.value(
            value: addressCubit,
            child: const AddressSelectionDialog(),
          ),
    );
  }

  Widget _buildPickupCard(
    BuildContext context,
    dynamic store,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.store, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Retirar em',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.name ?? 'Loja',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (store.street != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${store.street}${store.number != null ? ", ${store.number}" : ""}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMethod(
    BuildContext context,
    dynamic store,
    Color primaryColor,
  ) {
    final feeState = context.watch<DeliveryFeeCubit>().state;
    final minTime = store.store_operation_config?.deliveryEstimatedMin ?? 30;
    final maxTime = store.store_operation_config?.deliveryEstimatedMax ?? 60;

    double deliveryFee = 0.0;
    String deliveryFeeText = 'Grátis';
    if (feeState is DeliveryFeeLoaded) {
      deliveryFee = feeState.deliveryFee;
      deliveryFeeText =
          deliveryFee > 0 ? UtilBrasilFields.obterReal(deliveryFee) : 'Grátis';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoje, $minTime-$maxTime min',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Padrão',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoje, $minTime-$maxTime min',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Text(
                  deliveryFeeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: deliveryFee > 0 ? Colors.black87 : primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods(BuildContext context, Color primaryColor) {
    final store = context.read<StoreCubit>().state.store!;
    final checkoutState = context.watch<CheckoutCubit>().state;
    final feeState = context.watch<DeliveryFeeCubit>().state;

    final allPaymentGroups = store.paymentMethodGroups;
    final availablePaymentGroups = allPaymentGroups.filterFor(
      feeState.deliveryType,
    );

    // ✅ SEPARAÇÃO DE VALES: Divide grupos de Vales em Refeição e Alimentação
    final List<PaymentMethodGroup> expandedGroups = [];
    for (final group in availablePaymentGroups) {
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

    final isOnline = _paymentTabIndex == 0;
    final widgets = <Widget>[];

    for (final group in sortedGroups) {
      String groupTitle = group.title ?? group.name;

      // ✅ SIMPLIFICAÇÃO: "Cartão de crédito" -> "Crédito"
      if (groupTitle.toLowerCase().contains('crédito') ||
          groupTitle.toLowerCase().contains('credito')) {
        groupTitle = 'Crédito';
      }

      // Filtra métodos deste grupo baseados no tab (online ou na entrega)
      final filteredMethods =
          group.methods.where((m) {
            if (isOnline) {
              return m.method_type == 'ONLINE' ||
                  (m.activation?.details?['is_online'] == true);
            } else {
              return m.method_type != 'ONLINE' &&
                  (m.activation?.details?['is_online'] != true);
            }
          }).toList();

      if (filteredMethods.isEmpty) continue;

      // Cabeçalho do Grupo
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
          child: Text(
            groupTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );

      // Métodos do grupo
      for (final method in filteredMethods) {
        final isSelected = checkoutState.selectedPaymentMethod?.id == method.id;
        final String displayName = _formatFlagName(method.name, groupTitle);

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey[200]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  context.read<CheckoutCubit>().updatePaymentMethod(method);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildPaymentIcon(method.iconKey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.credit_card_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isOnline
                  ? 'Pagamento online não disponível'
                  : 'Nenhum método de pagamento na entrega disponível',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
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
        t.contains('beneficio'))
      return 7;
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
      final assetPath = 'assets/icons/$cleanKey.svg';

      return SizedBox(
        width: 40,
        height: 40,
        child: SvgPicture.asset(
          assetPath,
          placeholderBuilder:
              (context) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.payment, color: Colors.grey),
              ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.payment, color: Colors.grey),
    );
  }

  Widget _buildCartSection(BuildContext context, Color primaryColor) {
    final store = context.watch<StoreCubit>().state.store;
    final cartState = context.watch<CartCubit>().state;
    final feeState = context.watch<DeliveryFeeCubit>().state;
    final couponCode = cartState.cart.couponCode;

    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded &&
        feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }

    final subtotal = cartState.cart.subtotal / 100.0;
    final discount = cartState.cart.discount / 100.0;
    final total = (cartState.cart.total / 100.0) + deliveryFee;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu pedido em',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  store?.name ?? 'Loja',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    'Ver Cardápio',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de itens
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...cartState.cart.items.map(
                  (item) => _buildCartItem(context, item, primaryColor),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Cupom
          if (couponCode != null && couponCode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cupom $couponCode aplicado',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Totais
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F7),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              children: [
                _buildTotalRow(
                  'Subtotal',
                  UtilBrasilFields.obterReal(subtotal),
                ),
                const SizedBox(height: 8),
                if (discount > 0) ...[
                  _buildTotalRow(
                    'Desconto',
                    '-${UtilBrasilFields.obterReal(discount)}',
                    isDiscount: true,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildTotalRow(
                  'Taxa de entrega',
                  deliveryFee > 0
                      ? UtilBrasilFields.obterReal(deliveryFee)
                      : 'Grátis',
                ),
                const SizedBox(height: 16),
                _buildTotalRow(
                  'Total',
                  UtilBrasilFields.obterReal(total),
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    dynamic item,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}x ${item.product.name}',
                  style: const TextStyle(fontSize: 15),
                ),
                if (item.sizeName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.sizeName!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
                // Variantes/Complementos
                if (item.variants.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...item.variants.map<Widget>((variant) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...variant.options.map<Widget>((option) {
                          return Text(
                            '• ${option.name}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ],
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Obs: ${item.note}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            UtilBrasilFields.obterReal(item.totalPrice / 100.0),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.black : Colors.grey[600],
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                isDiscount
                    ? Colors.green
                    : (isTotal ? Colors.black : Colors.black),
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, Color primaryColor) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, checkoutState) {
        final isLoading = checkoutState.status == CheckoutStatus.loading;
        final hasPaymentMethod = checkoutState.selectedPaymentMethod != null;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isLoading || !hasPaymentMethod
                    ? null
                    : () => _submitOrder(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Fazer pedido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        );
      },
    );
  }

  Future<void> _submitOrder(BuildContext context) async {
    AppLogger.info(
      '🖱️ [CHECKOUT] Botão "Fazer pedido" clicado',
      tag: 'CHECKOUT',
    );
    final authState = context.read<AuthCubit>().state;
    final customer = authState.customer;

    // Verifica se tem telefone
    final needsPhone =
        customer?.phone == null || (customer?.phone?.isEmpty ?? true);
    AppLogger.debug(
      '📞 [CHECKOUT] Precisa de telefone: $needsPhone',
      tag: 'CHECKOUT',
    );

    if (needsPhone) {
      // ✅ CORREÇÃO: Usa showPhoneCollectionDialog que detecta desktop/mobile automaticamente
      AppLogger.info(
        '📞 [CHECKOUT] Coletando telefone do cliente...',
        tag: 'CHECKOUT',
      );
      final phone = await showPhoneCollectionDialog(
        context,
        initialPhone: customer?.phone,
      );

      if (phone == null || phone.isEmpty) {
        AppLogger.warning(
          '📞 [CHECKOUT] Telefone não informado - pedido cancelado',
          tag: 'CHECKOUT',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'É necessário informar um telefone para finalizar o pedido.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ Salva telefone no backend
      if (customer != null && customer.id != null) {
        AppLogger.info(
          '💾 [CHECKOUT] Salvando telefone no backend: $phone',
          tag: 'CHECKOUT',
        );
        try {
          final customerRepo = getIt<CustomerRepository>();
          final result = await customerRepo.updateCustomerInfo(
            customer.id!,
            customer.name ?? '',
            phone,
            email: customer.email,
          );

          if (result.isRight && context.mounted) {
            final updatedCustomer = result.right;
            context.read<AuthCubit>().updateCustomer(updatedCustomer);
            AppLogger.success(
              '✅ [CHECKOUT] Telefone salvo com sucesso: ${updatedCustomer.phone}',
              tag: 'CHECKOUT',
            );
          } else if (context.mounted) {
            AppLogger.error(
              '❌ [CHECKOUT] Erro ao salvar telefone: ${result.left}',
              tag: 'CHECKOUT',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erro ao salvar telefone: ${result.left ?? "Erro desconhecido"}',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } catch (e) {
          AppLogger.error(
            '❌ [CHECKOUT] Erro inesperado ao salvar telefone: $e',
            tag: 'CHECKOUT',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao salvar telefone. Tente novamente.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        AppLogger.warning(
          '⚠️ [CHECKOUT] Cliente não encontrado - não foi possível salvar telefone',
          tag: 'CHECKOUT',
        );
      }
    }

    // Envia pedido
    if (context.mounted) {
      AppLogger.info(
        '📦 [CHECKOUT] Preparando para enviar pedido...',
        tag: 'CHECKOUT',
      );
      final authState = context.read<AuthCubit>().state;
      final cartState = context.read<CartCubit>().state;
      final addressState = context.read<AddressCubit>().state;
      final feeState = context.read<DeliveryFeeCubit>().state;
      final store = context.read<StoreCubit>().state.store;

      AppLogger.debug('🔍 [CHECKOUT] Estados obtidos:', tag: 'CHECKOUT');
      AppLogger.debug(
        '   ├─ customer: ${authState.customer?.name}',
        tag: 'CHECKOUT',
      );
      AppLogger.debug(
        '   ├─ cart.items: ${cartState.cart.items.length}',
        tag: 'CHECKOUT',
      );
      AppLogger.debug(
        '   ├─ address: ${addressState.selectedAddress?.id}',
        tag: 'CHECKOUT',
      );
      AppLogger.debug(
        '   ├─ deliveryType: ${feeState.deliveryType?.name}',
        tag: 'CHECKOUT',
      );
      AppLogger.debug('   └─ store: ${store?.name}', tag: 'CHECKOUT');

      AppLogger.info('🚀 [CHECKOUT] Chamando placeOrder()...', tag: 'CHECKOUT');
      context.read<CheckoutCubit>().placeOrder(
        authState: authState,
        cartState: cartState,
        addressState: addressState,
        feeState: feeState,
        store: store,
      );
      AppLogger.info(
        '✅ [CHECKOUT] placeOrder() chamado com sucesso',
        tag: 'CHECKOUT',
      );
    } else {
      AppLogger.warning(
        '⚠️ [CHECKOUT] Context não está montado, não é possível enviar pedido',
        tag: 'CHECKOUT',
      );
    }
  }
}
