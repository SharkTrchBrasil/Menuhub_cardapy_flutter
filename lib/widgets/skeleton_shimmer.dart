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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildDesktopShimmer();
        }
        return _buildMobileShimmer();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE SHIMMER (Matching PremiumStoreHeader)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileShimmer() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Stack (Banner + Card + Logo) ───
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 1. Banner
                _shimmerBox(
                  width: double.infinity,
                  height: 200,
                  borderRadius: 0,
                ),

                // 2. Search Button Mock (Top Right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 16,
                  child: _shimmerBox(
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                    opacity: 0.5,
                  ),
                ),

                // 3. Info Card
                Padding(
                  padding: const EdgeInsets.only(top: 150, left: 16, right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 45), // Space for logo
                        // Name line
                        _shimmerBox(width: 180, height: 20, borderRadius: 4),
                        const SizedBox(height: 8),
                        // Distance/Min order line
                        _shimmerBox(width: 120, height: 12, borderRadius: 3),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        // Rating line
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              _shimmerBox(
                                width: 18,
                                height: 18,
                                borderRadius: 4,
                              ),
                              const SizedBox(width: 8),
                              _shimmerBox(
                                width: 100,
                                height: 14,
                                borderRadius: 4,
                              ),
                              const Spacer(),
                              _shimmerBox(
                                width: 24,
                                height: 24,
                                borderRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Delivery line
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _shimmerBox(
                                width: 200,
                                height: 14,
                                borderRadius: 4,
                              ),
                              const SizedBox(height: 6),
                              _shimmerBox(
                                width: 150,
                                height: 10,
                                borderRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Logo Shimmer (Circle)
                Positioned(
                  top: 110,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: _shimmerBox(
                      width: 80,
                      height: 80,
                      borderRadius: 40,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Sections ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _shimmerBox(width: 140, height: 20, borderRadius: 4),
            ),

            const SizedBox(height: 16),

            // Products Grid Mock
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.8,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _shimmerBox(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _shimmerBox(width: 100, height: 12, borderRadius: 3),
                      const SizedBox(height: 6),
                      _shimmerBox(width: 60, height: 14, borderRadius: 3),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP SHIMMER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopShimmer() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 1. Desktop Banner
                _shimmerBox(
                  width: double.infinity,
                  height: 280,
                  borderRadius: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),

                const SizedBox(height: 24),

                // 2. Desktop Header Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _shimmerBox(width: 100, height: 100, borderRadius: 50),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _shimmerBox(
                              width: 300,
                              height: 32,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 12),
                            _shimmerBox(
                              width: 200,
                              height: 16,
                              borderRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      _shimmerBox(width: 150, height: 44, borderRadius: 22),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // 3. Grid of products
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 32,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _shimmerBox(
                                  width: double.infinity,
                                  height: 16,
                                  borderRadius: 4,
                                ),
                                const SizedBox(height: 8),
                                _shimmerBox(
                                  width: 120,
                                  height: 12,
                                  borderRadius: 4,
                                ),
                                const SizedBox(height: 16),
                                _shimmerBox(
                                  width: 80,
                                  height: 18,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          _shimmerBox(width: 100, height: 100, borderRadius: 8),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _controller.value, -0.3),
            end: Alignment(-1.0 + 2.0 * _controller.value + 0.6, 0.3),
            colors: const [
              Color(0xFFEBEBEB),
              Color(0xFFF9F9F9),
              Color(0xFFEBEBEB),
            ],
            stops: const [0.1, 0.5, 0.9],
          ),
        ),
      ),
    );
  }
}
