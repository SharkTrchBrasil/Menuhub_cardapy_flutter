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
import 'package:totem/pages/checkout/widgets/checkou_summary_card.dart';
import 'package:totem/pages/checkout/widgets/payment_methods.dart';
import 'package:totem/pages/checkout/widgets/phone_collection_bottom_sheet.dart';
import 'package:totem/widgets/dot_loading.dart';
import '../../core/di.dart';
import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../models/delivery_type.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/ds_primary_button.dart';
import '../../widgets/store_header_card.dart';
import '../cart/cart_state.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    if (store == null) return const Scaffold(body: Center(child: DotLoading()));

    final addressState = context.read<AddressCubit>().state;
    final cart = context.read<CartCubit>().state.cart;

    final deliveryFeeCubit = context.read<DeliveryFeeCubit>();
    
    // ✅ Calcula frete assincronamente
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
        // ✅ Inicializa com tipo de entrega atual
        // Se deliveryType for null, inicializa sem filtro para mostrar todos os métodos ativos
        final currentDeliveryType = deliveryFeeCubit.state.deliveryType;
        print('🔍 [CheckoutPage] Inicializando CheckoutCubit com deliveryType: ${currentDeliveryType?.name ?? "null"}');
        cubit.initialize(store, deliveryType: currentDeliveryType);
        return cubit;
      },
      child: const CheckoutView(),
    );
  }
}

class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key});

  // ✅ NOVO: Flag para evitar que o bottom sheet do troco abra múltiplas vezes
  static bool _isChangeSheetOpen = false;

  void _showChangeNeededSheet(BuildContext context) {
    // ✅ CORREÇÃO: Previne que abra múltiplas vezes
    if (_isChangeSheetOpen) return;
    
    final cartState = context.read<CartCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;

    // ✅ CORREÇÃO APLICADA AQUI
    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    _isChangeSheetOpen = true;
    showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ChangeNeededBottomSheet(grandTotal: grandTotal),
      ),
    ).then((value) {
      _isChangeSheetOpen = false;
      if (value != null) {
        context.read<CheckoutCubit>().updateChange(value);
      }
    });
  }

  // ✅ NOVO: Bottom sheet para coletar telefone
  void _showPhoneCollectionSheet(BuildContext context, String? currentPhone) {
    showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PhoneCollectionBottomSheet(initialPhone: currentPhone),
      ),
    );
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
          context.read<CheckoutCubit>().updateForDeliveryType(store, feeState.deliveryType!);
        }
      },
      child: BlocListener<CheckoutCubit, CheckoutState>(
        listenWhen: (previous, current) => previous.status != current.status || previous.selectedPaymentMethod != current.selectedPaymentMethod,
        listener: (context, state) {
        if (state.status == CheckoutStatus.success) {
          context.read<CartCubit>().clearCart().then((_) {
            // ✅ CORREÇÃO: Passa order e payment method para a tela de sucesso
            context.go('/order/success', extra: {
              'order': state.finalOrder,
              'paymentMethod': state.selectedPaymentMethod,
            });
          });
        }
        if (state.status == CheckoutStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? "Ocorreu um erro."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        if (state.selectedPaymentMethod?.method_type == 'CASH' && state.changeFor == null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _showChangeNeededSheet(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finalizar Pedido', style: TextStyle(fontSize: 14)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StoreHeaderCard(),
              const SizedBox(height: 24),
              BlocBuilder<CheckoutCubit, CheckoutState>(
                buildWhen: (previous, current) => 
                    previous.selectedPaymentMethod != current.selectedPaymentMethod,
                builder: (context, state) {
                  // ✅ CORREÇÃO: Mostra mensagem informativa se não há métodos disponíveis
                  if (state.selectedPaymentMethod == null) {
                    final hasPaymentGroups = store?.paymentMethodGroups.isNotEmpty ?? false;
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
                              Icon(Icons.payment, color: Colors.orange.shade700, size: 48),
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
                  final paymentTitle = _getPaymentGroupTitle(state.selectedPaymentMethod!);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(paymentTitle),
                      _PaymentMethodSummary(onShowChangeSheet: () => _showChangeNeededSheet(context)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const OrderSummaryCard(),
              const SizedBox(height: 32),
              const _ScheduleOrderSection(),
              const SizedBox(height: 32),
              _buildSectionTitle('Observações'),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Ex: tirar a cebola, ponto da carne, etc.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) => context.read<CheckoutCubit>().setObservation(text),
                maxLines: 3,
              ),
            ],
          ),
        ),
        bottomNavigationBar: const CheckoutBottomBar(),
      ),
    ));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
            width: 200, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
          ),
          Container(
            width: double.infinity, height: 80,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
        if (state.selectedPaymentMethod == null) return const Center(child: CircularProgressIndicator());
        final method = state.selectedPaymentMethod!;
        final isCash = method.method_type == 'CASH';
        final deliveryType = context.read<DeliveryFeeCubit>().state.deliveryType;
        final allPaymentGroups = context.read<StoreCubit>().state.store!.paymentMethodGroups;
        final availablePaymentGroups = allPaymentGroups.filterFor(deliveryType);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              ListTile(
                leading: _buildPaymentIcon(method.iconKey),
                title: Text(method.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: TextButton(
                  child: const Text('Trocar'),
                  onPressed: () async {
                    final selected = await Navigator.push<PlatformPaymentMethod>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentMethodSelectionList(
                          paymentGroups: availablePaymentGroups,
                          initialSelectedMethod: method,
                        ),
                      ),
                    );
                    if (selected != null) {
                      context.read<CheckoutCubit>().updatePaymentMethod(selected);
                    }
                  },
                ),
              ),
              if (isCash) ...[
                const Divider(height: 1),
                ListTile(
                  title: const Text('Precisa de troco?'),
                  subtitle: Text(
                    state.changeFor == null || state.changeFor == 0
                        ? 'Não, obrigado'
                        : 'Sim, para ${UtilBrasilFields.obterReal(state.changeFor!)}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: onShowChangeSheet,
                ),
              ],
              // ✅ NOVO: Exibe chave PIX estática se configurada
              if (method.method_type == 'MANUAL_PIX' || method.name.toLowerCase().contains('pix')) ...[
                Builder(
                  builder: (context) {
                    final pixKey = method.getStaticPixKey();
                    final pixKeyType = method.getStaticPixKeyType();
                    
                    if (pixKey == null) return const SizedBox.shrink();
                    
                    String formattedKey = pixKey;
                    String keyTypeLabel = '';
                    
                    // Formata a chave conforme o tipo
                    switch (pixKeyType) {
                      case 'CPF':
                        keyTypeLabel = 'CPF';
                        if (pixKey.length == 11) {
                          formattedKey = '${pixKey.substring(0, 3)}.${pixKey.substring(3, 6)}.${pixKey.substring(6, 9)}-${pixKey.substring(9)}';
                        }
                        break;
                      case 'CNPJ':
                        keyTypeLabel = 'CNPJ';
                        if (pixKey.length == 14) {
                          formattedKey = '${pixKey.substring(0, 2)}.${pixKey.substring(2, 5)}.${pixKey.substring(5, 8)}/${pixKey.substring(8, 12)}-${pixKey.substring(12)}';
                        }
                        break;
                      case 'phone':
                        keyTypeLabel = 'Celular';
                        if (pixKey.length == 11) {
                          formattedKey = '(${pixKey.substring(0, 2)}) ${pixKey.substring(2, 7)}-${pixKey.substring(7)}';
                        }
                        break;
                      case 'email':
                        keyTypeLabel = 'E-mail';
                        break;
                      case 'random':
                        keyTypeLabel = 'Chave aleatória';
                        break;
                      default:
                        keyTypeLabel = 'Chave PIX';
                    }
                    
                    return Column(
                      children: [
                        const Divider(height: 1),
                        ListTile(
                          title: Text('Chave PIX ${keyTypeLabel.isNotEmpty ? '($keyTypeLabel)' : ''}'),
                          subtitle: SelectableText(
                            formattedKey,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: pixKey));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Chave PIX copiada!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copiar chave PIX',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
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
      'vr': 'cash', // Vale refeição -> dinheiro como fallback
      'alelo': 'cash', // Alelo -> dinheiro como fallback
      'va': 'cash', // Vale alimentação -> dinheiro como fallback
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

  const _SafeSvgPicture({
    required this.assetPath,
    required this.fallback,
  });

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
  State<_ChangeNeededBottomSheet> createState() => _ChangeNeededBottomSheetState();
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text('Precisa de troco?', style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 8),
          const Text('Informe o valor em dinheiro que você vai pagar para que o entregador leve o troco.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter()],
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              errorText: _errorMessage,
            ),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Ao receber seu pedido, não esqueça de conferir o troco.', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextButton(
            style: ButtonStyle(overlayColor: MaterialStateProperty.all(Colors.transparent)),
            onPressed: () {
              final enteredAmount = UtilBrasilFields.converterMoedaParaDouble(_controller.text);
              if (enteredAmount <= widget.grandTotal) {
                setState(() => _errorMessage = 'O valor para troco deve ser maior que o total.');
                return;
              }
              Navigator.pop(context, enteredAmount);
            },
            child: const Text('Confirmar valor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
          ),
          const SizedBox(height: 45),
          TextButton(
            style: ButtonStyle(overlayColor: MaterialStateProperty.all(Colors.transparent)),
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text('Não preciso de troco', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({super.key});

  // ✅ NOVO: Flag para evitar que o sheet de confirmação abra múltiplas vezes
  static bool _isConfirmationSheetOpen = false;

  void _showOrderConfirmationSheet(BuildContext context) {
    // ✅ CORREÇÃO: Previne que abra múltiplas vezes
    if (_isConfirmationSheetOpen) return;
    
    _isConfirmationSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CartCubit>()),
            BlocProvider.value(value: context.read<AddressCubit>()),
            BlocProvider.value(value: context.read<DeliveryFeeCubit>()),
            BlocProvider.value(value: context.read<CheckoutCubit>()),
            BlocProvider.value(value: context.read<AuthCubit>()),
            BlocProvider.value(value: context.read<StoreCubit>()),
          ],
          child: _OrderConfirmationBottomSheet(
            onShowPhoneSheet: (currentPhone) async {
              // Fecha o sheet de confirmação e mostra o de telefone
              Navigator.pop(context);
              await _showPhoneCollectionSheet(context, currentPhone);
            },
          ),
        );
      },
    ).then((_) {
      _isConfirmationSheetOpen = false;
    });
  }

  // ✅ NOVO: Bottom sheet para coletar telefone
  Future<void> _showPhoneCollectionSheet(BuildContext context, String? currentPhone) async {
    final phone = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PhoneCollectionBottomSheet(initialPhone: currentPhone),
      ),
    );

    if (phone != null && phone.isNotEmpty) {
      final authState = context.read<AuthCubit>().state;
      final customer = authState.customer;
      
      if (customer?.id != null) {
        // Atualiza telefone no backend
        try {
          final customerRepo = getIt<CustomerRepository>();
          final result = await customerRepo.updateCustomerInfo(
            customer!.id!,
            customer.name,
            phone,
            email: customer.email,
          );
          
          if (result.isRight) {
            // Atualiza o customer no AuthCubit
            context.read<AuthCubit>().updateCustomer(result.right);
            
            // Mostra mensagem de sucesso e reabre o sheet de confirmação
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Telefone salvo com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Aguarda um pouco e reabre o sheet de confirmação
            await Future.delayed(const Duration(milliseconds: 500));
            _showOrderConfirmationSheet(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao salvar telefone: ${result.left}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar telefone: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else if (phone == null) {
      // Usuário cancelou ou não informou telefone
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário informar um telefone para finalizar o pedido.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            // ✅ CORREÇÃO APLICADA AQUI
            double deliveryFee = 0.0;
            if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
              deliveryFee = feeState.deliveryFee;
            }
            final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

            return BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: DsPrimaryButton(
                  label: 'Revisar pedido • ${UtilBrasilFields.obterReal(grandTotal)}',
                  onPressed: () => _showOrderConfirmationSheet(context),
                ),
              ),
            );
          },
        );
      },
    );
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

    // ✅ CORREÇÃO APLICADA AQUI
    double deliveryFee = 0.0;
    if (feeState is DeliveryFeeLoaded && feeState.deliveryType == DeliveryType.delivery) {
      deliveryFee = feeState.deliveryFee;
    }
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    final deliveryTime = '${store.store_operation_config?.deliveryEstimatedMin}-${store.store_operation_config?.deliveryEstimatedMax} min';
    
    // ✅ CORREÇÃO: Se for pickup, mostra endereço da loja ou oculta; se for delivery, mostra endereço do cliente
    String addressLine = '';
    String addressComplement = '';
    if (feeState.deliveryType == DeliveryType.pickup) {
      // Para retirada, mostra endereço da loja ou oculta
      if (store.street != null && store.street!.isNotEmpty) {
        addressLine = '${store.street}${store.number != null && store.number!.isNotEmpty ? ", ${store.number}" : ""}';
        addressComplement = store.complement ?? '';
      }
      // Se não tiver endereço da loja, não mostra nada (addressLine fica vazio)
    } else {
      // Para delivery, mostra endereço do cliente
      addressLine = '${addressState.selectedAddress?.street ?? ""}, ${addressState.selectedAddress?.number ?? ""}';
      addressComplement = addressState.selectedAddress?.complement ?? '';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Revise o seu pedido', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _buildSummaryRow(
            Icons.delivery_dining, 
            feeState.deliveryType == DeliveryType.pickup ? 'Retirada' : 'Entrega hoje', 
            deliveryTime
          ),
          const Divider(),
          if (addressLine.isNotEmpty) ...[
            _buildSummaryRow(Icons.location_on, addressLine, addressComplement),
            const Divider(),
          ],
          _buildSummaryRow(
            Icons.account_balance_wallet,
            'Pagamento na entrega',
            '${checkoutState.selectedPaymentMethod?.name} • ${UtilBrasilFields.obterReal(grandTotal)}',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            child: const Text('Fazer pedido'),
            onPressed: () async {
              // ✅ NOVO: Valida se tem telefone antes de finalizar
              final customer = authState.customer;
              if (customer?.phone == null || customer!.phone!.isEmpty) {
                // Mostra bottom sheet para coletar telefone
                Navigator.pop(context); // Fecha o sheet de confirmação
                if (onShowPhoneSheet != null) {
                  onShowPhoneSheet?.call(customer?.phone);
                }
                return;
              }
              
              // Se tem telefone, prossegue normalmente
              Navigator.pop(context); // Fecha o sheet de confirmação
              context.read<CheckoutCubit>().placeOrder(
                cartState: cartState,
                addressState: addressState,
                feeState: feeState,
                authState: authState,
                store: store,
              );
            },
          ),
          TextButton(
            child: const Text('Alterar pedido'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
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
    final scheduledEnabled = store?.store_operation_config?.scheduledOrdersEnabled ?? false;
    
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
                        Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'Agendar pedido',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Switch(
                      value: state.isScheduled,
                      onChanged: (value) {
                        if (value) {
                          _pickScheduleDateTime(context);
                        } else {
                          context.read<CheckoutCubit>().updateScheduling(false, null);
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
                            Icon(Icons.calendar_today, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.scheduledFor!.day}/${state.scheduledFor!.month}/${state.scheduledFor!.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${state.scheduledFor!.hour.toString().padLeft(2, '0')}:${state.scheduledFor!.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: Colors.grey.shade600),
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
    final minDate = now.add(const Duration(minutes: 30)); // No mínimo 30 minutos no futuro
    
    // Pega a data
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: minDate.add(const Duration(days: 30)), // Máximo 30 dias no futuro
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