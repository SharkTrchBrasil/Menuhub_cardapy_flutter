import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';

import '../models/page_status.dart';
import '../widgets/app_toasts.dart';

class AppFetchByIdController<E, T> extends ChangeNotifier {
  AppFetchByIdController({
    required this.id,
    required this.fetch,
    this.errorHandler,
  }) {
    _initialize();
  }

  final int id;
  final Future<Either<E, T?>> Function(int) fetch;
  final Function(E)? errorHandler;

  PageStatus status = PageStatusIdle();

  Future<void> _initialize() async {
    status = PageStatusLoading();
    notifyListeners();

    final result = await fetch(id);
    if (result.isRight) {
      final data = result.right;
      if (data != null) {
        status = PageStatusSuccess(data);
      } else {
        status = PageStatusError('Dados não encontrados.');
      }
    } else {
      if (errorHandler != null) {
        errorHandler!(result.left);
      }
      status = PageStatusError('Erro ao carregar os dados.');
    }
    notifyListeners();
  }

  Future<void> reload() async => _initialize();
}
