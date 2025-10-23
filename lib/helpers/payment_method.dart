import '../models/delivery_type.dart';
// Supondo que você tenha este enum
import 'package:totem/models/payment_method.dart';

// Usando uma Extension para adicionar um novo método à lista de PaymentMethodGroup
extension PaymentGroupFiltering on List<PaymentMethodGroup> {

  /// Filtra a lista de grupos de pagamento para mostrar apenas as opções
  /// ativas e disponíveis para o tipo de entrega selecionado.
  List<PaymentMethodGroup> filterFor(DeliveryType deliveryType) {
    // 1. Faz uma cópia profunda para não modificar a lista original no Cubit
    final groupsCopy = map((group) => group.deepCopy()).toList();

    // 2. Filtra os métodos de pagamento dentro de cada categoria e grupo
    for (var group in groupsCopy) {
      for (var category in group.categories) {
        category.methods.removeWhere((method) {
          final activation = method.activation;
          if (activation == null || !activation.isActive) {
            return true; // Remove se não tiver ativação ou não estiver ativo
          }
          if (deliveryType == DeliveryType.delivery && !activation.isForDelivery) {
            return true; // Remove se for delivery e o método não for para delivery
          }
          if (deliveryType == DeliveryType.pickup && !activation.isForPickup) {
            return true; // Remove se for retirada e o método não for para retirada
          }
          return false; // Mantém o método
        });
      }
    }

    // 3. Remove categorias que ficaram vazias após o filtro
    for (var group in groupsCopy) {
      group.categories.removeWhere((category) => category.methods.isEmpty);
    }

    // 4. Remove grupos que ficaram vazios após o filtro
    groupsCopy.removeWhere((group) => group.categories.isEmpty);

    return groupsCopy;
  }
}