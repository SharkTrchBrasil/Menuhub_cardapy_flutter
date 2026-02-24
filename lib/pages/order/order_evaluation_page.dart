import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';

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
  final TextEditingController _commentController = TextEditingController();
  bool _onlyForStore = false;

  final List<String> _improvementTags = [
    'Sabor', 'Tempero', 'Aparência', 'Quantidade', 'Embalagem', 
    'Temperatura', 'Ingredientes', 'Ponto de cozimento', 
    'Itens errados', 'Uso excessivo de plástico/isopor'
  ];

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1: return 'Muito ruim';
      case 2: return 'Ruim';
      case 3: return 'Razoável';
      case 4: return 'Bom';
      case 5: return 'Excelente';
      default: return '';
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
          icon: const Icon(Icons.close, color: Color(0xFFEA1D2C)),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              _currentStep == 1 ? 'AVALIAÇÃO DO PEDIDO' : 'AVALIAÇÃO DA ENTREGA',
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
                    color: _currentStep == 1 ? const Color(0xFFEA1D2C) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentStep == 2 ? const Color(0xFFEA1D2C) : Colors.grey.shade300,
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
              Row(
                children: [
                  Checkbox(
                    value: _onlyForStore,
                    onChanged: (val) => setState(() => _onlyForStore = val ?? false),
                    activeColor: const Color(0xFFEA1D2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Enviar avaliação ',
                        style: TextStyle(fontSize: 13, color: Color(0xFF717171)),
                        children: [
                          TextSpan(
                            text: 'somente para a loja',
                            style: TextStyle(color: Color(0xFFEA1D2C), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFEA1D2C), size: 20),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue() ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA1D2C),
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _currentStep == 1 ? 'Enviar avaliação' : 'Finalizar',
                    style: TextStyle(
                      color: _canContinue() ? Colors.white : Colors.grey.shade400,
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

  void _handleContinue() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else {
      // Finalizar
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obrigado pela sua avaliação!')),
      );
    }
  }

  Widget _buildOrderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStoreAvatar(widget.order.merchant.logo, 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.merchant.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Ontem, às 22:55', // Mock
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFEA1D2C)),
          ],
        ),
        const SizedBox(height: 24),
        ...widget.order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.name.toUpperCase(), style: const TextStyle(fontSize: 13, color: Color(0xFF717171))),
              ),
            ],
          ),
        )),
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
            return GestureDetector(
              onTap: () => setState(() => _orderRating = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  starIndex <= _orderRating ? Icons.star : Icons.star_outline,
                  color: starIndex <= _orderRating ? const Color(0xFFFDCB3F) : Colors.grey.shade300,
                  size: 48,
                ),
              ),
            );
          }),
        ),
        if (_orderRating > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _getRatingLabel(_orderRating),
                style: const TextStyle(fontSize: 14, color: Color(0xFF717171)),
              ),
            ),
          ),
        const SizedBox(height: 40),
        const Text(
          'O que pode melhorar? *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _improvementTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) _selectedTags.remove(tag);
                  else _selectedTags.add(tag);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEA1D2C).withOpacity(0.05) : const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEA1D2C) : Colors.transparent,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? const Color(0xFFEA1D2C) : const Color(0xFF3F3E3E),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        const Text(
          'Deixar comentário *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Conte mais sobre sua experiência...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF2F2F2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        _buildStoreAvatar(widget.order.merchant.logo, 80),
        const SizedBox(height: 16),
        Text(
          widget.order.merchant.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Entrega Própria',
          style: TextStyle(fontSize: 14, color: Color(0xFF717171)),
        ),
        const SizedBox(height: 48),
        const Text(
          'A entrega foi *',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _deliveryRating = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  starIndex <= _deliveryRating ? Icons.star : Icons.star_outline,
                  color: starIndex <= _deliveryRating ? const Color(0xFFFDCB3F) : Colors.grey.shade300,
                  size: 48,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Muito ruim', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            Text('Excelente', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
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
        child: logoUrl != null && logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _formatImageUrl(logoUrl),
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorWidget: (_, __, ___) => const Icon(Icons.store, color: Colors.grey),
              )
            : const Icon(Icons.store, color: Colors.grey),
      ),
    );
  }

  String _formatImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://menuhub-dev.s3.us-east-1.amazonaws.com/$url';
  }
}
