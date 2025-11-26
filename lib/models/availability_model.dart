// lib/models/availability_model.dart
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// --- Funções Auxiliares (Helpers) ---

// Converte uma string "HH:MM" para um objeto TimeOfDay
TimeOfDay _timeFromString(String timeString) {
  try {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  } catch (e) {
    // Retorna um valor padrão seguro em caso de erro de formatação
    return const TimeOfDay(hour: 0, minute: 0);
  }
}

// Converte um objeto TimeOfDay para uma string "HH:MM"
String _timeToString(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}


// --- Modelos ---

// Representa um turno de horário (ex: 08:00 às 12:00)
class TimeShift extends Equatable {
  final int? id; // ID do banco de dados
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const TimeShift({
    this.id,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 18, minute: 0),
  });

  @override
  List<Object?> get props => [id, startTime, endTime];

  TimeShift copyWith({int? id, TimeOfDay? startTime, TimeOfDay? endTime}) {
    return TimeShift(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  // Constrói o objeto a partir do JSON da API
  factory TimeShift.fromJson(Map<String, dynamic> json) {
    return TimeShift(
      id: json['id'],
      startTime: _timeFromString(json['start_time']),
      endTime: _timeFromString(json['end_time']),
    );
  }

  // Gera o JSON para ser enviado para a API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_time': _timeToString(startTime),
      'end_time': _timeToString(endTime),
    };
  }
}

// Representa uma regra completa de agendamento
class ScheduleRule extends Equatable {
  final int? id; // ID do banco de dados
  final String localId; // ID local para controle na UI
  final List<bool> days; // [true, false, ...] -> Usado na UI
  final List<TimeShift> shifts;

  const ScheduleRule({
    this.id,
    required this.localId,
    this.days = const [false, false, false, false, false, false, false],
    this.shifts = const [TimeShift()],
  });

  // Construtor de conveniência para criar uma nova regra vazia
  factory ScheduleRule.empty() => ScheduleRule(localId: const Uuid().v4());

  @override
  List<Object?> get props => [id, localId, days, shifts];

  ScheduleRule copyWith({int? id, String? localId, List<bool>? days, List<TimeShift>? shifts}) {
    return ScheduleRule(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      days: days ?? this.days,
      shifts: shifts ?? this.shifts,
    );
  }

  // Constrói o objeto a partir do JSON da API
  factory ScheduleRule.fromJson(Map<String, dynamic> json) {
    // Converte a lista de inteiros [0, 1, 5] para [true, true, false, false, false, true, false]
    final daysFromApi = List<int>.from(json['days_of_week'] ?? []);
    final daysForUi = List.generate(7, (index) => daysFromApi.contains(index));

    return ScheduleRule(
      id: json['id'],
      localId: const Uuid().v4(), // Gera um ID local novo sempre que carrega
      days: daysForUi,
      shifts: (json['time_shifts'] as List<dynamic>?)
          ?.map((shiftJson) => TimeShift.fromJson(shiftJson))
          .toList() ?? [const TimeShift()],
    );
  }

  // Gera o JSON para ser enviado para a API
  Map<String, dynamic> toJson() {
    // Converte a lista de booleanos [true, true, ...] para uma lista de inteiros [0, 1, ...]
    final List<int> daysOfWeekIndices = [];
    for (int i = 0; i < days.length; i++) {
      if (days[i] == true) {
        daysOfWeekIndices.add(i);
      }
    }

    return {
      'id': id,
      // ✅ Nomes e formatos corretos para o backend
      'days_of_week': daysOfWeekIndices,
      'time_shifts': shifts.map((shift) => shift.toJson()).toList(),
    };
  }
}
