import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';


Function showLoading() {
  // Exibe o loading e bloqueia a tela
  final cancelLoading = BotToast.showCustomLoading(
    toastBuilder: (_) {
      return Center(
        child: CircularProgressIndicator(), // Indicador de loading circular
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
