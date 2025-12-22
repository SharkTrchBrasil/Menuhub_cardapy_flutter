// lib/models/menu/menu_response.dart
// Modelo para resposta do endpoint de menu no novo formato

import 'package:equatable/equatable.dart';
import 'package:totem/models/menu/menu_data.dart';

/// Resposta completa do endpoint de menu
class MenuResponse extends Equatable {
  final String code;
  final String? message;
  final String? timestamp;
  final MenuData data;

  const MenuResponse({
    required this.code,
    this.message,
    this.timestamp,
    required this.data,
  });

  factory MenuResponse.fromJson(Map<String, dynamic> json) {
    return MenuResponse(
      code: json['code'] as String? ?? '00',
      message: json['message'] as String?,
      timestamp: json['timestamp'] as String?,
      data: MenuData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'timestamp': timestamp,
      'data': data.toJson(),
    };
  }

  @override
  List<Object?> get props => [code, message, timestamp, data];
}












