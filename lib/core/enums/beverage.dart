// Em lib/core/enums/beverage.dart

// Seu Enum que você já criou
enum BeverageTag {
  coldDrink,
  alcoholic,
  natural,
}

// ✅ MAPA DE NOMES (o que faltava)
//    Converte o valor do Enum para um texto amigável na UI.
const Map<BeverageTag, String> beverageTagNames = {
  BeverageTag.coldDrink: 'Bebida gelada',
  BeverageTag.alcoholic: 'Bebida alcoólica',
  BeverageTag.natural: 'Natural',
};

// (Opcional, mas recomendado para consistência)
// ✅ MAPA DE DESCRIÇÕES, caso queira adicionar no futuro
const Map<BeverageTag, String> beverageTagDescriptions = {
  BeverageTag.coldDrink: 'Servida em baixa temperatura.',
  BeverageTag.alcoholic: 'Contém álcool. Venda proibida para menores.',
  BeverageTag.natural: 'Feita com ingredientes naturais, sem conservantes.',
};



// Dicionário reverso para busca rápida: "Bebida gelada" -> BeverageTag.coldDrink
final Map<String, BeverageTag> apiValueToBeverageTag =
beverageTagNames.map((key, value) => MapEntry(value, key));
