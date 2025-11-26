// Os nomes devem corresponder exatamente aos do backend (respeitando camelCase vs snake_case na serialização)
enum FoodTag {
  vegetarian,
  vegan,
  organic,
  sugarFree,
  lacFree,
  glutenFree,
  spicy,
  kids,
  fitness,
  lowCarb,
}

// Mapa para obter a descrição de cada tag
const Map<FoodTag, String> foodTagDescriptions = {
  FoodTag.vegetarian: 'Sem carne de nenhum tipo',
  FoodTag.vegan: 'Sem produtos de origem animal, como carne, ovo ou leite',
  FoodTag.organic: 'Cultivado sem agrotóxicos',
  FoodTag.sugarFree: 'Não contém nenhum tipo de açúcar',
  FoodTag.lacFree: 'Não contém lactose',
  FoodTag.glutenFree: 'Não contém glúten',
  FoodTag.spicy: 'Produto picante',
  FoodTag.kids: 'Apropriado para crianças',
  FoodTag.fitness: 'Produto fitness',
  FoodTag.lowCarb: 'Baixo teor de carboidratos',
};

// Mapa para obter o nome formatado de cada tag
const Map<FoodTag, String> foodTagNames = {
  FoodTag.vegetarian: 'Vegetariano',
  FoodTag.vegan: 'Vegano',
  FoodTag.organic: 'Orgânico',
  FoodTag.sugarFree: 'Sem açúcar',
  FoodTag.lacFree: 'Zero lactose',
  FoodTag.glutenFree: 'Sem glúten',
  FoodTag.spicy: 'Picante',
  FoodTag.kids: 'Infantil',
  FoodTag.fitness: 'Fitness',
  FoodTag.lowCarb: 'Low Carb',
};


// Dicionário reverso para busca rápida: "Vegetariano" -> FoodTag.vegetarian
final Map<String, FoodTag> apiValueToFoodTag =
foodTagNames.map((key, value) => MapEntry(value, key));
