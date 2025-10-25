part of 'delivery_fee_cubit.dart';

// Classe base para todos os estados de taxa de entrega.
@immutable
abstract class DeliveryFeeState extends Equatable {
  // ✅ CAMPO MOVIDO PARA A CLASSE BASE
  final DeliveryType deliveryType;

  const DeliveryFeeState({this.deliveryType = DeliveryType.delivery});

  @override
  List<Object> get props => [deliveryType];
}

// Estado Inicial: Nada foi calculado ainda.
class DeliveryFeeInitial extends DeliveryFeeState {
  // ✅ PASSA O deliveryType PARA O CONSTRUTOR PAI
  const DeliveryFeeInitial({super.deliveryType});
}

// Estado de Carregamento: O cálculo está em andamento.
class DeliveryFeeLoading extends DeliveryFeeState {
  const DeliveryFeeLoading({super.deliveryType});
}

// Estado de Sucesso: O cálculo foi concluído.
class DeliveryFeeLoaded extends DeliveryFeeState {
  final double deliveryFee;
  final bool isFree;

  const DeliveryFeeLoaded({
    required this.deliveryFee,
    required this.isFree,
    required super.deliveryType, // ✅ USA O PARÂMETRO DA CLASSE PAI
  });

  @override
  List<Object> get props => [deliveryFee, isFree, deliveryType];

  DeliveryFeeLoaded copyWith({
    double? deliveryFee,
    bool? isFree,
    DeliveryType? deliveryType,
  }) {
    return DeliveryFeeLoaded(
      deliveryFee: deliveryFee ?? this.deliveryFee,
      isFree: isFree ?? this.isFree,
      deliveryType: deliveryType ?? this.deliveryType,
    );
  }
}

// Estado de Erro: Ocorreu um problema no cálculo.
class DeliveryFeeError extends DeliveryFeeState {
  final String message;
  const DeliveryFeeError(this.message, {super.deliveryType});

  @override
  List<Object> get props => [message, deliveryType];
}

// Estado Específico: O cálculo precisa de um endereço para continuar.
class DeliveryFeeRequiresAddress extends DeliveryFeeState {
  const DeliveryFeeRequiresAddress({super.deliveryType});
}