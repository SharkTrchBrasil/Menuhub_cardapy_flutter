import 'package:flutter/material.dart';

import '../models/page_status.dart';
import 'loading.dart';


class AppPageStatusBuilder<T> extends StatelessWidget {
  const AppPageStatusBuilder({
    super.key,
    required this.status,
    this.tryAgain,
    required this.successBuilder,
    this.emptyBuilder,
  });

  final PageStatus status;
  final VoidCallback? tryAgain;
  final Widget Function(T) successBuilder;
  final Widget Function()? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PageStatusIdle _ => Container(),
      PageStatusLoading _ => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: AnimatedHourglassSequence()),
      ),
      PageStatusError status => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                status.message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              if (tryAgain != null) ...[

                const SizedBox(height: 16),

              ],
            ],
          ),
        ),
      ),
      PageStatusEmpty _ =>
        emptyBuilder?.call() ??
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum item encontrado.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

      PageStatusSuccess status => successBuilder(status.data),
    };
  }
}
