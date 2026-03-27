import 'package:flutter/material.dart';

/// Skeleton shimmer screen que imita o layout da home page
/// com blocos cinza e efeito de luz passando (estilo iFood).
/// Usado como overlay enquanto a home carrega por baixo.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _controller.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ Header / Banner ═══
              _shimmerBox(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.all(0),
                borderRadius: 0,
              ),

              const SizedBox(height: 16),

              // ═══ Search bar ═══
              _shimmerBox(
                width: double.infinity,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                borderRadius: 22,
              ),

              const SizedBox(height: 20),

              // ═══ Category pills (horizontal) ═══
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(5, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _shimmerBox(
                        width: 70,
                        height: 32,
                        borderRadius: 16,
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // ═══ Featured banners (large cards) ═══
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _shimmerBox(
                        width: 260,
                        height: 160,
                        borderRadius: 12,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ═══ Section title ═══
              _shimmerBox(
                width: 140,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                borderRadius: 4,
              ),

              const SizedBox(height: 16),

              // ═══ Product list items ═══
              ...List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      _shimmerBox(
                        width: 80,
                        height: 80,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 12),
                      // Text lines
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _shimmerBox(
                              width: double.infinity,
                              height: 14,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 8),
                            _shimmerBox(
                              width: 180,
                              height: 12,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 8),
                            _shimmerBox(
                              width: 80,
                              height: 14,
                              borderRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      // ═══ Bottom nav bar mock ═══
      bottomNavigationBar: Container(
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(3, (i) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _shimmerBox(width: 24, height: 24, borderRadius: 4),
                const SizedBox(height: 4),
                _shimmerBox(width: 36, height: 10, borderRadius: 4),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Cria um bloco cinza com efeito shimmer (luz passando)
  Widget _shimmerBox({
    required double height,
    double? width,
    double borderRadius = 8,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
          end: Alignment(-1.0 + 2.0 * _controller.value + 0.6, 0),
          colors: const [
            Color(0xFFEEEEEE),
            Color(0xFFF5F5F5),
            Color(0xFFEEEEEE),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
