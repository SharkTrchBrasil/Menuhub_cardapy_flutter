// Em: lib/pages/checkout/checkout_page.dart
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem/helpers/payment_method.dart';
import 'package:totem/models/payment_method.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';
// Removed import checkou_summary_card.dart
import 'package:totem/pages/checkout/widgets/payment_methods.dart';
import 'package:totem/themes/ds_theme_switcher.dart'; // ✅ Theme
import 'package:totem/widgets/unified_cart_bottom_bar.dart'; // ✅ Unified Bar
import 'package:totem/pages/checkout/widgets/phone_collection_bottom_sheet.dart'
    show showPhoneCollectionDialog;
import 'package:totem/widgets/dot_loading.dart';
import 'package:totem/widgets/order_summary_card.dart'; // Added import
import '../../core/di.dart';
import '../../core/utils/app_logger.dart';
import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../../cubit/catalog_cubit.dart';
import '../../models/delivery_type.dart';
import '../../models/store.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/store_header_card.dart';
import '../../widgets/store_closed_widgets.dart';
import '../../services/store_status_service.dart';
import '../cart/cart_state.dart';
import '../cart/widgets/recommended_products.dart';
import '../../services/product_recommendation_service.dart';
import '../../models/update_cart_payload.dart';
import '../../models/product.dart';
import '../../models/cart.dart'; // ✅ Para usar Cart no _CheckoutInitializer
import '../../core/utils/id_obfuscator.dart'; // ✅ ENTERPRISE: Ofuscação de IDs

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  // ✅ CORREÇÃO: Flag estática para evitar múltiplas inicializações
  static bool _hasInitialized = false;

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    if (store == null) return const Scaffold(body: Center(child: DotLoading()));

    final addressState = context.read<AddressCubit>().state;
    final cart = context.read<CartCubit>().state.cart;
    final feeState = context.read<DeliveryFeeCubit>().state;

    final deliveryFeeCubit = context.read<DeliveryFeeCubit>();

    // ✅ CORREÇÃO: Usa BlocListener para calcular frete apenas quando necessário
    // Evita loop infinito calculando apenas quando endereço ou carrinho mudam
    return BlocListener<AddressCubit, AddressState>(
      listenWhen:
          (previous, current) =>
              previous.selectedAddress?.id != current.selectedAddress?.id,
      listener: (context, addressState) {
        // ✅ Recalcula apenas quando o endereço muda
        if (addressState.selectedAddress != null) {
          final currentCart = context.read<CartCubit>().state.cart;
          deliveryFeeCubit.calculate(
            address: addressState.selectedAddress,
            store: store,
            cartSubtotal: currentCart.subtotal / 100.0,
          );
        }
      },
      child: BlocListener<CartCubit, CartState>(
        listenWhen:
            (previous, current) =>
                previous.cart.subtotal != current.cart.subtotal,
        listener: (context, cartState) {
          // ✅ Recalcula apenas quando o subtotal do carrinho muda
          final currentFeeState = context.read<DeliveryFeeCubit>().state;
          final currentAddress =
              context.read<AddressCubit>().state.selectedAddress;
          if (currentFeeState is! DeliveryFeeLoading &&
              currentAddress != null) {
            deliveryFeeCubit.calculate(
              address: currentAddress,
              store: store,
              cartSubtotal: cartState.cart.subtotal / 100.0,
            );
          }
        },
        child: BlocProvider(
          create: (context) {
            final cubit = CheckoutCubit(
              realtimeRepository: getIt(),
              customerRepository: getIt<CustomerRepository>(),
            );
            final currentDeliveryType = deliveryFeeCubit.state.deliveryType;
            cubit.initialize(store, deliveryType: currentDeliveryType);
            return cubit;
          },
          child: _CheckoutInitializer(
            store: store,
            addressState: addressState,
            cart: cart,
            deliveryFeeCubit: deliveryFeeCubit,
          ),
        ),
      ),
    );
  }
}

// ✅ CORREÇÃO: Widget stateful para calcular frete apenas uma vez na inicialização
class _CheckoutInitializer extends StatefulWidget {
  final Store store;
  final AddressState addressState;
  final Cart cart;
  final DeliveryFeeCubit deliveryFeeCubit;

  const _CheckoutInitializer({
    required this.store,
    required this.addressState,
    required this.cart,
    required this.deliveryFeeCubit,
  });

  @override
  State<_CheckoutInitializer> createState() => _CheckoutInitializerState();
}

class _CheckoutInitializerState extends State<_CheckoutInitializer> {
  bool _hasCalculated = false;

  @override
  void initState() {
    super.initState();
    // ✅ Calcula apenas uma vez na inicialização, se necessário
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCalculated && mounted) {
        final currentState = widget.deliveryFeeCubit.state;
        final currentAddress = widget.addressState.selectedAddress;
        // ✅ Só calcula se ainda não foi calculado ou se está em estado inicial/erro
        if ((currentState is DeliveryFeeInitial ||
                currentState is DeliveryFeeError ||
                (currentState is DeliveryFeeRequiresAddress &&
                    currentAddress != null)) &&
            currentAddress != null) {
          widget.deliveryFeeCubit.calculate(
            address: currentAddress,
            store: widget.store,
            cartSubtotal: widget.cart.subtotal / 100.0,
          );
          _hasCalculated = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const CheckoutView();
  }
}

class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key});

  // ✅ NOVO: Flag para evitar que o bottom sheet do troco abra múltiplas vezes
  static bool _isChangeSheetOpen = false;

  Future<void> _showChangeNeededSheet(BuildContext context) async {
    // ✅ CORREÇÃO: Previne que abra múltiplas vezes
    if (_isChangeSheetOpen) return;

    final cartState = context.read<CartCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;

    // ✅ CORREÇÃO APLICADA AQUI
    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded &&
        feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    _isChangeSheetOpen = true;
    final value = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ✅ CORREÇÃO: Remove fundo cinza
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: _ChangeNeededBottomSheet(grandTotal: grandTotal),
          ),
    );

    _isChangeSheetOpen = false;
    if (value != null) {
      context.read<CheckoutCubit>().updateChange(value);
    }
  }

  // ✅ NOVO: Bottom sheet para coletar telefone (mobile) ou dialog (desktop)
  void _showPhoneCollectionSheet(BuildContext context, String? currentPhone) {
    showPhoneCollectionDialog(context, initialPhone: currentPhone);
  }

  String _getPaymentGroupTitle(PlatformPaymentMethod method) {
    switch (method.method_type) {
      case 'ONLINE':
        return 'Pagamento pelo app';
      case 'CASH':
      case 'CARD_MACHINE':
        return 'Pagamento na entrega';
      default:
        return 'Forma de pagamento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;

    return BlocListener<DeliveryFeeCubit, DeliveryFeeState>(
      listener: (context, feeState) {
        // ✅ Atualiza métodos de pagamento quando tipo de entrega muda
        if (store != null && feeState.deliveryType != null) {
          context.read<CheckoutCubit>().updateForDeliveryType(
            store,
            feeState.deliveryType!,
          );
        }
      },
      child: BlocListener<CheckoutCubit, CheckoutState>(
        listenWhen:
            (previous, current) =>
                previous.status != current.status ||
                previous.selectedPaymentMethod != current.selectedPaymentMethod,
        listener: (context, state) {
          // ✅ NOTA: A navegação para success agora é tratada pela OrderSubmissionPage
          // Este listener aqui é apenas para fallback em casos edge (ex: usuário não está na tela de submissão)
          if (state.status == CheckoutStatus.success) {
            // Não faz nada aqui - a OrderSubmissionPage cuida da navegação
            AppLogger.debug(
              '✅ [CHECKOUT] Status success recebido no checkout_page (ignorado - OrderSubmissionPage cuida)',
              tag: 'CHECKOUT',
            );
          }
          if (state.status == CheckoutStatus.error) {
            // ✅ Mostra erro apenas se NÃO estiver na tela de submissão
            // A OrderSubmissionPage tem seu próprio tratamento de erro
            final currentRoute = GoRouterState.of(context).matchedLocation;
            if (!currentRoute.contains('submitting')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? "Ocorreu um erro."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
          // ✅ CORREÇÃO: REMOVIDO - O auto-popup do troco era intrusivo
          // O usuário configura o troco clicando em "Precisa de troco?" na seção de pagamento
          // Se não configurou, será validado ao clicar em "Revisar pedido"
        },
        child: Builder(
          // ✅ Builder para acessar tema
          builder: (context) {
            final theme = context.watch<DsThemeSwitcher>().theme;
            return Scaffold(
              backgroundColor: theme.cartBackgroundColor, // Fundo consistente
              appBar: AppBar(
                title: Text(
                  'FINALIZAR PEDIDO',
                  style: theme.headingTextStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.cartTextColor,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: theme.cartBackgroundColor,
                iconTheme: IconThemeData(color: theme.cartTextColor),
                leading: IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_left,
                    color: Colors.black,
                  ),
                  onPressed: () => context.go('/address'),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreHeaderCard(
                      showAddItemsButton: true,
                      onAddItemsPressed: () => context.go('/'),
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<CheckoutCubit, CheckoutState>(
                      buildWhen:
                          (previous, current) =>
                              previous.selectedPaymentMethod !=
                              current.selectedPaymentMethod,
                      builder: (context, state) {
                        // ✅ CORREÇÃO: Mostra mensagem informativa se não há métodos disponíveis
                        if (state.selectedPaymentMethod == null) {
                          final hasPaymentGroups =
                              store?.paymentMethodGroups.isNotEmpty ?? false;
                          if (hasPaymentGroups) {
                            // Se tem grupos mas nenhum método foi selecionado, mostra placeholder
                            return const _PaymentSectionPlaceholder();
                          } else {
                            // Se não tem grupos de pagamento, mostra erro
                            return Card(
                              color: Colors.orange.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      color: Colors.orange.shade700,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nenhuma forma de pagamento disponível',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Entre em contato com a loja para mais informações.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                        final paymentTitle = _getPaymentGroupTitle(
                          state.selectedPaymentMethod!,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(paymentTitle),
                            _PaymentMethodSummary(
                              onShowChangeSheet:
                                  () => _showChangeNeededSheet(context),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    BlocBuilder<CheckoutCubit, CheckoutState>(
                      buildWhen:
                          (previous, current) =>
                              previous.selectedPaymentMethod !=
                              current.selectedPaymentMethod,
                      builder: (context, state) {
                        return OrderSummaryCard(
                          paymentMethod: state.selectedPaymentMethod,
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // ✅ Upsell removido para limpar checkout
                    // const _CheckoutUpsellSection(),
                    // const SizedBox(height: 32),

                    // ✅ Seção CPF na Nota
                    const _FiscalCpfSection(),
                    const SizedBox(height: 32),
                    // const _CheckoutUpsellSection(),
                    // const SizedBox(height: 32),
                    const _ScheduleOrderSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Observações do Pedido'),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText:
                            'Ex: Campainha não funciona, deixar na portaria, etc.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          (text) => context
                              .read<CheckoutCubit>()
                              .setObservation(text),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              // ✅ Bottom Bar Unificado
              bottomNavigationBar: const _UnifiedCheckoutBottomBarWrapper(),
            );
          },
        ), // Builder
      ), // BlocListener (Checkout)
    ); // BlocListener (DeliveryFee)
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ... Os outros widgets auxiliares (_PaymentSectionPlaceholder, _PaymentMethodSummary, etc.) permanecem os mesmos.
// O único que precisava de correção era o CheckoutBottomBar, que foi corrigido no arquivo `bottomBar.dart`.
// Vou incluir os outros aqui para manter o arquivo completo.

class _PaymentSectionPlaceholder extends StatelessWidget {
  const _PaymentSectionPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 20,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSummary extends StatelessWidget {
  final VoidCallback onShowChangeSheet;
  const _PaymentMethodSummary({required this.onShowChangeSheet});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        if (state.selectedPaymentMethod == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final method = state.selectedPaymentMethod!;
        final isCash = method.method_type == 'CASH';
        final deliveryType =
            context.read<DeliveryFeeCubit>().state.deliveryType;
        final store = context.read<StoreCubit>().state.store!;
        final availablePaymentGroups = store.paymentMethodGroups.filterFor(
          deliveryType,
        );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7), // Cinza claro de fundo
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Conteúdo do Pagamento em Card Branco
              InkWell(
                onTap: () async {
                  final cartState = context.read<CartCubit>().state;
                  final feeState = context.read<DeliveryFeeCubit>().state;

                  double deliveryFee = 0.0;
                  if (feeState is DeliveryFeeLoaded &&
                      feeState.deliveryType == DeliveryType.delivery) {
                    deliveryFee = feeState.deliveryFee;
                  }

                  final orderTotal =
                      (cartState.cart.total / 100.0) + deliveryFee;

                  final selected = await Navigator.push<PlatformPaymentMethod>(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PaymentMethodSelectionList(
                            paymentGroups: availablePaymentGroups,
                            initialSelectedMethod: method,
                            orderTotal: orderTotal,
                            store: store,
                          ),
                    ),
                  );
                  if (selected != null) {
                    context.read<CheckoutCubit>().updatePaymentMethod(selected);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      _buildPaymentIcon(method.iconKey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF3E3E3E),
                              ),
                            ),
                            if (isCash)
                              GestureDetector(
                                onTap: onShowChangeSheet,
                                child: Text(
                                  state.changeFor == null ||
                                          state.changeFor == 0
                                      ? 'Sem troco'
                                      : 'Troco para ${UtilBrasilFields.obterReal(state.changeFor!)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_right,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

class _ChangeNeededBottomSheet extends StatefulWidget {
  final double grandTotal;
  const _ChangeNeededBottomSheet({required this.grandTotal});

  @override
  State<_ChangeNeededBottomSheet> createState() =>
      _ChangeNeededBottomSheetState();
}

class _ChangeNeededBottomSheetState extends State<_ChangeNeededBottomSheet> {
  final _controller = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ✅ CORREÇÃO: Container branco explícito para evitar fundo cinza
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Precisa de troco?',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informe o valor em dinheiro que você vai pagar para que o entregador leve o troco.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CentavosInputFormatter(),
            ],
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _errorMessage,
            ),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ao receber seu pedido, não esqueça de conferir o troco.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () {
              final enteredAmount = UtilBrasilFields.converterMoedaParaDouble(
                _controller.text,
              );
              if (enteredAmount <= widget.grandTotal) {
                setState(
                  () =>
                      _errorMessage =
                          'O valor para troco deve ser maior que o total.',
                );
                return;
              }
              Navigator.pop(context, enteredAmount);
            },
            child: const Text(
              'Confirmar valor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text(
              'Não preciso de troco',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _UnifiedCheckoutBottomBarWrapper extends StatelessWidget {
  const _UnifiedCheckoutBottomBarWrapper();

  static bool _isChangeSheetOpen = false;
  static bool _isConfirmationSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    // ✅ Wrapper para o UnifiedCartBottomBar no Checkout
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, checkoutState) {
        return UnifiedCartBottomBar(
          variant: CartBottomBarVariant.checkout,
          overrideButtonLabel: 'Revisar pedido', // Texto customizado
          onContinuePressed: () {
            // ✅ Lógica de validação de troco + Confirmação
            final method = checkoutState.selectedPaymentMethod;
            final isCash = method?.method_type == 'CASH';
            final needsChangeConfig = isCash && checkoutState.changeFor == null;

            if (needsChangeConfig) {
              _showChangeNeededSheet(context).then((_) {
                final updatedState = context.read<CheckoutCubit>().state;
                if (updatedState.changeFor != null || !isCash) {
                  _showOrderConfirmationSheet(context);
                }
              });
            } else {
              _showOrderConfirmationSheet(context);
            }
          },
        );
      },
    );
  }

  // ✅ NOVO: Método para mostrar sheet de troco (copiado da lógica anterior)
  Future<void> _showChangeNeededSheet(BuildContext context) async {
    if (_isChangeSheetOpen) return;

    final cartState = context.read<CartCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;

    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded &&
        feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    _isChangeSheetOpen = true;
    final value = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ✅ CORREÇÃO: Remove fundo cinza
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: _ChangeNeededBottomSheet(grandTotal: grandTotal),
          ),
    );

    _isChangeSheetOpen = false;
    if (value != null && context.mounted) {
      context.read<CheckoutCubit>().updateChange(value);
    }
  }

  void _showOrderConfirmationSheet(BuildContext context) {
    if (_isConfirmationSheetOpen) return;

    _isConfirmationSheetOpen = true;
    // ✅ CORREÇÃO: Captura o contexto antes de usar no callback assíncrono
    final outerContext = context;
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (builderContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: outerContext.read<CartCubit>()),
            BlocProvider.value(value: outerContext.read<AddressCubit>()),
            BlocProvider.value(value: outerContext.read<DeliveryFeeCubit>()),
            BlocProvider.value(value: outerContext.read<CheckoutCubit>()),
            BlocProvider.value(value: outerContext.read<AuthCubit>()),
            BlocProvider.value(value: outerContext.read<StoreCubit>()),
          ],
          child: _OrderConfirmationBottomSheet(
            onShowPhoneSheet: (currentPhone) async {
              // ✅ Fecha o bottomSheet de confirmação
              Navigator.pop(builderContext);

              // ✅ CORREÇÃO: Coleta telefone, salva e continua fluxo usando contexto externo
              AppLogger.info(
                '📞 [CHECKOUT] Coletando telefone do cliente...',
                tag: 'CHECKOUT',
              );
              final phone = await showPhoneCollectionDialog(
                outerContext,
                initialPhone: currentPhone,
              );

              if (phone == null || phone.isEmpty) {
                AppLogger.warning(
                  '📞 [CHECKOUT] Telefone não informado - pedido cancelado',
                  tag: 'CHECKOUT',
                );
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
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

              // ✅ CRÍTICO: Salva telefone no backend E atualiza estado local
              if (!outerContext.mounted) {
                AppLogger.error(
                  '❌ [CHECKOUT] Contexto não está mounted após coletar telefone',
                  tag: 'CHECKOUT',
                );
                return;
              }

              final authCubit = outerContext.read<AuthCubit>();
              final customer = authCubit.state.customer;

              // ✅ DEBUG: Log detalhado do estado do customer
              AppLogger.info(
                '🔍 [CHECKOUT] Estado do customer:',
                tag: 'CHECKOUT',
              );
              AppLogger.info(
                '   ├─ customer = ${customer != null ? "NOT NULL" : "NULL"}',
                tag: 'CHECKOUT',
              );
              if (customer != null) {
                AppLogger.info(
                  '   ├─ customer.id = ${customer.id}',
                  tag: 'CHECKOUT',
                );
                AppLogger.info(
                  '   ├─ customer.name = ${customer.name}',
                  tag: 'CHECKOUT',
                );
                AppLogger.info(
                  '   ├─ customer.email = ${customer.email}',
                  tag: 'CHECKOUT',
                );
                AppLogger.info(
                  '   └─ customer.phone (antes) = ${customer.phone}',
                  tag: 'CHECKOUT',
                );
              }

              if (customer == null) {
                AppLogger.error(
                  '❌ [CHECKOUT] Customer é NULL! Não foi possível salvar telefone',
                  tag: 'CHECKOUT',
                );
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Erro: Cliente não encontrado. Faça login novamente.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (customer.id == null) {
                AppLogger.error(
                  '❌ [CHECKOUT] Customer ID é NULL! Não foi possível salvar telefone',
                  tag: 'CHECKOUT',
                );
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Erro: ID do cliente inválido. Faça login novamente.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              // ✅ CRÍTICO: Wrappa toda a operação em try-finally para garantir que o fluxo continue
              bool saveSuccessful = false;

              try {
                AppLogger.info(
                  '💾 [CHECKOUT] Salvando telefone no backend: $phone',
                  tag: 'CHECKOUT',
                );
                final customerRepo = getIt<CustomerRepository>();

                AppLogger.info(
                  '📤 [CHECKOUT] Chamando updateCustomerInfo...',
                  tag: 'CHECKOUT',
                );
                final result = await customerRepo.updateCustomerInfo(
                  customer.id!,
                  customer.name ?? '',
                  phone,
                  email: customer.email,
                );

                AppLogger.info(
                  '📥 [CHECKOUT] Resposta recebida do backend',
                  tag: 'CHECKOUT',
                );

                if (result.isRight && outerContext.mounted) {
                  final updatedCustomer = result.right;
                  authCubit.updateCustomer(updatedCustomer);
                  saveSuccessful = true;
                  AppLogger.success(
                    '✅ [CHECKOUT] Telefone salvo com sucesso no backend: ${updatedCustomer.phone}',
                    tag: 'CHECKOUT',
                  );
                  AppLogger.success(
                    '✅ [CHECKOUT] Estado local atualizado',
                    tag: 'CHECKOUT',
                  );
                } else if (result.isLeft) {
                  AppLogger.error(
                    '❌ [CHECKOUT] Erro do backend ao salvar telefone: ${result.left}',
                    tag: 'CHECKOUT',
                  );
                  if (outerContext.mounted) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Erro ao salvar telefone: ${result.left ?? "Erro desconhecido"}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e, stackTrace) {
                AppLogger.error(
                  '❌ [CHECKOUT] Exceção ao salvar telefone: $e',
                  tag: 'CHECKOUT',
                );
                AppLogger.error('   └─ Stack: $stackTrace', tag: 'CHECKOUT');
                if (outerContext.mounted) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao salvar telefone: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                // ✅ CRÍTICO: Reabre a confirmação SEMPRE, independente de sucesso ou falha
                // O telefone já foi coletado e o usuário pode prosseguir mesmo que o save falhe
                AppLogger.info(
                  '🔄 [CHECKOUT] Reabrindo modal de confirmação...',
                  tag: 'CHECKOUT',
                );
                await Future.delayed(const Duration(milliseconds: 500));
                if (outerContext.mounted) {
                  _isConfirmationSheetOpen =
                      false; // ✅ Reset flag antes de reabrir
                  _showOrderConfirmationSheet(outerContext);
                }
              }
            },
          ),
        );
      },
    ).then((_) {
      _isConfirmationSheetOpen = false;
    });
  }
}

class _OrderConfirmationBottomSheet extends StatelessWidget {
  final Function(String?)? onShowPhoneSheet;

  const _OrderConfirmationBottomSheet({this.onShowPhoneSheet});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store!;
    final cartState = context.read<CartCubit>().state;
    final addressState = context.read<AddressCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;
    final checkoutState = context.read<CheckoutCubit>().state;
    final authState = context.read<AuthCubit>().state;
    final theme = Theme.of(context);

    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded &&
        feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    // Estimativa de tempo
    final deliveryTime = store.getDeliveryTimeRange();

    // Endereço
    String addressLine = '';
    String addressComplement = '';

    // Título do tipo de entrega
    String deliveryTitle = 'Entrega hoje';
    IconData deliveryIcon = Icons.two_wheeler; // Ícone de moto por padrão

    if (feeState.deliveryType == DeliveryType.pickup) {
      deliveryTitle = 'Retirada na loja';
      deliveryIcon = Icons.storefront;
      if (store.street != null && store.street!.isNotEmpty) {
        addressLine =
            '${store.street}${store.number != null && store.number!.isNotEmpty ? ", ${store.number}" : ""}';
        addressComplement = store.complement ?? '';
      }
    } else {
      addressLine =
          '${addressState.selectedAddress?.street ?? ""}, ${addressState.selectedAddress?.number ?? ""}';
      addressComplement = addressState.selectedAddress?.complement ?? '';
    }

    // Pagamento
    final paymentMethodName =
        checkoutState.selectedPaymentMethod?.name ?? 'Pagamento';
    final isOnline =
        checkoutState.selectedPaymentMethod?.method_type == 'ONLINE';
    final paymentTypeLabel =
        isOnline ? 'Pagamento pelo app' : 'Pagamento na entrega';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Center(
            child: Text(
              'Revise o seu pedido',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Linha de Entrega
          _buildSummaryRow(
            context,
            icon: deliveryIcon,
            title: deliveryTitle,
            subtitle: 'Hoje, $deliveryTime',
          ),

          const SizedBox(height: 16),

          // Linha de Endereço (se houver)
          if (addressLine.isNotEmpty) ...[
            _buildSummaryRow(
              context,
              icon: Icons.location_on,
              title: addressLine,
              subtitle: addressComplement.isNotEmpty ? addressComplement : null,
            ),
            const SizedBox(height: 16),
          ],

          // TODO: Linha de Cupom (Se disponível no futuro)
          // _buildSummaryRow(context, icon: Icons.local_offer_outlined, title: 'Cupom', subtitle: 'Nenhum cupom aplicado'),
          // const SizedBox(height: 16),

          // Linha CPF na Nota (se houver e estiver ativo na loja)
          if (store.fiscalActive &&
              authState.customer?.cpf != null &&
              authState.customer!.cpf!.isNotEmpty) ...[
            _buildSummaryRow(
              context,
              icon: Icons.receipt_long,
              title: 'CPF na nota',
              subtitle: authState.customer!.cpf!,
            ),
            const SizedBox(height: 16),
          ],

          // Linha de Pagamento com PREÇO no final
          _buildSummaryRow(
            context,
            icon: isOnline ? Icons.credit_card : Icons.attach_money,
            title: paymentTypeLabel,
            subtitle: paymentMethodName,
            trailing: Text(
              UtilBrasilFields.obterReal(grandTotal),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Botão Confirmar
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Cor preta conforme solicitado
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Fazer pedido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                // Validações
                final storeStatus = StoreStatusService.validateStoreStatus(
                  store,
                );
                if (!storeStatus.canReceiveOrders) {
                  Navigator.pop(context);
                  await StoreClosedCartModal.show(
                    context,
                    onSeeOtherOptions: () => Navigator.pop(context),
                    nextOpenTime: storeStatus.message,
                  );
                  return;
                }

                if (store.fiscalActive) {
                  final cpf = authState.customer?.cpf;
                  if (cpf == null || cpf.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CPF é obrigatório.'),
                        backgroundColor: Colors.black,
                      ),
                    );
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _FiscalCpfBottomSheet(initialCpf: cpf),
                    );
                    return;
                  }
                }

                final customer = authState.customer;
                if (customer?.phone == null || customer!.phone!.isEmpty) {
                  // ✅ CORREÇÃO: NÃO fecha o bottom sheet aqui
                  // O callback onShowPhoneSheet vai fechar, coletar telefone, salvar E reabrir
                  if (onShowPhoneSheet != null) {
                    onShowPhoneSheet?.call(customer?.phone);
                  }
                  return;
                }

                Navigator.pop(context);
                final checkoutCubit = context.read<CheckoutCubit>();
                context.push(
                  '/order/submitting',
                  extra: {'checkoutCubit': checkoutCubit},
                );
                checkoutCubit.placeOrder(
                  cartState: cartState,
                  addressState: addressState,
                  feeState: feeState,
                  authState: authState,
                  store: store,
                );
              },
            ),
          ),

          // Botão Alterar Pedido
          const SizedBox(height: 12),
          TextButton(
            child: const Text(
              'Alterar pedido',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.black87, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, // Título em negrito
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}

// ✅ NOVO: Widget da seção CPF na Nota
class _FiscalCpfSection extends StatelessWidget {
  const _FiscalCpfSection();

  @override
  Widget build(BuildContext context) {
    // Escuta alterações no customer (AuthCubit) e Store (para saber se é fiscal active)
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        final store = storeState.store;
        final isFiscalMandatory = store?.fiscalActive ?? false;

        return BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final cpf = authState.customer?.cpf;
            final hasCpf = cpf != null && cpf.isNotEmpty;

            // Se não ativado, oculta a seção
            if (!isFiscalMandatory) return const SizedBox.shrink();

            // Se obrigatório e vazio, destaca erro
            final showWarning = isFiscalMandatory && !hasCpf;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 24,
                        color: showWarning ? Colors.red : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CPF na nota',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    showWarning ? Colors.red : Colors.black87,
                              ),
                            ),
                            if (!hasCpf)
                              Text(
                                isFiscalMandatory ? 'Obrigatório' : 'Opcional',
                                style: TextStyle(
                                  color:
                                      showWarning
                                          ? Colors.red.shade700
                                          : Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight:
                                      isFiscalMandatory
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasCpf)
                        TextButton(
                          onPressed: () => _openCpfSheet(context, cpf),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _obfuscateCpf(cpf),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => _openCpfSheet(context, null),
                          child: const Text(
                            'Adicionar',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _obfuscateCpf(String cpf) {
    if (cpf.length < 11) return cpf;
    return '***.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-**';
  }

  void _openCpfSheet(BuildContext context, String? currentCpf) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiscalCpfBottomSheet(initialCpf: currentCpf),
    );
  }
}

// ✅ NOVO: Bottom Sheet para editar CPF
class _FiscalCpfBottomSheet extends StatefulWidget {
  final String? initialCpf;
  const _FiscalCpfBottomSheet({super.key, this.initialCpf});
  @override
  State<_FiscalCpfBottomSheet> createState() => _FiscalCpfBottomSheetState();
}

class _FiscalCpfBottomSheetState extends State<_FiscalCpfBottomSheet> {
  final _inputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCpf != null && widget.initialCpf!.isNotEmpty) {
      // Aplica formatação se não estiver formatado
      if (widget.initialCpf!.length <= 11) {
        _inputController.text = UtilBrasilFields.obterCpf(widget.initialCpf!);
      } else {
        _inputController.text = widget.initialCpf!;
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _saveCpf() async {
    if (!_formKey.currentState!.validate()) return;

    // Remove pontuação para salvar limpo
    final cpfClean = UtilBrasilFields.removeCaracteres(_inputController.text);

    setState(() => _isLoading = true);

    try {
      final authCubit = context.read<AuthCubit>();
      final customer = authCubit.state.customer;

      if (customer?.id == null) return;

      final repo = getIt<CustomerRepository>();
      // Mantem phone atual. Assumimos que phone não é nulo se user está logado e no checkout, mas usamos ?? '' por segurança
      final result = await repo.updateCustomerInfo(
        customer!.id!,
        customer.name,
        customer.phone ?? '', // Phone é obrigatório posicional
        cpf: cpfClean,
        email: customer.email,
      );

      if (result.isRight && mounted) {
        authCubit.updateCustomer(result.right);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CPF salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.left ?? 'Erro ao salvar CPF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<DsThemeSwitcher>().theme;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CPF na nota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'É necessário informar o seu CPF para fazer o pedido nesta loja',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'CPF',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfInputFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Informe o CPF';
                if (!UtilBrasilFields.isCPFValido(value)) return 'CPF inválido';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _saveCpf,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.white,
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

// ✅ NOVO: Seção de Upsell no Checkout
class _CheckoutUpsellSection extends StatelessWidget {
  const _CheckoutUpsellSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final catalogState = context.watch<CatalogCubit>().state;
        final allProducts = catalogState.products ?? [];
        final allCategories = catalogState.activeCategories;
        final itemsInCart = cartState.cart.items;

        // Se não tem produtos ou carrinho vazio, não mostra upsell
        if (allProducts.isEmpty ||
            itemsInCart.isEmpty ||
            allCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        // Obtém produtos recomendados usando o serviço existente
        final recommendedProducts =
            ProductRecommendationService.getRecommendedProducts(
              allProducts: allProducts,
              allCategories: allCategories,
              itemsInCart: itemsInCart,
              maxItems: 6, // Limita a 6 produtos no checkout
            );

        // Se não tem recomendações, não mostra a seção
        if (recommendedProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            RecommendedProductsSection(
              recommendedProducts: recommendedProducts,
              allCategories: allCategories,
              onProductTap: (product) => _handleProductTap(context, product),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleProductTap(BuildContext context, Product product) async {
    // ✅ Verifica se tem variantes/complementos OU é pizza (tem prices)
    final hasVariants = product.variantLinks.isNotEmpty;
    final isPizza = product.prices.isNotEmpty;

    // ✅ Se tem complementos OU é pizza, abre tela de detalhes
    if (hasVariants || isPizza) {
      // ✅ ENTERPRISE: Usa ID ofuscado na URL
      final productUrl = IdObfuscator.createProductUrl(
        product.name,
        product.id!,
      );
      context.push('/product/$productUrl?fromCart=true', extra: product);
    } else {
      // ✅ Produto simples: adiciona direto ao carrinho
      final firstCategoryLink = product.categoryLinks.firstOrNull;
      if (firstCategoryLink == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro: ${product.name} não pertence a nenhuma categoria.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final payload = UpdateCartItemPayload(
        productId: product.id!,
        categoryId: firstCategoryLink.categoryId,
        quantity: 1,
        variants: null,
      );

      try {
        await context.read<CartCubit>().updateItem(payload);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} adicionado à sacola!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Não foi possível adicionar ${product.name}. Tente novamente.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _ScheduleOrderSection extends StatefulWidget {
  const _ScheduleOrderSection();

  @override
  State<_ScheduleOrderSection> createState() => _ScheduleOrderSectionState();
}

class _ScheduleOrderSectionState extends State<_ScheduleOrderSection> {
  @override
  Widget build(BuildContext context) {
    // ✅ Verifica se pedidos agendados estão habilitados
    final store = context.read<StoreCubit>().state.store;
    final scheduledEnabled =
        store?.store_operation_config?.scheduledOrdersEnabled ?? false;

    // Se não estiver habilitado, não mostra a seção
    if (!scheduledEnabled) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Agendar pedido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: state.isScheduled,
                      onChanged: (value) {
                        if (value) {
                          _pickScheduleDateTime(context);
                        } else {
                          context.read<CheckoutCubit>().updateScheduling(
                            false,
                            null,
                          );
                        }
                      },
                    ),
                  ],
                ),
                if (state.isScheduled && state.scheduledFor != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: InkWell(
                      onTap: () => _pickScheduleDateTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.scheduledFor!.day}/${state.scheduledFor!.month}/${state.scheduledFor!.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${state.scheduledFor!.hour.toString().padLeft(2, '0')}:${state.scheduledFor!.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickScheduleDateTime(BuildContext context) async {
    final now = DateTime.now();
    final minDate = now.add(
      const Duration(minutes: 30),
    ); // No mínimo 30 minutos no futuro

    // Pega a data
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: minDate.add(
        const Duration(days: 30),
      ), // Máximo 30 dias no futuro
      locale: const Locale('pt', 'BR'),
    );

    if (selectedDate == null) return;

    // Pega a hora
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(minDate),
    );

    if (selectedTime == null) return;

    // Combina data e hora
    final scheduledDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Valida que a data/hora escolhida não está no passado
    if (scheduledDateTime.isBefore(minDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escolha uma data e hora no futuro')),
        );
      }
      return;
    }

    context.read<CheckoutCubit>().updateScheduling(true, scheduledDateTime);
  }
}
