import 'package:flutter/foundation.dart';

/// Controller para gerenciar navegação entre tabs
/// Permite que widgets filhos mudem a tab ativa
class MainTabController extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void changeTab(int index) {
    // ✅ Permite mudar mesmo para a mesma tab (para garantir sincronização)
    // Isso resolve o bug onde o home não funciona após limpar carrinho
    if (index >= 0 && index < 4) {
      _currentIndex = index;
      // ✅ Sempre notifica para garantir sincronização, mesmo se for a mesma tab
      // Isso resolve problemas quando o estado fica inconsistente após operações como clearCart
      notifyListeners();
    }
  }
  
  // ✅ Método para forçar sincronização do estado atual
  void syncState() {
    notifyListeners();
  }

  void goToHome() => changeTab(0);
  void goToCart() => changeTab(1);
  void goToOrders() => changeTab(2);
  void goToProfile() => changeTab(3);
}

