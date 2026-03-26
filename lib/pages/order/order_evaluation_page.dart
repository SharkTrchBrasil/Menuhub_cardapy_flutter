import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';

import 'package:totem/core/di.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/core/utils/app_logger.dart';

class OrderEvaluationPage extends StatefulWidget {
  final Order order;

  const OrderEvaluationPage({super.key, required this.order});

  @override
  State<OrderEvaluationPage> createState() => _OrderEvaluationPageState();
}

class _OrderEvaluationPageState extends State<OrderEvaluationPage> {
  int _currentStep = 1; // 1: Pedido, 2: Entrega
  int _orderRating = 0;
  int _deliveryRating = 0;
  final Set<String> _selectedTags = {};
  final Set<String> _deliverySelectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _deliveryCommentController =
      TextEditingController();
  bool _onlyForStore = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _deliveryCommentController.dispose();
    super.dispose();
  }

  final List<String> _improvementTags = [
    'Sabor',
    'Tempero',
    'Aparência',
    'Quantidade',
    'Embalagem',
    'Temperatura',
    'Ingredientes',
    'Ponto de cozimento',
    'Itens errados',
    'Uso excessivo de plástico/isopor',
  ];

  final List<String> _positiveTags = [
    'Comida Saborosa',
    'Bem temperada',
    'Boa aparência',
    'Boa quantidade',
    'Boa embalagem',
    'Temperatura certa',
    'Bons ingredientes',
    'No ponto certo',
    'Embalagem sustentável',
  ];

  final List<String> _deliveryImprovementTags = [
    'Demorou muito',
    'Não seguiu instruções',
    'Mal educado',
    'Cuidado com a bag',
    'Cuidado com o pedido',
  ];

  final List<String> _deliveryPositiveTags = [
    'Cuidado com o pedido',
    'Educação',
    'Cuidado com a bag',
    'Paciência',
    'Dentro do prazo',
  ];

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Muito ruim';
      case 2:
        return 'Ruim';
      case 3:
        return 'Razoável';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.black,
            size: 32,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              _currentStep == 1
                  ? 'AVALIAÇÃO DO PEDIDO'
                  : 'AVALIAÇÃO DA ENTREGA',
              style: const TextStyle(
                color: Color(0xFF3F3E3E),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        _currentStep == 1 ? Colors.black : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        _currentStep == 2 ? Colors.black : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _currentStep == 1 ? _buildOrderStep() : _buildDeliveryStep(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep == 1)
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyForStore = !_onlyForStore;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _onlyForStore,
                          onChanged:
                              (val) =>
                                  setState(() => _onlyForStore = val ?? false),
                          activeColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Enviar avaliação ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF717171),
                              ),
                              children: [
                                TextSpan(
                                  text: 'somente para a loja',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.black,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_currentStep == 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentStep = 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_ios,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voltar para avaliação do pedido',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue() ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            _currentStep == 1
                                ? (_onlyForStore
                                    ? 'Enviar avaliação'
                                    : 'Avaliar entrega')
                                : 'Enviar avaliação',
                            style: TextStyle(
                              color:
                                  _canContinue()
                                      ? Colors.white
                                      : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canContinue() {
    if (_currentStep == 1) return _orderRating > 0;
    return _deliveryRating > 0;
  }

  Future<void> _handleContinue() async {
    if (_currentStep == 1) {
      if (_orderRating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma nota para o pedido.'),
          ),
        );
        return;
      }

      if (_onlyForStore) {
        _submitFeedback();
        return;
      }

      setState(() {
        _currentStep = 2;
      });
    } else {
      if (_deliveryRating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma nota para a entrega.'),
          ),
        );
        return;
      }
      _submitFeedback();
    }
  }

  String get _buttonLabel {
    if (_currentStep == 1) {
      return _onlyForStore ? 'Enviar avaliação' : 'Avaliar entrega';
    }
    return 'Enviar avaliação';
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);

    try {
      final orderRepo = getIt<OrderRepository>();
      final storeComment = _commentController.text.trim();

      // 1. Enviar avaliação DA LOJA
      final orderResult = await orderRepo.submitOrderReview(
        orderPublicId: widget.order.publicId,
        stars: _orderRating,
        comment: storeComment.isEmpty ? null : storeComment,
        positiveTags: _selectedTags.toList(),
      );

      if (orderResult.isLeft) {
        throw orderResult.left;
      }

      // 2. Enviar avaliação DA ENTREGA (se houver e não for apenas loja)
      if (!_onlyForStore && _deliveryRating > 0) {
        final deliveryComment = _deliveryCommentController.text.trim();
        final deliveryResult = await orderRepo.submitDeliveryReview(
          orderPublicId: widget.order.publicId,
          likedDelivery: _deliveryRating >= 4,
          negativeTags:
              _deliveryRating < 4 ? _deliverySelectedTags.toList() : null,
          comment: deliveryComment.isEmpty ? null : deliveryComment,
        );

        if (deliveryResult.isLeft) {
          AppLogger.w(
            '⚠️ [RATING] Erro ao enviar avaliação da entrega: ${deliveryResult.left}',
          );
        }
      }

      // 3. ✅ GRANULAR: Marca o pedido como avaliado localmente no OrdersCubit
      _markOrderAsReviewed();

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obrigado! Sua avaliação foi enviada com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// ✅ Atualiza o pedido localmente no OrdersCubit marcando como avaliado
  void _markOrderAsReviewed() {
    try {
      final ordersCubit = getIt<OrdersCubit>();
      final updatedOrder = widget.order.copyWith(
        details: widget.order.details.copyWith(reviewed: true),
        storeRating: StoreRating(
          stars: _orderRating,
          comment:
              _commentController.text.trim().isEmpty
                  ? null
                  : _commentController.text.trim(),
          positiveTags: _selectedTags.toList(),
        ),
        deliveryRating:
            (!_onlyForStore && _deliveryRating > 0)
                ? DeliveryRating(
                  likedDelivery: _deliveryRating >= 4,
                  negativeTags: _deliverySelectedTags.toList(),
                  comment:
                      _deliveryCommentController.text.trim().isEmpty
                          ? null
                          : _deliveryCommentController.text.trim(),
                )
                : null,
      );
      ordersCubit.onRealtimeOrderUpdate(updatedOrder);
      AppLogger.i(
        '✅ [RATING] Pedido ${widget.order.shortId} marcado como avaliado localmente',
      );
    } catch (e) {
      AppLogger.w(
        '⚠️ [RATING] Erro ao marcar pedido como avaliado localmente: $e',
      );
    }
  }

  Widget _buildOrderStep() {
    final dateStr = _formatDate(widget.order.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildStoreAvatar(widget.order.merchant.logo, 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.merchant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lista de itens
            Expanded(
              child: Column(
                children:
                    widget.order.items
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F2F2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF717171),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            // Fotos empilhadas (estilo iFood)
            const SizedBox(width: 16),
            _buildProductImageStack(),
          ],
        ),
        if (widget.order.items.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${widget.order.items.length - 4} itens',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            'O que você achou do pedido? *',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Escolha de 1 a 5 estrelas para classificar.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isSelected = starIndex <= _orderRating;
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Se a nota mudou, limpa as tags selecionadas
                  if (_orderRating != starIndex) {
                    _selectedTags.clear();
                  }
                  _orderRating = starIndex;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isSelected ? Icons.star : Icons.star_outline,
                  color:
                      isSelected
                          ? const Color(0xFFFDCB3F)
                          : Colors.grey.shade300,
                  size: 48,
                ),
              ),
            );
          }),
        ),
        if (_orderRating > 0) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _getRatingLabel(_orderRating),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF717171),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.5),
        ],
        const SizedBox(height: 40),
        Text(
          _orderRating >= 4
              ? 'Do que você gostou? *'
              : 'O que pode melhorar? *',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              (_orderRating >= 4 ? _positiveTags : _improvementTags).map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.black.withOpacity(0.05)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isSelected ? Colors.black : const Color(0xFF3F3E3E),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            'Deixar comentário *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Conte mais sobre sua experiência...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryStep() {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildStoreAvatar(widget.order.merchant.logo, 80),
        const SizedBox(height: 16),
        Text(
          widget.order.merchant.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          'Entrega Própria',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 32),
        const Text(
          'A entrega foi *',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isSelected = starIndex <= _deliveryRating;
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Se a nota mudou, limpa as tags selecionadas
                  if (_deliveryRating != starIndex) {
                    _deliverySelectedTags.clear();
                  }
                  _deliveryRating = starIndex;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isSelected ? Icons.star : Icons.star_outline,
                  color:
                      isSelected
                          ? const Color(0xFFFDCB3F)
                          : Colors.grey.shade300,
                  size: 48,
                ),
              ),
            );
          }),
        ),
        if (_deliveryRating > 0) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _getRatingLabel(_deliveryRating),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF717171),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 40),
          Text(
            _deliveryRating >= 4
                ? 'Teve algo especial?'
                : 'O que pode melhorar? *',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _deliveryRating >= 4
                ? 'Escolha as opções que mais gostou'
                : 'Escolha de 1 a 5 estrelas para classificar.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children:
                (_deliveryRating >= 4
                        ? _deliveryPositiveTags
                        : _deliveryImprovementTags)
                    .map((tag) {
                      final isSelected = _deliverySelectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected)
                              _deliverySelectedTags.remove(tag);
                            else
                              _deliverySelectedTags.add(tag);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.black.withOpacity(0.05)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.black
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isSelected
                                      ? Colors.black
                                      : const Color(0xFF3F3E3E),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _deliveryCommentController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Comentário (opcional)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Muito ruim',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  'Excelente',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStoreAvatar(String? logoUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child:
            logoUrl != null && logoUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: _formatImageUrl(logoUrl),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorWidget:
                      (_, __, ___) =>
                          const Icon(Icons.store, color: Colors.grey),
                )
                : const Icon(Icons.store, color: Colors.grey),
      ),
    );
  }

  String _formatImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://menuhub-dev.s3.us-east-1.amazonaws.com/$url';
  }

  String _formatDate(DateTime date) {
    // Exemplo: Quarta, 04/03, às 07:51
    final months = [
      '',
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12',
    ];
    final weekdays = [
      '',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];

    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = months[date.month];
    final hourStr = date.hour.toString().padLeft(2, '0');
    final minStr = date.minute.toString().padLeft(2, '0');

    return '${weekdays[date.weekday]}, $dayStr/$monthStr, às $hourStr:$minStr';
  }

  Widget _buildProductImageStack() {
    final itemsToShow = widget.order.items.take(3).toList();
    if (itemsToShow.isEmpty) return const SizedBox();

    return SizedBox(
      width: 80,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children:
            itemsToShow.reversed.toList().asMap().entries.map((entry) {
              final item = entry.value;
              final imgUrl = _formatImageUrl(item.logoUrl ?? '');
              final hasImage = imgUrl.isNotEmpty && !imgUrl.contains('null');

              return Positioned(
                right: entry.key * 15.0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child:
                        hasImage
                            ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              errorWidget:
                                  (context, url, error) =>
                                      _buildPlaceholderImage(),
                            )
                            : _buildPlaceholderImage(),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF2F2F2),
      child: const Icon(Icons.fastfood, size: 18, color: Colors.grey),
    );
  }
}
