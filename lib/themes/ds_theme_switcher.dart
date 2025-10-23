import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:totem/themes/ds_theme.dart';

class DsThemeSwitcher extends ChangeNotifier {
  DsTheme theme = DsTheme(
    primaryColor: Colors.red,
    // Cor principal do app (ex: botões, links)
    secondaryColor: Colors.black,
    // Cor secundária (ex: fundo de sidebar ou destaques)
    backgroundColor: const Color(0xffffffff),
    // Cor de fundo geral (ex: Scaffold)
    cardColor: Colors.white,
    // Fundo de cards
    inactiveColor: Colors.grey[300]!,

    // Elementos desativados (ex: botão inativo)
    onPrimaryColor: Colors.black,
    // Texto ou ícone sobre `primaryColor` (bom contraste)
    onSecondaryColor: Colors.white,
    // Texto/ícone sobre `secondaryColor`
    onBackgroundColor: Colors.black,
    // Texto/ícone sobre `backgroundColor`
    onCardColor: Colors.black,
    // Texto/ícone sobre `cardColor`
    onInactiveColor: Colors.white,
    // Texto sobre `inactiveColor`

    // Novas cores padrão (exemplos)
    sidebarBackgroundColor: const Color(0xffffffff),
    // Fundo da sidebar
    sidebarTextColor: Colors.black,
    // Texto na sidebar
    sidebarIconColor: Colors.black,

    // Ícones na sidebar
    categoryBackgroundColor: const Color(0xffffffff),
    // Fundo da categoria
    categoryTextColor: Colors.black87,

    // Texto da categoria
    productBackgroundColor: Colors.white,
    // Fundo do produto
    productTextColor: Colors.black,

    // Texto do produto
    priceTextColor: Colors.green,

    // Cor do preço
    cartBackgroundColor: const Color(0xffffffff),
    // Fundo do carrinho
    cartTextColor: Colors.black,

    // Texto no carrinho
    fontFamily: DsThemeFontFamily.roboto,
    categoryLayout: DsCategoryLayout.verticalWithSideProducts,
    productLayout: DsProductLayout.grid,
    themeName: DsThemeName.classic, // Família de fonte usada no app
  );

  void changeTheme(DsTheme theme) {
    this.theme = theme;
    notifyListeners();
  }
}

extension ThemeDataFromDsTheme on DsTheme {
  ThemeData toThemeData() {
    return ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: cardColor,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      appBarTheme: AppBarTheme(

        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // tabBarTheme: TabBarTheme(
      //   splashFactory: NoSplash.splashFactory,
      //   indicatorColor: primaryColor,
      //   labelColor: primaryColor,
      //   unselectedLabelColor: Colors.grey,
      //   dividerColor: Colors.transparent,
      // ),

      textTheme: GoogleFonts.getTextTheme(
        fontFamily.nameGoogle,
      ).apply(bodyColor: onBackgroundColor, displayColor: onBackgroundColor),

      primaryColor: primaryColor,

      cardColor: cardColor,

      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        onBackground: onBackgroundColor,
        surface: cardColor,
        onSurface: onCardColor,
        error: Colors.red,
        onError: Colors.white,
      ),
    );
  }
}
