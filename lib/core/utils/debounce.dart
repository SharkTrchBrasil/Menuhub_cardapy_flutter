/// 🔒 DEBOUNCE & THROTTLE - PREVINE AÇÕES DUPLICADAS
/// ==================================================
/// Utilitários para prevenir cliques duplos e spam de requisições.

import 'dart:async';
import 'package:flutter/material.dart';

/// Debouncer - Executa ação após período de inatividade
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  /// Executa [action] após [delay] de inatividade
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancela execução pendente
  void cancel() {
    _timer?.cancel();
  }

  /// Limpa recursos
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler - Limita execuções por período
class Throttler {
  final Duration interval;
  DateTime? _lastExecution;

  Throttler({this.interval = const Duration(milliseconds: 1000)});

  /// Executa [action] no máximo uma vez por [interval]
  void run(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastExecution == null ||
        now.difference(_lastExecution!) >= interval) {
      _lastExecution = now;
      action();
    }
  }

  /// Reseta o throttler
  void reset() {
    _lastExecution = null;
  }
}

/// Mixin para StatefulWidget com debounce automático
mixin DebounceMixin<T extends StatefulWidget> on State<T> {
  final Map<String, Debouncer> _debouncers = {};

  /// Executa ação com debounce
  void debounce(
    String key,
    VoidCallback action, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debouncers[key] ??= Debouncer(delay: delay);
    _debouncers[key]!.run(action);
  }

  @override
  void dispose() {
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    _debouncers.clear();
    super.dispose();
  }
}

/// Botão com proteção contra cliques duplos
class SafeButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration cooldown;
  final bool showLoading;

  const SafeButton({
    super.key,
    required this.child,
    this.onPressed,
    this.cooldown = const Duration(milliseconds: 1000),
    this.showLoading = true,
  });

  @override
  State<SafeButton> createState() => _SafeButtonState();
}

class _SafeButtonState extends State<SafeButton> {
  bool _isProcessing = false;

  Future<void> _handlePress() async {
    if (_isProcessing || widget.onPressed == null) return;

    setState(() => _isProcessing = true);

    try {
      widget.onPressed!();
    } finally {
      // Aguarda cooldown antes de permitir novo clique
      await Future.delayed(widget.cooldown);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isProcessing ? null : _handlePress,
      child: AbsorbPointer(
        absorbing: _isProcessing,
        child: Opacity(
          opacity: _isProcessing ? 0.6 : 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              widget.child,
              if (_isProcessing && widget.showLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ElevatedButton com proteção contra cliques duplos
class SafeElevatedButton extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onPressed;
  final Duration cooldown;
  final ButtonStyle? style;

  const SafeElevatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.cooldown = const Duration(milliseconds: 1000),
    this.style,
  });

  @override
  State<SafeElevatedButton> createState() => _SafeElevatedButtonState();
}

class _SafeElevatedButtonState extends State<SafeElevatedButton> {
  bool _isProcessing = false;

  Future<void> _handlePress() async {
    if (_isProcessing || widget.onPressed == null) return;

    setState(() => _isProcessing = true);

    try {
      await widget.onPressed!();
    } finally {
      await Future.delayed(widget.cooldown);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _handlePress,
      style: widget.style,
      child: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : widget.child,
    );
  }
}

/// Extension para adicionar debounce a qualquer callback
extension DebounceExtension on VoidCallback {
  /// Retorna versão com debounce do callback
  VoidCallback debounced(Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, this);
    };
  }

  /// Retorna versão com throttle do callback
  VoidCallback throttled(Duration interval) {
    DateTime? lastExecution;
    return () {
      final now = DateTime.now();
      if (lastExecution == null || now.difference(lastExecution!) >= interval) {
        lastExecution = now;
        this();
      }
    };
  }
}

/// Controller para ações assíncronas com proteção
class AsyncActionController {
  bool _isProcessing = false;
  final Duration cooldown;

  AsyncActionController({this.cooldown = const Duration(milliseconds: 1000)});

  bool get isProcessing => _isProcessing;

  /// Executa ação assíncrona com proteção
  Future<T?> execute<T>(Future<T> Function() action) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    try {
      return await action();
    } finally {
      await Future.delayed(cooldown);
      _isProcessing = false;
    }
  }

  /// Reseta o controller
  void reset() {
    _isProcessing = false;
  }
}

/// Singleton para controlar ações globais (ex: finalizar pedido)
class GlobalActionLock {
  static final GlobalActionLock _instance = GlobalActionLock._internal();
  factory GlobalActionLock() => _instance;
  GlobalActionLock._internal();

  final Set<String> _lockedActions = {};

  /// Verifica se ação está bloqueada
  bool isLocked(String actionKey) => _lockedActions.contains(actionKey);

  /// Executa ação com lock global
  Future<T?> executeWithLock<T>(
    String actionKey,
    Future<T> Function() action, {
    Duration lockDuration = const Duration(seconds: 5),
  }) async {
    if (_lockedActions.contains(actionKey)) {
      return null;
    }

    _lockedActions.add(actionKey);
    try {
      return await action();
    } finally {
      // Remove lock após duração
      Future.delayed(lockDuration, () {
        _lockedActions.remove(actionKey);
      });
    }
  }

  /// Remove lock manualmente
  void unlock(String actionKey) {
    _lockedActions.remove(actionKey);
  }

  /// Limpa todos os locks
  void clear() {
    _lockedActions.clear();
  }
}

// Ações globais comuns
class ActionKeys {
  static const String checkout = 'checkout';
  static const String createOrder = 'create_order';
  static const String processPayment = 'process_payment';
  static const String applyCoupon = 'apply_coupon';
  static const String addToCart = 'add_to_cart';
}

