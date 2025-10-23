import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;


import '../models/page_status.dart';

class AppListController<T> extends ChangeNotifier {

  AppListController({required this.fetch}) {
    _initialize();
  }

  final Future<Either<void, List<T>>> Function() fetch;

  PageStatus status = PageStatusIdle();

  Future<void> _initialize() async {
    status = PageStatusLoading();
    notifyListeners();

    final result = await fetch();


    // if(result.isLeft) {
    //   status = PageStatusError('Falha ao carregar!');
    // } else {
    //   // *** MUDANÇA AQUI: Remova a condição para PageStatusEmpty ***
    //   // Se a requisição foi um sucesso (result.isRight),
    //   // sempre definimos o status como PageStatusSuccess com os dados,
    //   // mesmo que a lista esteja vazia.
    //   status = PageStatusSuccess<List<T>>(result.right);
    // }


    if(result.isLeft) {
      status = PageStatusError('Falha ao carregar!');
    } else {
      if(result.right.isEmpty) {
        status = PageStatusEmpty('Nenhum item encontrado');
      } else {
        status = PageStatusSuccess<List<T>>(result.right);
      }
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await _initialize();
  }

  List<T> get items {
    if (status is PageStatusSuccess<List<T>>) {
      return (status as PageStatusSuccess<List<T>>).data;
    }
    return [];
  }

  // --- NOVO MÉTODO AQUI ---
  /// Notifica os listeners de que a lista `items` foi atualizada localmente,
  /// sem acionar uma nova busca ao backend.
  void updateLocally() {
    // Apenas chamamos notifyListeners() se o status atual já é de sucesso.
    // Isso evita notificar se, por exemplo, o controller está em estado de erro ou carregando.
    // Se o status for de sucesso, garantimos que a lista interna já contém os dados.
    if (status is PageStatusSuccess<List<T>>) {
      notifyListeners();
    }
  }

  /// Remove um item da lista localmente com base em um teste e notifica os listeners.
  /// Retorna true se o item foi encontrado e removido, false caso contrário.
  bool removeLocally(bool Function(T) test) { // Changed Predicate<T> to bool Function(T)
    if (status is PageStatusSuccess<List<T>>) {
      final successStatus = status as PageStatusSuccess<List<T>>;
      final initialLength = successStatus.data.length;
      successStatus.data.removeWhere(test);
      if (successStatus.data.length < initialLength) {
        notifyListeners(); // Notifica apenas se algo foi realmente removido
        return true;
      }
    }
    return false;
  }

}