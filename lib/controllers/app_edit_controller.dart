import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';

import '../models/page_status.dart';
import '../widgets/app_toasts.dart';


class AppEditController<E, T> extends ChangeNotifier {
  AppEditController({
    required this.id,
    required this.fetch,
    required this.empty,
    required this.save,
    this.errorHandler,
  }) {
    _initialize();
  }

  final int? id;
  final Future<Either<E, T?>> Function(int) fetch;
  final Future<Either<E, T>> Function(T) save;
  final T Function() empty;
  final Function(E)? errorHandler;

  PageStatus status = PageStatusIdle();

  Future<void> _initialize() async {

    if (id == null) {
      status = PageStatusSuccess(empty());
      notifyListeners();
      return;
    }

    status = PageStatusLoading();
    notifyListeners();

    final result = await fetch(id!);
    if (result.isRight) {
      status = PageStatusSuccess(result.right ?? empty());
    } else {
      status = PageStatusError('Falha ao carregar!');
    }
    notifyListeners();
  }

  void onChanged(T newData) {
    status = PageStatusSuccess(newData);
    notifyListeners();
  }

  Future<Either<void, T>> saveData() async {
    final l = showLoading();
    final result = await save((status as PageStatusSuccess).data);
    l();
    if (result.isLeft) {
      if(errorHandler != null) {
        errorHandler!.call(result.left);
      } else {
        showError('Falha ao salvar. Por favor, tente novamente!');
      }
      return Left(null);
    } else {
      showSuccess('Salvo com sucesso!');
      status = PageStatusSuccess(result.right);
      notifyListeners();
      return Right(result.right);
    }
  }

  Future<void> reloadData() async {
    if (id == null) {
      status = PageStatusError('ID não disponível para recarregar.');
      notifyListeners();
      return;
    }

    status = PageStatusLoading();
    notifyListeners();

    final result = await fetch(id!);
    if (result.isRight) {
      status = PageStatusSuccess(result.right ?? empty());
    } else {
      status = PageStatusError('Falha ao recarregar!');
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await _initialize();
  }

  T get data => (status as PageStatusSuccess<T>).data;

}
