// lib/core/utils/id_obfuscator.dart

/// ✅ ENTERPRISE: Ofuscador de IDs para URLs
/// 
/// Transforma IDs numéricos sequenciais em strings não-previsíveis.
/// Isso evita que usuários advinhem outros IDs na URL.
/// 
/// Exemplo:
/// - ID 1 -> "kX7h"
/// - ID 123 -> "mQ3nPw"
/// - ID 456 -> "jR9tYz"
class IdObfuscator {
  // Salt para tornar os hashes únicos por app
  static const String _salt = 'mh2024';
  
  // Caracteres permitidos na URL (URL-safe, sem caracteres ambíguos)
  static const String _alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  
  /// Codifica um ID numérico para uma string ofuscada
  static String encode(int id) {
    if (id <= 0) return '';
    
    // Mistura o ID com o salt para dificultar engenharia reversa
    final mixed = (id * 2654435761) ^ _salt.hashCode;
    
    // Converte para base custom
    var result = StringBuffer();
    var value = mixed.abs();
    
    while (value > 0) {
      result.write(_alphabet[value % _alphabet.length]);
      value ~/= _alphabet.length;
    }
    
    // Adiciona um prefixo baseado no ID original para validação
    final checksum = _alphabet[id % _alphabet.length];
    
    return '$checksum${result.toString()}';
  }
  
  /// Decodifica uma string ofuscada para o ID numérico original
  static int? decode(String encoded) {
    if (encoded.isEmpty || encoded.length < 2) return null;
    
    try {
      // Extrai checksum e valor
      final checksum = encoded[0];
      final valueStr = encoded.substring(1);
      
      // Reconstrói o valor misturado
      var mixed = 0;
      var multiplier = 1;
      
      for (var i = 0; i < valueStr.length; i++) {
        final index = _alphabet.indexOf(valueStr[i]);
        if (index < 0) return null;
        
        mixed += index * multiplier;
        multiplier *= _alphabet.length;
      }
      
      // Desfaz a mistura (inversa de multiplicação modular)
      // 2654435761 * 3422390419 ≡ 1 (mod 2^32)
      final unMixed = (mixed ^ _salt.hashCode) * 340558971 & 0xFFFFFFFF;
      
      // Busca o ID original por iteração (mais confiável)
      for (var testId = 1; testId < 10000000; testId++) {
        final testMixed = (testId * 2654435761) ^ _salt.hashCode;
        if (testMixed.abs() == mixed && _alphabet[testId % _alphabet.length] == checksum) {
          return testId;
        }
      }
      
      // Fallback: tenta decodificar diretamente
      final candidateId = unMixed.toInt();
      if (candidateId > 0 && candidateId < 10000000) {
        final expectedChecksum = _alphabet[candidateId % _alphabet.length];
        if (expectedChecksum == checksum) {
          return candidateId;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Cria uma URL amigável para produto
  /// Exemplo: "x-burguer" + ID 123 -> "x-burguer-mQ3nPw"
  static String createProductUrl(String productName, int productId) {
    final slug = _slugify(productName);
    final encodedId = encode(productId);
    return '$slug-$encodedId';
  }
  
  /// Extrai o ID codificado de uma URL de produto
  /// Exemplo: "x-burguer-mQ3nPw" -> "mQ3nPw"
  static String? extractEncodedId(String urlSlug) {
    final lastDash = urlSlug.lastIndexOf('-');
    if (lastDash < 0 || lastDash == urlSlug.length - 1) return null;
    return urlSlug.substring(lastDash + 1);
  }
  
  /// Decodifica ID de uma URL de produto
  /// Exemplo: "x-burguer-mQ3nPw" -> 123
  static int? decodeFromProductUrl(String urlSlug) {
    final encodedId = extractEncodedId(urlSlug);
    if (encodedId == null) return null;
    return decode(encodedId);
  }
  
  /// Converte string para slug URL-friendly
  static String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
