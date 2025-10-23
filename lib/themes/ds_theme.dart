import 'package:flutter/material.dart';

enum DsThemeFontFamily {
  roboto,
  montserrat,
  lato,
  openSans,
  poppins;

  String get nameGoogle {
    switch (this) {
      case DsThemeFontFamily.roboto:
        return 'Roboto';
      case DsThemeFontFamily.montserrat:
        return 'Montserrat';
      case DsThemeFontFamily.lato:
        return 'Lato';
      case DsThemeFontFamily.openSans:
        return 'Open Sans';
      case DsThemeFontFamily.poppins:
        return 'Poppins';
    }
  }

  static DsThemeFontFamily fromString(String value) {
    return DsThemeFontFamily.values.firstWhere(
          (e) => e.nameGoogle.toLowerCase() == value.toLowerCase(),
      orElse: () => DsThemeFontFamily.roboto,
    );
  }
}


enum DsCategoryLayout {
  verticalWithSideProducts('vertical'),
  horizontalWithBelowProducts('horizontal');


  final String name;
  const DsCategoryLayout(this.name);

  static DsCategoryLayout fromString(String name) {
    return DsCategoryLayout.values.firstWhere(
          (e) => e.name == name,
      orElse: () => DsCategoryLayout.verticalWithSideProducts,
    );
  }
}



enum DsProductLayout {
  grid('grid'),
  list('list');

  final String name;
  const DsProductLayout(this.name);

  static DsProductLayout fromString(String value) {
    return DsProductLayout.values.firstWhere(
          (e) => e.name == value,
      orElse: () => DsProductLayout.grid,
    );
  }
}


enum DsThemeName {
  classic('Classic'),
  fancy('Fancy'),
  minimal('Minimal'),
  modern('Modern'),
  street('Street');

  final String title;
  const DsThemeName(this.title);

  String get name => title.toLowerCase();

  static DsThemeName fromString(String value) {
    return DsThemeName.values.firstWhere(
          (e) => e.name == value.toLowerCase(),
      orElse: () => DsThemeName.classic,
    );
  }
}


class DsTheme {
  DsTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.onPrimaryColor,
    required this.onSecondaryColor,
    required this.onBackgroundColor,
    required this.onCardColor,
    required this.inactiveColor,
    required this.onInactiveColor,
    required this.fontFamily,

    required this.sidebarBackgroundColor,
    required this.sidebarTextColor,
    required this.sidebarIconColor,
    required this.categoryBackgroundColor,
    required this.categoryTextColor,
    required this.productBackgroundColor,
    required this.productTextColor,
    required this.priceTextColor,
    required this.cartBackgroundColor,
    required this.cartTextColor,

    required this.categoryLayout,
    required this.productLayout,
    required this.themeName,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color inactiveColor;

  final Color onPrimaryColor;
  final Color onSecondaryColor;
  final Color onBackgroundColor;
  final Color onCardColor;
  final Color onInactiveColor;

  final Color sidebarBackgroundColor;
  final Color sidebarTextColor;
  final Color sidebarIconColor;
  final Color categoryBackgroundColor;
  final Color categoryTextColor;
  final Color productBackgroundColor;
  final Color productTextColor;
  final Color priceTextColor;
  final Color cartBackgroundColor;
  final Color cartTextColor;

  final DsThemeFontFamily fontFamily;
  final DsCategoryLayout categoryLayout;
  final DsProductLayout productLayout;
  final DsThemeName themeName;

  static int hexToInteger(String hex) => int.parse(hex, radix: 16);

  factory DsTheme.fromJson(Map<String, dynamic> map) {
    return DsTheme(
      primaryColor: Color(hexToInteger(map['primary_color'])),
      secondaryColor: Color(hexToInteger(map['secondary_color'])),
      backgroundColor: Color(hexToInteger(map['background_color'])),
      cardColor: Color(hexToInteger(map['card_color'])),
      onPrimaryColor: Color(hexToInteger(map['on_primary_color'])),
      onSecondaryColor: Color(hexToInteger(map['on_secondary_color'])),
      onBackgroundColor: Color(hexToInteger(map['on_background_color'])),
      onCardColor: Color(hexToInteger(map['on_card_color'])),
      inactiveColor: Color(hexToInteger(map['inactive_color'])),
      onInactiveColor: Color(hexToInteger(map['on_inactive_color'])),


      sidebarBackgroundColor: Color(hexToInteger(map['sidebar_background_color'])),
      sidebarTextColor: Color(hexToInteger(map['sidebar_text_color'])),
      sidebarIconColor: Color(hexToInteger(map['sidebar_icon_color'])),
      categoryBackgroundColor: Color(hexToInteger(map['category_background_color'])),
      categoryTextColor: Color(hexToInteger(map['category_text_color'])),
      productBackgroundColor: Color(hexToInteger(map['product_background_color'])),
      productTextColor: Color(hexToInteger(map['product_text_color'])),
      priceTextColor: Color(hexToInteger(map['price_text_color'])),
      cartBackgroundColor: Color(hexToInteger(map['cart_background_color'])),
      cartTextColor: Color(hexToInteger(map['cart_text_color'])),

      fontFamily: DsThemeFontFamily.fromString(map['font_family']),
      categoryLayout: DsCategoryLayout.fromString(map['category_layout']),
      productLayout: DsProductLayout.fromString(map['product_layout']),
      themeName: DsThemeName.fromString(map['theme_name']),


    );
  }




  late final TextStyle displayExtraLargeTextStyle = TextStyle(
    fontSize: 32,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle displayLargeTextStyle = TextStyle(
    fontSize: 24,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle displayMediumTextStyle = TextStyle(
    fontSize: 20,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle headingTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle paragraphTextStyle = TextStyle(
    fontSize: 14,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle smallTextStyle = TextStyle(
    fontSize: 12,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

  late final TextStyle extraSmallTextStyle = TextStyle(
    fontSize: 10,
    color: Colors.yellow,
    fontFamily: fontFamily.name,
  );

}














extension TextStyleX on TextStyle {

  TextStyle colored(Color color) => copyWith(color: color);
  TextStyle weighted(FontWeight weight) => copyWith(fontWeight: weight);

}