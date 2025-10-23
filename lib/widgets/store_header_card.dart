import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:totem/cubit/store_cubit.dart'; // Importe seu StoreCubit
import 'package:totem/models/store.dart';

class StoreHeaderCard extends StatelessWidget {
  /// Controla se o botão "Adicionar mais itens" deve ser exibido.
  final bool showAddItemsButton;

  /// A função a ser executada quando o botão for pressionado.
  final VoidCallback? onAddItemsPressed;

  /// Widget que busca o Store do Cubit e decide se mostra o conteúdo ou um placeholder.
  const StoreHeaderCard({
    super.key,
    this.showAddItemsButton = false,
    this.onAddItemsPressed,
  });

  @override
  Widget build(BuildContext context) {
    // O widget agora 'assiste' a mudanças no StoreCubit
    final store = context.watch<StoreCubit>().state.store;

    // ✅ SEGURANÇA: Se a loja for nula (carregando), mostra o placeholder.
    if (store == null) {
      return const _StoreHeaderPlaceholder();
    }

    // Se a loja existe, constrói o card real.
    return _StoreHeaderContent(
      store: store,
      showAddItemsButton: showAddItemsButton,
      onAddItemsPressed: onAddItemsPressed,
    );
  }
}

/// Widget interno que constrói o conteúdo real do card quando a loja já existe.
class _StoreHeaderContent extends StatelessWidget {
  final Store store;
  final bool showAddItemsButton;
  final VoidCallback? onAddItemsPressed;

  const _StoreHeaderContent({
    required this.store,
    required this.showAddItemsButton,
    this.onAddItemsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ✅ SEGURANÇA EXTRA: Lida com a possibilidade de 'image' ser nulo.
    final String? imageUrl = store.image?.url;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? Icon(
              Icons.store_mall_directory_outlined,
              color: Colors.grey.shade600,
              size: 24,
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // ✅ LÓGICA DO SUBTÍTULO DINÂMICO
                if (showAddItemsButton)
                  InkWell(
                    onTap: onAddItemsPressed,
                    child: Text(
                      'Adicionar mais itens',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (store.description != null && store.description!.isNotEmpty)
                  Text(
                    store.description!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de placeholder (esqueleto) com efeito de brilho (shimmer).
class _StoreHeaderPlaceholder extends StatelessWidget {
  const _StoreHeaderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}