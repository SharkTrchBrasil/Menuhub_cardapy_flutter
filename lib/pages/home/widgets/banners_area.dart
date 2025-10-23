import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BannersArea extends StatefulWidget {
  const BannersArea({super.key});

  @override
  State<BannersArea> createState() => _BannersAreaState();
}

class _BannersAreaState extends State<BannersArea> {

  final PageController pageController = PageController(initialPage: 1000);

  Timer? timer;

  @override
  void initState() {
    super.initState();

    reset();
  }

  void reset() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      pageController.nextPage(duration: const Duration(milliseconds: 700), curve: Curves.ease);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 36 / 9,
      child: TapRegion(
        onTapInside: (_) {
          reset();
        },
        child: PageView.builder(
          controller: pageController,
          itemBuilder: (_, i) {
            return CachedNetworkImage(
              imageUrl: 'https://www.minhareceita.com.br/app/uploads/2021/05/shutterstock_1489640750-1.jpg',
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }
}
