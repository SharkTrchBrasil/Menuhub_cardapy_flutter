// lib/pages/checkout/order_submission_page.dart
// ✅ Página de animação ao enviar pedido - inspirada no Admin

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/pages/checkout/checkout_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/models/order.dart';
import 'package:totem/cubit/store_cubit.dart';
import '../../core/utils/app_logger.dart';
import '../../helpers/payment_method.dart';

/// Página de submissão de pedido com animação
/// Mostra loading enquanto o pedido está sendo processado
/// e sucesso/erro ao final
class OrderSubmissionPage extends StatefulWidget {
  const OrderSubmissionPage({super.key});

  @override
  State<OrderSubmissionPage> createState() => _OrderSubmissionPageState();
}

class _OrderSubmissionPageState extends State<OrderSubmissionPage> {
  Timer? _messageTimer;
  int _currentMessageIndex = 0;
  final List<String> _loadingMessages = [
    'Preparando seu pedido...',
    'Verificando itens...',
    'Processando pagamento...',
    'Enviando para cozinha...',
    'Quase pronto!',
  ];

  bool _isSuccess = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startMessageTimer();
  }

  void _startMessageTimer() {
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && !_isSuccess && !_hasError) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  void _handleSuccess(Order order) {
    AppLogger.success(
      '✅ [ORDER_SUBMISSION] Pedido criado com sucesso: #${order.id}',
      tag: 'CHECKOUT',
    );

    setState(() {
      _isSuccess = true;
      _hasError = false;
    });

    _messageTimer?.cancel();
  }

  void _handleError(String message) {
    AppLogger.error(
      '❌ [ORDER_SUBMISSION] Erro ao criar pedido: $message',
      tag: 'CHECKOUT',
    );

    setState(() {
      _hasError = true;
      _isSuccess = false;
      _errorMessage = message;
    });

    _messageTimer?.cancel();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ Ícone de cozinha + loading (substituindo Lottie para evitar StackOverflow no Web)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade400,
                  ),
                ),
              ),
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.orange.shade700,
              ),
            ],
          ),
          const SizedBox(height: 48),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingMessages[_currentMessageIndex],
              key: ValueKey<int>(_currentMessageIndex),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 250,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone de erro
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade50,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Ops! Algo deu errado',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Não foi possível processar seu pedido',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Voltar'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Tenta novamente voltando para a tela anterior
                    context.pop();
                  },
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (prev, current) => prev.status != current.status,
      listener: (context, state) {
        if (state.status == CheckoutStatus.success &&
            state.finalOrder != null) {
          _handleSuccess(state.finalOrder!);

          // ✅ CORREÇÃO: Captura referências ANTES do delay para evitar uso de contexto disposto
          final cartCubit = context.read<CartCubit>();
          final storeCubit = context.read<StoreCubit>();
          final router = GoRouter.of(context);
          final paymentMethod = state.selectedPaymentMethod;
          final order = state.finalOrder!;

          // Limpa o carrinho IMEDIATAMENTE (antes do delay)
          cartCubit.clearCart();

          // Navega após um breve delay para o usuário ver a animação de sucesso
          Future.delayed(const Duration(seconds: 2), () {
            // ✅ Verifica se widget ainda está montado antes de navegar
            if (!mounted) return;

            // ✅ NOVO: Se pagamento for PIX Manual, mostra tela de QR Code
            final isPixManual = paymentMethod?.method_type == 'MANUAL_PIX';
            final pixKey = paymentMethod?.getStaticPixKey();

            if (isPixManual && pixKey != null && pixKey.isNotEmpty) {
              // Pega dados da loja para gerar QR Code
              final store = storeCubit.state.store;

              router.go(
                '/pix-payment',
                extra: {
                  'totalCents': order.payments.total.value,
                  'pixKey': pixKey,
                  'pixKeyType': paymentMethod?.getStaticPixKeyType(),
                  'storeName': store?.name ?? '',
                  'storeCity': store?.city ?? 'Brasil',
                  'orderNumber':
                      order.sequentialId?.toString() ??
                      order.publicId ??
                      order.id.toString(),
                  'orderId': int.tryParse(order.id),
                  'order': order,
                },
              );
            } else {
              // ✅ DIRETO PARA DETALHES: Em vez da tela de sucesso, vai para o tracker
              router.go('/order/${order.id}', extra: order);
            }
          });
        }

        if (state.status == CheckoutStatus.error) {
          _handleError(state.errorMessage ?? 'Erro desconhecido');
        }
      },
      child: PopScope(
        canPop: !_isSuccess && _hasError, // Só pode voltar se deu erro
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _hasError ? _buildErrorState() : _buildLoadingState(),
            ),
          ),
        ),
      ),
    );
  }
}
