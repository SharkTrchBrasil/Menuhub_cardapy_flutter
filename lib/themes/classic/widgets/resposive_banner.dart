import 'package:flutter/material.dart';

import '../../../models/banners.dart';

class ResponsiveBannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const ResponsiveBannerCarousel({super.key, required this.banners});

  @override
  State<ResponsiveBannerCarousel> createState() => _ResponsiveBannerCarouselState();
}

class _ResponsiveBannerCarouselState extends State<ResponsiveBannerCarousel> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsividade simples por largura
    double height;
    EdgeInsets padding;
    double borderRadius;

    if (screenWidth < 600) {
      // MOBILE
      height = 160;
      padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      borderRadius = 12;
    } else if (screenWidth < 1024) {
      // TABLET
      height = 180;
      padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 12);
      borderRadius = 16;
    } else {
      // DESKTOP
      height = 200;
      padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
      borderRadius = 20;
    }

    // ✅ NOVO: Verifica se há banners configurados
    final bool hasCustomBanners = widget.banners.isNotEmpty;

    return Padding(
      padding: padding,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: hasCustomBanners
                ? PageView.builder(
                    itemCount: widget.banners.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final banner = widget.banners[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: Image.network(
                          banner.image!.url!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // ✅ FALLBACK: Se erro ao carregar, usa banner padrão
                            return _buildDefaultBanner(height, borderRadius);
                          },
                        ),
                      );
                    },
                  )
                : // ✅ NOVO: Banner padrão quando não há banners configurados
                  _buildDefaultBanner(height, borderRadius),
          ),
          const SizedBox(height: 8),
          // ✅ CORREÇÃO: Só mostra indicadores se houver múltiplos banners
          if (hasCustomBanners && widget.banners.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 12 : 8,
                  height: currentIndex == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentIndex == index ? Colors.blueAccent : Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// ✅ NOVO: Widget de banner padrão
  Widget _buildDefaultBanner(double height, double borderRadius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/banner.jpg',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // ✅ Fallback final: container cinza se nem o asset existir
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 50,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }
}
