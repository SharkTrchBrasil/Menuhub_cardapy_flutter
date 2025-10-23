// lib/pages/product/widgets/product_image_gallery.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../widgets/video_player_widget.dart';

class ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String? videoUrl;
  final double height;

  const ProductImageGallery({
    super.key,
    required this.imageUrls,
    this.videoUrl,
    this.height = 300,
  });

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Combina imagens e vídeo em uma lista de widgets
    final List<Widget> mediaWidgets = [];

    // Adiciona todas as imagens da galeria
    for (final imageUrl in widget.imageUrls) {
      mediaWidgets.add(_buildImageWidget(imageUrl));
    }

    // ✅ Adiciona o vídeo no final (se existir)
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      mediaWidgets.add(_buildVideoThumbnail(widget.videoUrl!));
    }

    // Se não tiver nenhuma mídia, mostra placeholder
    if (mediaWidgets.isEmpty) {
      return _buildPlaceholder();
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: mediaWidgets,
          ),
        ),

        // ✅ Indicador de páginas (bolinhas)
        if (mediaWidgets.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: mediaWidgets.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: Theme.of(context).primaryColor,
                dotColor: Colors.grey.shade300,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return GestureDetector(
      onTap: () {
        // ✅ TODO: Implementar player de vídeo em fullscreen
        _showVideoPlayer(context, videoUrl);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black87,
            child: const Icon(
              Icons.play_circle_outline,
              size: 80,
              color: Colors.white,
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Vídeo',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
      ),
    );
  }
  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
    );
  }
}