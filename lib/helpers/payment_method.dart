import '../models/delivery_type.dart';
// Supondo que você tenha este enum
import 'package:totem/models/payment_method.dart';

// Usando uma Extension para adicionar um novo método à lista de PaymentMethodGroup
extension PaymentGroupFiltering on List<PaymentMethodGroup> {

  /// Filtra a lista de grupos de pagamento para mostrar apenas as opções
  /// ativas e disponíveis para o tipo de entrega selecionado.
  // ✅ ATUALIZADO: PaymentMethodGroup agora tem methods diretamente (sem categories)
  List<PaymentMethodGroup> filterFor(DeliveryType deliveryType) {
    // 1. Faz uma cópia profunda para não modificar a lista original no Cubit
    final groupsCopy = map((group) => group.deepCopy()).toList();

    // 2. Filtra os métodos de pagamento dentro de cada grupo
    for (var group in groupsCopy) {
      group.methods.removeWhere((method) {
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
        // if (deliveryType == DeliveryType. && !activation.isForInStore) {
        //   return true; // Remove se for na loja e o método não for para na loja
        // }
        return false; // Mantém o método
      });
    }

    // 3. Remove grupos que ficaram vazios após o filtro
    groupsCopy.removeWhere((group) => group.methods.isEmpty);

    return groupsCopy;
  }
}

/// Extension para calcular taxas de pagamento
extension PaymentFeeCalculation on PlatformPaymentMethod {
  /// ✅ ENTERPRISE: Calcula a taxa de pagamento baseada no subtotal
  /// ✅ Usa fee_value e fee_type tipados do activation (prioridade) ou details (fallback)
  /// Retorna o valor da taxa em reais (double)
  double calculateFee(double subtotalInReais) {
    final activation = this.activation;
    if (activation == null) return 0.0;
    
    // ✅ NOVO: Prioriza campos tipados do activation
    final feeValue = activation.feeValue;
    final feeType = activation.feeType;
    
    // ✅ Fallback: Se não tiver campos tipados, lê de details
    final details = activation.details ?? {};
    final hasFee = details['has_fee'] as bool? ?? false;
    final feeValueFromDetails = details['fee_value'] as num?;
    final feeTypeFromDetails = details['fee_type'] as String?;
    
    // ✅ Usa campos tipados se disponíveis, senão usa details
    final finalFeeValue = feeValue ?? feeValueFromDetails;
    final finalFeeType = feeType ?? feeTypeFromDetails;
    
    if (!hasFee && feeValue == null && feeValueFromDetails == null) {
      return 0.0;
    }
    
    if (finalFeeValue == null || finalFeeValue <= 0) {
      return 0.0;
    }
    
    // ✅ CORREÇÃO: fee_value está em reais (Numeric(10, 2) no backend)
    // ✅ UNIFICADO: Sempre usa feeValue e feeType (deprecado feePercentage)
    if (finalFeeType == 'fixed' || finalFeeType == 'R\$' || finalFeeType == '\$') {
      // Taxa fixa: fee_value já está em reais (ex: 5.50 para R$ 5,50)
      return finalFeeValue.toDouble();
    } else if (finalFeeType == '%' || finalFeeType == 'percentage') {
      // Taxa percentual: calcula sobre o subtotal
      // fee_value está em porcentagem (ex: 2.5 para 2.5%)
      return (subtotalInReais * finalFeeValue.toDouble()) / 100.0;
    }
    
    // ✅ Se não tem tipo definido, retorna 0 (não usa feePercentage como fallback)
    return 0.0;
  }
  
  /// ✅ CORREÇÃO: Retorna a chave PIX estática se configurada
  /// ✅ CRÍTICO: Verifica apenas se pix_key existe e method_type é MANUAL_PIX
  String? getStaticPixKey() {
    // ✅ Verifica se é método MANUAL_PIX
    if (this.method_type != 'MANUAL_PIX') return null;
    
    final activation = this.activation;
    if (activation == null) return null;
    
    final details = activation.details ?? {};
    // ✅ CORREÇÃO: Não verifica static_pix_enabled (backend não envia esse campo)
    // Apenas verifica se pix_key existe
    if (details['pix_key'] != null) {
      final pixKey = details['pix_key'].toString();
      if (pixKey.isNotEmpty) {
        return pixKey;
      }
    }
    
    return null;
  }
  
  /// ✅ CORREÇÃO: Retorna o tipo da chave PIX se configurada
  String? getStaticPixKeyType() {
    // ✅ Verifica se é método MANUAL_PIX
    if (this.method_type != 'MANUAL_PIX') return null;
    
    final activation = this.activation;
    if (activation == null) return null;
    
    final details = activation.details ?? {};
    // ✅ CORREÇÃO: Não verifica static_pix_enabled (backend não envia esse campo)
    // Apenas retorna pix_key_type se existir
    if (details['pix_key_type'] != null) {
      return details['pix_key_type'].toString();
    }
    
    return null;
  }
}