// lib/pages/order/widgets/order_rating_widget.dart
// ✅ Widget Avaliação - Estilo iFood
// Aparece apenas para pedidos concluídos dentro do prazo

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderRatingWidget extends StatefulWidget {
  final String? storeLogo;
  final String storeName;
  final bool isExpired;
  final bool alreadyRated;
  final int? existingRating;
  final ValueChanged<int>? onRatingChanged;

  const OrderRatingWidget({
    super.key,
    this.storeLogo,
    required this.storeName,
    this.isExpired = false,
    this.alreadyRated = false,
    this.existingRating,
    this.onRatingChanged,
  });

  @override
  State<OrderRatingWidget> createState() => _OrderRatingWidgetState();
}

class _OrderRatingWidgetState extends State<OrderRatingWidget> {
  int _hoveredStar = 0;
  int _selectedStar = 0;

  @override
  void initState() {
    super.initState();
    _selectedStar = widget.existingRating ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Não mostra se já avaliou ou expirou
    if (widget.alreadyRated && widget.existingRating != null) {
      return _buildAlreadyRated();
    }
    
    if (widget.isExpired) {
      return _buildExpired();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pergunta
          const Text(
            'Quantas estrelas a loja merece?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          
          // Logo + Estrelas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo da loja
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: widget.storeLogo != null && widget.storeLogo!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.storeLogo!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.store,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ),
                      )
                    : Icon(Icons.store, color: Colors.grey[400], size: 20),
              ),
              const SizedBox(width: 16),
              
              // 5 Estrelas
              Row(
                children: List.generate(5, (index) {
                  final starNumber = index + 1;
                  final isActive = starNumber <= (_hoveredStar > 0 ? _hoveredStar : _selectedStar);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStar = starNumber;
                      });
                      widget.onRatingChanged?.call(starNumber);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isActive ? Icons.star : Icons.star_border,
                        color: isActive ? Colors.amber : Colors.grey[400],
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyRated() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Obrigado pela sua avaliação!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < (widget.existingRating ?? 0) 
                          ? Icons.star 
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpired() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'O prazo para avaliar este pedido expirou.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
