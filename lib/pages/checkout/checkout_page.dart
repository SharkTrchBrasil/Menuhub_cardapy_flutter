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
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';
import 'package:totem/pages/checkout/widgets/checkou_summary_card.dart';
import 'package:totem/pages/checkout/widgets/payment_methods.dart';
import 'package:totem/widgets/dot_loading.dart';


import '../../core/di.dart';
import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../models/delivery_type.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/ds_primary_button.dart';
import '../../widgets/store_header_card.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreCubit>().state.store;
    if (store == null) return const Scaffold(body: Center(child: DotLoading()));

    // ✅ INÍCIO DA CORREÇÃO
    // 1. Pegamos os dados necessários de outros cubits que já existem.
    final addressState = context.read<AddressCubit>().state;
    final cart = context.read<CartCubit>().state.cart;

    // 2. Disparamos o cálculo do frete imediatamente.
    //    Esta é a mesma lógica que funciona na tela do carrinho.
    context.read<DeliveryFeeCubit>().calculate(
      address: addressState.selectedAddress,
      store: store,
      cartSubtotal: cart.subtotal / 100.0,
    );
    // ✅ FIM DA CORREÇÃO


    return BlocProvider(
      create: (context) => CheckoutCubit(
        realtimeRepository: getIt(),
        customerRepository: getIt<CustomerRepository>(),
      )..initialize(store),
      child: const CheckoutView(), // O listener foi removido daqui
    );
  }
}

class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key});

  // ✅ A função para mostrar o BottomSheet agora mora aqui
  void _showChangeNeededSheet(BuildContext context) {

    // ✅ LÓGICA ADICIONADA: Calcula o total antes de chamar o sheet
    final cartState = context.read<CartCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;

    final deliveryFee = (feeState.deliveryType == DeliveryType.delivery)
        ? feeState.calculatedDeliveryFee
        : 0;
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;




    showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Remove o arredondamento
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ChangeNeededBottomSheet(grandTotal: grandTotal),
      ),
    ).then((value) {
      if (value != null) {
        context.read<CheckoutCubit>().updateChange(value);
      }
    });
  }
  // ✅ NOVO: Função auxiliar para determinar o título do grupo de pagamento
  String _getPaymentGroupTitle(PlatformPaymentMethod method) {
    // Você pode expandir esta lógica se tiver mais tipos
    switch (method.method_type) {
      case 'ONLINE':
        return 'Pagamento pelo app';
      case 'CASH':
      case 'CARD_MACHINE': // Exemplo de outro tipo "na entrega"
        return 'Pagamento na entrega';
      default:
        return 'Forma de pagamento';
    }
  }


  @override
  Widget build(BuildContext context) {
    // ✅ O BlocListener agora envolve o Scaffold na View.
    return BlocListener<CheckoutCubit, CheckoutState>(
        // ✅ OTIMIZAÇÃO: O listener só será chamado quando o método de pagamento mudar.
        listenWhen: (previous, current) => previous.selectedPaymentMethod != current.selectedPaymentMethod,
    listener: (context, state) {
    // Lógica de sucesso/erro que já existia
    if (state.status == CheckoutStatus.success) {
    context.read<CartCubit>().clearCart().then((_) {
    context.go('/order/success', extra: state.finalOrder);
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

    // ✅ NOVA LÓGICA: Dispara o BottomSheet automaticamente
    // Verifica se o novo método é CASH e se o troco ainda não foi definido.
    if (state.selectedPaymentMethod?.method_type == 'CASH' && state.changeFor == null) {
    // Adiciona um pequeno delay para garantir que a UI de troca de método
    // termine antes de mostrar o BottomSheet.
    Future.delayed(const Duration(milliseconds: 300), () {
    _showChangeNeededSheet(context);
    });
    }
    },
    child:  Scaffold(
      appBar: AppBar(
        title: const Text('Sacola', style: TextStyle(fontSize: 14)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StoreHeaderCard(),
            const SizedBox(height: 24),

            // ✅ LÓGICA ATUALIZADA AQUI
            BlocBuilder<CheckoutCubit, CheckoutState>(
              builder: (context, state) {
                // Se nenhum método foi carregado ainda, mostra o placeholder completo.
                if (state.selectedPaymentMethod == null) {
                  return const _PaymentSectionPlaceholder();
                }

                // Se já temos um método, constrói a seção real com o título dinâmico.
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

            // ✅ ADICIONADO AQUI
            const SizedBox(height: 32),
            const OrderSummaryCard(),
            const SizedBox(height: 24),



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
    );
  }




  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(), // Deixando em maiúsculas como no iFood
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }


// ✅ NOVO WIDGET: Placeholder para a seção de pagamento inteira
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
          // Placeholder para o título
          Container(
            width: 200,
            height: 20,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          // Placeholder para o Card
          Container(
            width: double.infinity,
            height: 80, // Altura aproximada do seu card de pagamento
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
// ✅ NOVO: Widget para o resumo do pagamento


class _PaymentMethodSummary extends StatelessWidget {
  // ✅ Recebe a função por parâmetro
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

        final deliveryType = context.read<DeliveryFeeCubit>().state.deliveryType;

// 2. Pegue a lista completa de métodos da loja
        final allPaymentGroups = context.read<StoreCubit>().state.store!.paymentMethodGroups;

// 3. Filtre a lista ANTES de passar para a próxima tela!
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
                leading:   _buildPaymentIcon(method.iconKey),
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
            ],
          ),
        );
      },
    );
  }


  Widget _buildPaymentIcon(String? iconKey) {

    if (iconKey != null && iconKey.isNotEmpty) {
      final String assetPath = 'assets/icons/$iconKey';
      return SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          assetPath,

          placeholderBuilder: (context) => Icon(Icons.credit_card, size: 24, ),
        ),
      );
    }
    return Icon(Icons.payment, size: 24);
  }


}

class _ChangeNeededBottomSheet extends StatefulWidget {
  // ✅ ADICIONADO: Propriedade para receber o total do pedido
  final double grandTotal;

  const _ChangeNeededBottomSheet({super.key, required this.grandTotal});

  @override
  State<_ChangeNeededBottomSheet> createState() => _ChangeNeededBottomSheetState();
}



class _ChangeNeededBottomSheetState extends State<_ChangeNeededBottomSheet> {
  final _controller = TextEditingController();

  // ✅ 1. Variável para guardar a mensagem de erro no estado do widget
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Bônus: Limpa a mensagem de erro assim que o usuário começa a digitar
    _controller.addListener(() {
      if (_errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
      }
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
          Center(
            child: Text('Precisa de troco?', style: theme.textTheme.headlineSmall),
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter()],
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              // Mostra o erro diretamente no campo de texto
              errorText: _errorMessage,
            ),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ao receber seu pedido, não esqueça de conferir o troco.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ✅ 2. Usando TextButton em vez de GestureDetector/ElevatedButton
          TextButton(
            style: ButtonStyle(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () {
              final enteredAmount = UtilBrasilFields.converterMoedaParaDouble(_controller.text);
              final total = widget.grandTotal;

              if (enteredAmount <= total) {
                // ✅ 1. Atualiza o estado com a mensagem de erro
                setState(() {
                  _errorMessage = 'O valor para troco deve ser maior que o total.';
                });
                return; // Impede o fechamento
              }

              Navigator.pop(context, enteredAmount);
            },
            child: Text(

              'Confirmar valor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black
                // Cor de destaque
              ),
            ),
          ),
          const SizedBox(height: 45),
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





// ✅ MODIFICADO: Barra inferior para mostrar o BottomSheet de confirmação
class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({super.key});

  void _showOrderConfirmationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        // Compartilha os cubits existentes com o BottomSheet
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CartCubit>()),
            BlocProvider.value(value: context.read<AddressCubit>()),
            BlocProvider.value(value: context.read<DeliveryFeeCubit>()),
            BlocProvider.value(value: context.read<CheckoutCubit>()),
            BlocProvider.value(value: context.read<AuthCubit>()),
          ],
          child: const _OrderConfirmationBottomSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
          builder: (context, feeState) {
            final deliveryFee = (feeState.deliveryType == DeliveryType.delivery)
                ? feeState.calculatedDeliveryFee
                : 0;
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

// ✅ NOVO: O BottomSheet de confirmação final
class _OrderConfirmationBottomSheet extends StatelessWidget {
  const _OrderConfirmationBottomSheet();

  @override
  Widget build(BuildContext context) {
    // Lê todos os estados necessários
    final store = context.read<StoreCubit>().state.store!;
    final cartState = context.read<CartCubit>().state;
    final addressState = context.read<AddressCubit>().state;
    final feeState = context.read<DeliveryFeeCubit>().state;
    final checkoutState = context.read<CheckoutCubit>().state;
    final authState = context.read<AuthCubit>().state;

    final deliveryFee = (feeState.deliveryType == DeliveryType.delivery) ? feeState.calculatedDeliveryFee : 0;
    final grandTotal = (cartState.cart.total / 100.0) + deliveryFee;

    final deliveryTime = '${store.store_operation_config?.deliveryEstimatedMin}-${store.store_operation_config?.deliveryEstimatedMax} min';
    final addressLine = '${addressState.selectedAddress?.street}, ${addressState.selectedAddress?.number}';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Revise o seu pedido', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _buildSummaryRow(Icons.delivery_dining, 'Entrega hoje', deliveryTime),
          const Divider(),
          _buildSummaryRow(Icons.location_on, addressLine, addressState.selectedAddress?.complement ?? ''),
          const Divider(),
          // Aqui você pode adicionar a lógica para o cupom se houver
          // _buildSummaryRow(Icons.confirmation_number, 'Cupom aplicado', 'R\$ 5 OFF'),
          _buildSummaryRow(
            Icons.account_balance_wallet,
            'Pagamento na entrega',
            '${checkoutState.selectedPaymentMethod?.name} • ${UtilBrasilFields.obterReal(grandTotal)}',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            child: const Text('Fazer pedido'),
            onPressed: () {
              context.read<CheckoutCubit>().placeOrder(
                cartState: cartState,
                addressState: addressState,
                feeState: feeState,
                authState: authState,
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

