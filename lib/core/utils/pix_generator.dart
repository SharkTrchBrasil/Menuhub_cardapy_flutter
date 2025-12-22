/// ✅ Gerador de Payload PIX (BR Code EMV)
/// 
/// Gera o código Copia e Cola e QR Code para pagamentos PIX
/// Padrão: BR Code (EMVCo) definido pelo Banco Central
/// 
/// Referências:
/// - https://www.bcb.gov.br/estabilidadefinanceira/pix
/// - Manual BR Code PIX (BACEN)
class PixGenerator {
  
  /// Gera o payload BR Code para PIX
  /// 
  /// [pixKey] - Chave PIX (CPF, CNPJ, email, telefone ou aleatória)
  /// [pixKeyType] - Tipo da chave: 'cpf', 'cnpj', 'email', 'phone', 'random'
  /// [merchantName] - Nome do recebedor (loja)
  /// [merchantCity] - Cidade do recebedor
  /// [amount] - Valor em reais (ex: 89.00)
  /// [txId] - Identificador da transação (opcional)
  /// [description] - Descrição do pagamento (opcional)
  static String generatePayload({
    required String pixKey,
    String? pixKeyType,
    required String merchantName,
    required String merchantCity,
    required double amount,
    String? txId,
    String? description,
  }) {
    final payload = StringBuffer();
    
    // 00 - Payload Format Indicator (fixo: "01")
    payload.write(_field('00', '01'));
    
    // 01 - Point of Initiation Method
    // "11" = QR Code estático (reutilizável)
    // "12" = QR Code dinâmico (único, com valor)
    payload.write(_field('01', amount > 0 ? '12' : '11'));
    
    // 26 - Merchant Account Information (PIX)
    // SubTags:
    // - 00: GUI (fixo: "br.gov.bcb.pix")
    // - 01: Chave PIX
    // - 02: Descrição (opcional, máx 25 chars)
    final gui = _field('00', 'br.gov.bcb.pix');
    final key = _field('01', pixKey);
    String descField = '';
    if (description != null && description.isNotEmpty) {
      descField = _field('02', _truncate(_sanitize(description), 25));
    }
    final merchantAccountInfo = '$gui$key$descField';
    payload.write(_field('26', merchantAccountInfo));
    
    // 52 - Merchant Category Code (MCC)
    // "0000" = Não informado
    payload.write(_field('52', '0000'));
    
    // 53 - Transaction Currency (ISO 4217)
    // "986" = BRL (Real Brasileiro)
    payload.write(_field('53', '986'));
    
    // 54 - Transaction Amount
    if (amount > 0) {
      // Formata com 2 casas decimais e ponto como separador
      payload.write(_field('54', amount.toStringAsFixed(2)));
    }
    
    // 58 - Country Code
    payload.write(_field('58', 'BR'));
    
    // 59 - Merchant Name (máx 25 chars)
    payload.write(_field('59', _truncate(_sanitize(merchantName), 25)));
    
    // 60 - Merchant City (máx 15 chars)
    payload.write(_field('60', _truncate(_sanitize(merchantCity), 15)));
    
    // 62 - Additional Data Field Template
    // SubTag 05: Reference Label (txId)
    if (txId != null && txId.isNotEmpty) {
      final refLabel = _field('05', _truncate(_sanitize(txId), 25));
      payload.write(_field('62', refLabel));
    }
    
    // 63 - CRC16 (checksum)
    // Adiciona o prefixo "6304" antes de calcular o CRC
    final payloadWithoutCrc = '${payload.toString()}6304';
    final crc = _calculateCRC16(payloadWithoutCrc);
    
    return '$payloadWithoutCrc$crc';
  }
  
  /// Cria um campo EMV no formato: ID + LENGTH + VALUE
  static String _field(String id, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }
  
  /// Trunca string para o tamanho máximo
  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
  
  /// Sanitiza string removendo acentos e caracteres especiais
  static String _sanitize(String value) {
    // Mapa de substituição de acentos
    const accentsMap = {
      'ã': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
      'Ã': 'A', 'Á': 'A', 'À': 'A', 'Â': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C', 'Ñ': 'N',
    };
    
    String result = value;
    accentsMap.forEach((accent, replacement) {
      result = result.replaceAll(accent, replacement);
    });
    
    // Remove caracteres não permitidos (mantém apenas alfanuméricos e espaço)
    result = result.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
    
    return result.toUpperCase();
  }
  
  /// Calcula CRC-16 CCITT-FALSE
  /// Polinômio: 0x1021, valor inicial: 0xFFFF
  static String _calculateCRC16(String payload) {
    int crc = 0xFFFF;
    const polynomial = 0x1021;
    
    for (int i = 0; i < payload.length; i++) {
      crc ^= (payload.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
  
  /// Formata a chave PIX para exibição
  static String formatPixKeyForDisplay(String pixKey, String? keyType) {
    final type = keyType?.toLowerCase();
    
    switch (type) {
      case 'cpf':
        if (pixKey.length == 11) {
          return '${pixKey.substring(0, 3)}.${pixKey.substring(3, 6)}.${pixKey.substring(6, 9)}-${pixKey.substring(9)}';
        }
        break;
      case 'cnpj':
        if (pixKey.length == 14) {
          return '${pixKey.substring(0, 2)}.${pixKey.substring(2, 5)}.${pixKey.substring(5, 8)}/${pixKey.substring(8, 12)}-${pixKey.substring(12)}';
        }
        break;
      case 'phone':
        final clean = pixKey.replaceAll(RegExp(r'[^\d]'), '');
        if (clean.length == 11) {
          return '(${clean.substring(0, 2)}) ${clean.substring(2, 7)}-${clean.substring(7)}';
        }
        break;
    }
    
    return pixKey;
  }
  
  /// Retorna label amigável para o tipo de chave
  static String getKeyTypeLabel(String? keyType) {
    switch (keyType?.toLowerCase()) {
      case 'cpf':
        return 'CPF';
      case 'cnpj':
        return 'CNPJ';
      case 'email':
        return 'E-mail';
      case 'phone':
        return 'Celular';
      case 'random':
        return 'Chave aleatória';
      default:
        return 'Chave PIX';
    }
  }
}
