// Em: lib/widgets/clear_cart_confirmation.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Mostra um diálogo (desktop) ou bottomsheet (mobile) perguntando se o usuário
/// deseja limpar o carrinho para adicionar itens de outra loja.
/// Retorna `true` se o usuário confirmou a limpeza, `false` se cancelou.
Future<bool> showClearCartConfirmation({
  required BuildContext context,
  required String newStoreName,
}) async {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  if (isMobile) {
    return await _showBottomSheet(context, newStoreName) ?? false;
  } else {
    return await _showDialog(context, newStoreName) ?? false;
  }
}

Future<bool?> _showDialog(BuildContext context, String newStoreName) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _ClearCartDialog(newStoreName: newStoreName),
  );
}

Future<bool?> _showBottomSheet(BuildContext context, String newStoreName) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ClearCartBottomSheet(newStoreName: newStoreName),
  );
}

class _ClearCartDialog extends StatelessWidget {
  final String newStoreName;
  
  const _ClearCartDialog({required this.newStoreName});
  
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 20),
              
              // Título
              Text(
                'Você só pode adicionar itens de um restaurante ou mercado por vez',
                style: theme.bodyTextStyle
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Descrição
              Text(
                'Deseja esvaziar a sacola e adicionar este item?',
                style: theme.smallTextStyle.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Botões
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Esvaziar sacola e adicionar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearCartBottomSheet extends StatelessWidget {
  final String newStoreName;
  
  const _ClearCartBottomSheet({required this.newStoreName});
  
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Ícone
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 32,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 20),
          
          // Título
          Text(
            'Você só pode adicionar itens de um restaurante ou mercado por vez',
            style: theme.bodyTextStyle
                .copyWith(fontWeight: FontWeight.w600, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Descrição
          Text(
            'Deseja esvaziar a sacola e adicionar este item?',
            style: theme.smallTextStyle.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Botões
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Esvaziar sacola e adicionar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper para verificar se o carrinho atual tem itens de outra loja
/// e se necessário, mostrar confirmação para limpar.
/// Retorna `true` se pode prosseguir com a adição, `false` se deve abortar.
Future<bool> canAddToCart({
  required BuildContext context,
  required int productStoreId,
}) async {
  final cartState = context.read<CartCubit>().state;
  final storeState = context.read<StoreCubit>().state;
  final currentStore = storeState.store;
  
  // Se o carrinho está vazio, pode adicionar
  if (cartState.cart.isEmpty || cartState.cart.items.isEmpty) {
    return true;
  }
  
  // Pega o storeId do primeiro item no carrinho
  final firstItem = cartState.cart.items.first;
  final cartStoreId = firstItem.product.storeId;
  
  // Se o produto é da mesma loja, pode adicionar
  if (cartStoreId == productStoreId || cartStoreId == 0) {
    return true;
  }
  
  // Carrinho tem itens de outra loja - mostra confirmação
  final shouldClear = await showClearCartConfirmation(
    context: context,
    newStoreName: currentStore?.name ?? 'esta loja',
  );
  
  if (shouldClear) {
    // Limpa o carrinho antes de adicionar
    await context.read<CartCubit>().clearCart();
    return true;
  }
  
  return false;
}
