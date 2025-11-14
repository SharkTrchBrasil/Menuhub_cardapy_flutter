/// Offline Order Queue
/// ===================
/// Fila local para pedidos offline no Totem
/// 
/// Features:
/// - Persistência local (sqflite)
/// - Sincronização automática ao reconectar
/// - Validação de disponibilidade antes de enviar

import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/create_order_payload.dart';

enum OrderQueueStatus {
  pending,
  sending,
  sent,
  failed,
}

class OfflineOrder {
  final int? id;
  final CreateOrderPayload payload;
  final OrderQueueStatus status;
  final int retries;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? error;

  OfflineOrder({
    this.id,
    required this.payload,
    this.status = OrderQueueStatus.pending,
    this.retries = 0,
    DateTime? createdAt,
    this.sentAt,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payload': jsonEncode(payload.toJson()),
      'status': status.index,
      'retries': retries,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'error': error,
    };
  }

  factory OfflineOrder.fromMap(Map<String, dynamic> map) {
    return OfflineOrder(
      id: map['id'] as int?,
      payload: CreateOrderPayload.fromJson(jsonDecode(map['payload'] as String)),
      status: OrderQueueStatus.values[map['status'] as int],
      retries: map['retries'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      sentAt: map['sent_at'] != null 
          ? DateTime.parse(map['sent_at'] as String)
          : null,
      error: map['error'] as String?,
    );
  }
}

class OfflineOrderQueue {
  static final OfflineOrderQueue _instance = OfflineOrderQueue._internal();
  factory OfflineOrderQueue() => _instance;
  OfflineOrderQueue._internal();

  Database? _database;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_orders.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_orders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            retries INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            sent_at TEXT,
            error TEXT
          )
        ''');

        await db.execute('CREATE INDEX idx_status ON pending_orders(status)');
      },
    );

    _isInitialized = true;
    debugPrint('[OfflineOrderQueue] ✅ Inicializado');
  }

  Future<int> enqueue(CreateOrderPayload payload) async {
    await initialize();

    final order = OfflineOrder(payload: payload);
    final id = await _database!.insert('pending_orders', order.toMap());

    debugPrint('[OfflineOrderQueue] ✅ Pedido enfileirado (id: $id)');
    return id;
  }

  Future<List<OfflineOrder>> getPendingOrders() async {
    await initialize();

    final maps = await _database!.query(
      'pending_orders',
      where: 'status = ?',
      whereArgs: [OrderQueueStatus.pending.index],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => OfflineOrder.fromMap(map)).toList();
  }

  Future<void> markAsSent(int id) async {
    await initialize();

    await _database!.update(
      'pending_orders',
      {
        'status': OrderQueueStatus.sent.index,
        'sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsFailed(int id, String error, {int maxRetries = 3}) async {
    await initialize();

    final order = await getOrder(id);
    if (order == null) return;

    final newRetries = order.retries + 1;
    final newStatus = newRetries >= maxRetries
        ? OrderQueueStatus.failed
        : OrderQueueStatus.pending;

    await _database!.update(
      'pending_orders',
      {
        'status': newStatus.index,
        'retries': newRetries,
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<OfflineOrder?> getOrder(int id) async {
    await initialize();

    final maps = await _database!.query(
      'pending_orders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return OfflineOrder.fromMap(maps.first);
  }

  Future<void> remove(int id) async {
    await initialize();
    await _database!.delete('pending_orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await initialize();
    await _database!.delete('pending_orders');
  }

  Future<void> close() async {
    await _database?.close();
    _isInitialized = false;
  }
}

