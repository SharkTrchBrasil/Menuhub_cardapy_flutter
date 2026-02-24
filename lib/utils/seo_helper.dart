// lib/utils/seo_helper.dart
// Utilitário para atualizar SEO dinamicamente (título, descrição, etc.)
// ✅ Migrado para package:web para compatibilidade com WASM

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Helper para atualizar informações de SEO dinamicamente no Flutter Web
class SeoHelper {
  /// Atualiza o título da página (aparece na aba do navegador)
  static void setTitle(String title) {
    if (kIsWeb) {
      web.document.title = title;
    }
  }

  /// Atualiza a meta description (importante para SEO)
  static void setDescription(String description) {
    if (kIsWeb) {
      _setMetaTag('description', description);
    }
  }

  /// Atualiza as meta tags do Open Graph (compartilhamento em redes sociais)
  static void setOpenGraph({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    if (kIsWeb) {
      _setMetaTag('og:title', title, isProperty: true);
      _setMetaTag('og:description', description, isProperty: true);
      if (imageUrl != null) {
        _setMetaTag('og:image', imageUrl, isProperty: true);
      }
    }
  }

  /// Atualiza todas as informações de SEO da loja
  static void updateStoreSeo({
    required String storeName,
    String? storeDescription,
    String? storeImageUrl,
  }) {
    if (!kIsWeb) return;

    final title = storeName;
    final description = storeDescription ?? 
        'Faça seu pedido online em $storeName. Cardápio digital, rápido e prático!';

    // Atualiza título
    setTitle(title);
    
    // Atualiza meta description
    setDescription(description);
    
    // Atualiza Open Graph
    setOpenGraph(
      title: title,
      description: description,
      imageUrl: storeImageUrl,
    );
    
    // Atualiza Twitter Cards
    _setMetaTag('twitter:title', title);
    _setMetaTag('twitter:description', description);
    if (storeImageUrl != null) {
      _setMetaTag('twitter:image', storeImageUrl);
    }
  }

  /// Helper para definir/atualizar uma meta tag
  static void _setMetaTag(String name, String content, {bool isProperty = false}) {
    final attribute = isProperty ? 'property' : 'name';
    
    // Tenta encontrar a meta tag existente
    final meta = web.document.querySelector('meta[$attribute="$name"]');
    
    if (meta == null) {
      // Cria se não existir
      final newMeta = web.document.createElement('meta') as web.HTMLMetaElement;
      newMeta.setAttribute(attribute, name);
      newMeta.content = content;
      web.document.head?.append(newMeta);
    } else {
      // Atualiza se existir
      (meta as web.HTMLMetaElement).content = content;
    }
  }
}
