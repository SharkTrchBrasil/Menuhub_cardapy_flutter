import 'package:flutter/foundation.dart';

/// Controller para gerenciar navegação entre tabs
/// Permite que widgets filhos mudem a tab ativa
class MainTabController extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void changeTab(int index) {
    // ✅ Permite mudar mesmo para a mesma tab (para garantir sincronização)
    // Apenas 3 tabs: Home (0), Notificações (1), Cardápio (2)
    if (index >= 0 && index < 3) {
      _currentIndex = index;
      // ✅ Sempre notifica para garantir sincronização, mesmo se for a mesma tab
      notifyListeners();
    }
  }
  
  // ✅ Método para forçar sincronização do estado atual
  void syncState() {
    notifyListeners();
  }

  void goToHome() => changeTab(0);
  void goToNotifications() => changeTab(1);
  void goToMenu() => changeTab(2);
}

