import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/di.dart';
import '../../repositories/order_repository.dart';

class OrderReviewPage extends StatefulWidget {
  final String orderPublicId;

  const OrderReviewPage({super.key, required this.orderPublicId});

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  int _selectedStars = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma avaliação')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final orderRepository = getIt<OrderRepository>();
    final result = await orderRepository.submitOrderReview(
      orderPublicId: widget.orderPublicId,
      stars: _selectedStars,
      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (result.isLeft) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.left)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar Pedido'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shopping_bag,
                      size: 64,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pedido #${widget.orderPublicId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Como foi sua experiência?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Sua avaliação',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStars = starNumber;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      starNumber <= _selectedStars ? Icons.star : Icons.star_border,
                      size: 48,
                      color: starNumber <= _selectedStars ? Colors.amber : Colors.grey.shade400,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            const Text(
              'Comentário (opcional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Conte-nos o que achou do pedido...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enviar Avaliação',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

