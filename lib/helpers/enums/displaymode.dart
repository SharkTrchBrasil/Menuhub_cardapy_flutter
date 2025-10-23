// lib/core/enums/ui_display_mode.dart

/// Define como uma variante (grupo de complementos) será exibida na tela
/// e como o usuário poderá interagir com as opções.
enum UIDisplayMode {
  /// **SELEÇÃO ÚNICA (Radio Button)**
  ///
  /// O usuário DEVE escolher EXATAMENTE UMA opção.
  /// Exemplos:
  /// - Tamanho da pizza (Pequena, Média, Grande)
  /// - Ponto da carne (Mal passada, Ao ponto, Bem passada)
  /// - Tipo de massa (Tradicional, Integral, Sem glúten)
  ///
  /// UI Comportamento:
  /// - Radio buttons (círculos)
  /// - Apenas uma opção pode estar selecionada por vez
  /// - Ao selecionar outra, a anterior é desmarcada automaticamente
  SINGLE,

  /// **SELEÇÃO MÚLTIPLA (Checkboxes)**
  ///
  /// O usuário PODE escolher NENHUMA, UMA ou VÁRIAS opções.
  /// Exemplos:
  /// - Adicionais do hambúrguer (Bacon, Queijo extra, Ovo)
  /// - Ingredientes da salada (Alface, Tomate, Cebola, Azeitona)
  /// - Molhos extras (Ketchup, Mostarda, Maionese)
  ///
  /// UI Comportamento:
  /// - Checkboxes (quadrados)
  /// - Múltiplas opções podem estar selecionadas simultaneamente
  /// - Respeita min/max configurado (ex: escolha no mínimo 2, no máximo 4)
  MULTIPLE,

  /// **SELEÇÃO COM QUANTIDADE (Stepper)**
  ///
  /// O usuário pode escolher a QUANTIDADE de cada opção.
  /// Exemplos:
  /// - Bordas recheadas da pizza (0-4 bordas)
  /// - Shots de café expresso (1-3 shots)
  /// - Porções de molho extra (0-5 porções)
  ///
  /// UI Comportamento:
  /// - Botões +/- (stepper) para cada opção
  /// - Contador numérico visível
  /// - Pode ter quantidade total máxima (ex: máximo 10 itens no total)
  QUANTITY,

  /// **MODO DESCONHECIDO/NÃO CONFIGURADO**
  ///
  /// Usado como fallback quando o backend envia um valor inválido
  /// ou quando a variante ainda não foi configurada.
  ///
  /// UI Comportamento:
  /// - Não deve ser usado em produção
  /// - Logar warning e usar SINGLE como padrão
  UNKNOWN;

  /// Converte uma string vinda do backend para o enum
  static UIDisplayMode fromString(String? value) {
    if (value == null || value.isEmpty) {
      return UIDisplayMode.UNKNOWN;
    }

    switch (value.toUpperCase()) {
      case 'SINGLE':
      case 'SELEÇÃO ÚNICA':
      case 'SELECAO_UNICA':
        return UIDisplayMode.SINGLE;

      case 'MULTIPLE':
      case 'SELEÇÃO MÚLTIPLA':
      case 'SELECAO_MULTIPLA':
        return UIDisplayMode.MULTIPLE;

      case 'QUANTITY':
      case 'SELEÇÃO COM QUANTIDADE':
      case 'SELECAO_QUANTIDADE':
        return UIDisplayMode.QUANTITY;

      default:
        print('⚠️ UIDisplayMode desconhecido: "$value". Usando UNKNOWN.');
        return UIDisplayMode.UNKNOWN;
    }
  }

  /// Converte o enum para string no formato do backend
  String toApiString() {
    switch (this) {
      case UIDisplayMode.SINGLE:
        return 'SINGLE';
      case UIDisplayMode.MULTIPLE:
        return 'MULTIPLE';
      case UIDisplayMode.QUANTITY:
        return 'QUANTITY';
      case UIDisplayMode.UNKNOWN:
        return 'UNKNOWN';
    }
  }

  /// Nome amigável para exibir na UI (em português)
  String get displayName {
    switch (this) {
      case UIDisplayMode.SINGLE:
        return 'Seleção Única';
      case UIDisplayMode.MULTIPLE:
        return 'Seleção Múltipla';
      case UIDisplayMode.QUANTITY:
        return 'Seleção com Quantidade';
      case UIDisplayMode.UNKNOWN:
        return 'Não Configurado';
    }
  }

  /// Descrição detalhada do modo
  String get description {
    switch (this) {
      case UIDisplayMode.SINGLE:
        return 'O cliente deve escolher exatamente uma opção';
      case UIDisplayMode.MULTIPLE:
        return 'O cliente pode escolher múltiplas opções';
      case UIDisplayMode.QUANTITY:
        return 'O cliente define a quantidade de cada opção';
      case UIDisplayMode.UNKNOWN:
        return 'Modo de exibição não definido';
    }
  }

  /// Ícone sugerido para cada modo (para usar em interfaces admin)
  String get iconName {
    switch (this) {
      case UIDisplayMode.SINGLE:
        return 'radio_button_checked';
      case UIDisplayMode.MULTIPLE:
        return 'check_box';
      case UIDisplayMode.QUANTITY:
        return 'add_circle';
      case UIDisplayMode.UNKNOWN:
        return 'help_outline';
    }
  }

  /// Verifica se é um modo válido para uso em produção
  bool get isValid => this != UIDisplayMode.UNKNOWN;
}