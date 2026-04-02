import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../models/order.dart';
import '../../cubit/orders_cubit.dart';

enum TopicActionType { cancel, info, submitForm }

enum CancellationStage { initial, loading, success }

class OrderHelpTopicPage extends StatefulWidget {
  final Order order;
  final String topicTitle;
  final String description;
  final TopicActionType actionType;
  final String buttonText;
  final IconData icon;

  const OrderHelpTopicPage({
    super.key,
    required this.order,
    required this.topicTitle,
    required this.description,
    required this.actionType,
    required this.buttonText,
    required this.icon,
  });

  @override
  State<OrderHelpTopicPage> createState() => _OrderHelpTopicPageState();
}

class _OrderHelpTopicPageState extends State<OrderHelpTopicPage> {
  final TextEditingController _reasonController = TextEditingController();
  CancellationStage _stage = CancellationStage.initial;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _handleAction() async {
    if (widget.actionType == TopicActionType.cancel || widget.actionType == TopicActionType.submitForm) {
      if (widget.actionType == TopicActionType.submitForm && _reasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, preencha o motivo.')),
        );
        return;
      }

      setState(() {
        _stage = CancellationStage.loading;
      });

      String finalReason = widget.topicTitle;
      if (_reasonController.text.trim().isNotEmpty) {
        finalReason += ' - ${_reasonController.text.trim()}';
      }

      final orderId = int.tryParse(widget.order.id.toString()) ?? 0;

      // Simulate network delay for the animation
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        context.read<OrdersCubit>().cancelOrder(
              orderId,
              reason: finalReason,
            );

        setState(() {
          _stage = CancellationStage.success;
        });
      }
    } else {
      // Info action -> "Falar com a loja"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A funcionalidade de chat com a loja será implementada em breve.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == CancellationStage.loading) {
      return _buildLoadingStage();
    }

    if (_stage == CancellationStage.success) {
      return _buildSuccessStage();
    }

    return _buildInitialStage();
  }

  Widget _buildLoadingStage() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar('Pedido realizado'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/delivery_waiting.json',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 32),
            const Text(
              'Por favor, aguarde',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F3E3E),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Estamos solicitando o cancelamento do seu pedido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF717171),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStage() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar('Pedido cancelado'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 100,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Seu pedido foi cancelado',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA1D2C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Fazer novo pedido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialStage() {
    // Show text field for both cancel and submitForm actions
    final showTextField = widget.actionType == TopicActionType.submitForm || 
                          widget.actionType == TopicActionType.cancel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(widget.order.lastStatus.toLowerCase() == 'pending' ? 'Pedido realizado' : 'Pedido confirmado'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 64,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.topicTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF717171),
                        height: 1.4,
                      ),
                    ),
                    if (showTextField) ...[
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _reasonController,
                          maxLines: 4,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: widget.actionType == TopicActionType.submitForm 
                                ? 'Conte o que aconteceu (obrigatório)'
                                : 'Conte o que aconteceu (opcional)',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            counterStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String subtitle) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: _stage == CancellationStage.initial
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
              onPressed: () => context.pop(),
            )
          : const SizedBox.shrink(),
      title: Column(
        children: [
          Text(
            (widget.order.customer?.name ?? 'CLIENTE').toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }
}
