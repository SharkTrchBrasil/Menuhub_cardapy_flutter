import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:totem/widgets/food_loading_animation.dart';


Function showLoading({String? message}) {
  // Exibe o loading com animação de comida
  final cancelLoading = BotToast.showCustomLoading(
    toastBuilder: (_) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: FoodLoadingCompact(
          size: 48,
          color: const Color(0xFFEA1D2C), // Cor Menuhub
        ),
      );
    },
    clickClose: false, // Impede qualquer interação enquanto o loading está visível
  );
  // Retorna a função que fecha o loading
  return cancelLoading;
}



Function showError(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  return BotToast.showText(
    text: message,
    contentColor: Colors.red,
    duration: duration,
  );
}

Function showSuccess(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  return BotToast.showText(
    text: message,
    contentColor: Colors.blue,
    duration: duration,
  );
}
Function showInfo(
    String message, {
      Duration duration = const Duration(seconds: 3),
    }) {
  return BotToast.showText(
    text: message,
    contentColor: Colors.amber, // ou Colors.grey dependendo do estilo
    duration: duration,
  );
}
