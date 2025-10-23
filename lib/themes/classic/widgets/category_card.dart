import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/models/category.dart';
import 'package:totem/themes/ds_theme.dart'; // Certifique-se de que DsTheme e DsThemeSwitcher estão corretos

import '../../ds_theme_switcher.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.category,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Removi a largura fixa (width: 100) para que o card se adapte ao conteúdo,
        // mas você pode reintroduzi-la se desejar cartões de largura uniforme.
        // Se você reintroduzir, certifique-se de que o conteúdo (ícone+texto) caiba.
        // width: 100, // Recomendo remover para um layout mais fluido em uma Row.
        margin: const EdgeInsets.only(right: 12), // Espaçamento entre os cards
        // Ajustei o padding vertical para que o conteúdo caiba melhor na altura de 60
        // da lista horizontal de categorias.
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.categoryBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.categoryBackgroundColor,
            width: 1,
          ),

        ),
        child: Row( // <-- Mudança principal: de Column para Row
          mainAxisSize: MainAxisSize.min, // Faz com que a Row ocupe o mínimo de largura necessário
          children: [
            // Imagem do ícone da categoria
            Image.network(
              category.imageUrl ?? 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png', // Placeholder se URL for nula
              width: 32, // <-- Reduzi o tamanho do ícone
              height: 32, // <-- Reduzi o tamanho do ícone
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 32), // Tamanho consistente para ícone de erro
            ),
            const SizedBox(width: 8), // <-- Espaçamento horizontal entre ícone e texto
            // Texto do nome da categoria
            Flexible( // Use Flexible para que o texto possa ser cortado com ellipsis se muito longo
              child: Text(
                category.name ?? '',
                textAlign: TextAlign.start, // Alinhe o texto à esquerda na Row
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? theme.primaryColor : theme.categoryTextColor, // Cor do texto baseada na seleção
                  overflow: TextOverflow.ellipsis, // Mantém a elipse se o texto for muito longo
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}