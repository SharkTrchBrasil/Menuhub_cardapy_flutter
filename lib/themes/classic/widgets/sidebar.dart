
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart'; // Importe GoRouter
import 'package:provider/provider.dart'; // Mantenha o Provider

import 'package:totem/themes/classic/widgets/store_card.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/get_code.dart';
import '../../../controllers/menu_app_controller.dart'; // Seu DrawerControllerProvider

import '../../../models/store.dart';
import '../../../cubit/store_cubit.dart';


import '../../ds_theme.dart';
import '../../ds_theme_switcher.dart';

class SidebarClassicTheme extends StatefulWidget {
  final int storeId; // Adicione storeId se for necessário para as rotas

  const SidebarClassicTheme({super.key, required this.storeId});

  @override
  State<SidebarClassicTheme> createState() => _SidebarClassicThemeState();
}

class _SidebarClassicThemeState extends State<SidebarClassicTheme> {
  // Use GetX InboxController, mas para um projeto puro Provider, considere convertê-lo
  // ou injetá-lo de forma compatível com Provider/GetX.
  // Se InboxController for parte de um sistema GetX, você precisará garantir que ele seja inicializado.
  final InboxController _inboxController = InboxController();

  final double _collapsedWidth = 72.0; // Largura do mini-drawer (ícone + texto)
  final double _expandedWidth = 260.0; // Largura do drawer expandido

  @override
  Widget build(BuildContext context) {
    final Store? store = context.watch<StoreCubit>().state.store;
    final theme = context.watch<DsThemeSwitcher>().theme;
    final drawerController = context.watch<MenuAppController>();
    final bool isExpanded = drawerController.isExpanded;

    final imageUrl =
        (store?.image?.url?.isNotEmpty ?? false)
            ? store!.image!.url!
            : 'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? _expandedWidth : _collapsedWidth,
      color: theme.sidebarBackgroundColor,
      child: Drawer(
        backgroundColor: theme.sidebarBackgroundColor,
        child: Column(
          children: [
            // === TOPO DO DRAWER ===
            Padding(
              padding: isExpanded
                  ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0)
                  : const EdgeInsets.symmetric(vertical: 20.0),
              child: InkWell(
                onTap: () => drawerController.toggle(),
                child: isExpanded
                    ? StoreCardData()
                    : Center(
                  child: CircleAvatar(
                    foregroundColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    backgroundImage: NetworkImage(imageUrl),
                    radius: 28,
                  ),
                ),
              ),
            ),

            // === MENU EXPANDIDO COM SCROLL ===
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _buildMenuItem(
                        context: context,
                        title: 'Meus Pedidos',
                        route: '/stores/${widget.storeId}/orders',
                        index: 0,
                        iconPath: 'assets/images/package.png',
                        isExpanded: isExpanded,
                        theme: theme,
                      ),

                      const SizedBox(height: 20),


                      _buildMenuItem(
                        context: context,
                        title: 'Perfil',
                        route: '/stores/${widget.storeId}/customers',
                        index: 4,
                        iconPath: 'assets/images/user.png',
                        isExpanded: isExpanded,
                        theme: theme,
                      ),

                      const SizedBox(height: 20),
                      _buildMenuItem(
                        context: context,
                        title: 'Cupons',
                        route: '/stores/${widget.storeId}/coupons',
                        index: 7,
                        iconPath: 'assets/images/6.png',
                        isExpanded: isExpanded,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // === RODAPÉ FIXO: REDES E ENDEREÇO ===
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Divider(color: Colors.white30),
                  if (isExpanded) ...[
                    Row(
                      children: [

                        Expanded(
                          child: storeAddress(store, theme)
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [

                        _socialIcons(store, theme),


                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );








  }

  // --- MÉTODOS AUXILIARES ---

  Widget _buildSectionTitle(
    String title, {
    required bool selected,
    required DsTheme theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color:
              selected
                  ? theme
                      .primaryColor // Usa a cor primária do seu tema
                  : theme
                      .sidebarTextColor, // Usa a cor de texto do seu tema para sidebar
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String title,
    required String route,
    required int index,
    required String iconPath,
    required bool isExpanded,
    required DsTheme theme, // Passa o tema para o método
  }) {
    // Usamos setState para que o widget seja reconstruído e o item selecionado seja atualizado
    // quando o index do InboxController muda.
    return ListenableBuilder(
      listenable: _inboxController,
      builder: (context, child) {
        final isSelected = _inboxController.pageselecter == index;
        final Color primaryColor = theme.primaryColor;
        final Color defaultIconColor = theme.sidebarIconColor;
        final Color defaultTextColor = theme.sidebarTextColor;

        final Color iconColor = isSelected ? primaryColor : defaultIconColor;
        final Color textColor = isSelected ? theme.sidebarBackgroundColor : defaultTextColor;
        final Color backgroundColor =
            isSelected ? primaryColor : Colors.transparent;
        final Border? border =
            isSelected &&
                    !isExpanded // Borda apenas no modo colapsado e selecionado
                ? Border.all(color: primaryColor.withOpacity(0.3), width: 1.0)
                : null;

        return InkWell(
          onTap: () {
            // Atualiza o estado do InboxController e navega
            _inboxController.setTextIsTrue(index);
            context.go(route);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: isExpanded ? 48 : 55,
            width: isExpanded ? double.infinity : 60,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: border, // Aplica a borda condicionalmente
            ),
            child:
                isExpanded
                    ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Image.asset(
                          iconPath,
                          height: 20,
                          width: 20,
                          color: iconColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color:
                                  textColor, // Use textColor para refletir a seleção
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                    : Stack(
                      children: [
                        if (isSelected) // Barra lateral para item selecionado no modo colapsado
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2.0,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  iconPath,
                                  height: 20,
                                  width: 20,
                                  color: iconColor,
                                ),
                              ),
                              if (!isExpanded ||
                                  !isSelected) // Mostra texto apenas se não estiver expandido ou não selecionado
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        defaultTextColor, // Use defaultTextColor para o texto do item colapsado
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }

  Widget _socialIcons(Store? store, DsTheme theme) {
    if (store == null) return const SizedBox.shrink();

    final List<Widget> icons = [];

    if (store.facebook != null && store.facebook!.isNotEmpty) {
      final url = formatSocialUrl('https://facebook.com/', store.facebook!);
      icons.add(_socialIcon(FontAwesomeIcons.facebookF, url, theme));
    }

    if (store.instagram != null && store.instagram!.isNotEmpty) {
      final url = formatSocialUrl('https://instagram.com/', store.instagram!);
      icons.add(_socialIcon(FontAwesomeIcons.instagram, url, theme));
    }

    if (store.tiktok != null && store.tiktok!.isNotEmpty) {
      final url = formatSocialUrl('https://tiktok.com/@', store.tiktok!);
      icons.add(_socialIcon(FontAwesomeIcons.tiktok, url, theme));
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: icons,
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, String url, DsTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      // Ajuste o padding
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Icon(icon, size: 16, color: theme.sidebarIconColor),
      ),
    );
  }

  String formatSocialUrl(String baseUrl, String userInput) {
    if (userInput.trim().startsWith('http')) {
      return userInput.trim();
    }
    return '$baseUrl${userInput.trim()}';
  }

  Widget storeAddress(Store? store, DsTheme theme) {
    if (store == null) return const SizedBox.shrink();

    final addressLine = [
          store.street,
          if (store.number?.isNotEmpty ?? false) store.number,
          if (store.neighborhood?.isNotEmpty ?? false) ' ${store.neighborhood}',
          if (store.complement?.isNotEmpty ?? false) ' ${store.complement}',
          if (store.reference?.isNotEmpty ?? false) ' ${store.reference}',

        ]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, color: theme.sidebarIconColor),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            addressLine,
            style: TextStyle(
              fontSize: 12,
              color: theme.sidebarTextColor,
              fontWeight: FontWeight.w600,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}































// Seu DrawerControllerProvider (menu_app_controller.dart)
// Permanece o mesmo
/*
import 'package:flutter/material.dart';

class MenuAppController with ChangeNotifier { // Renomeado de DrawerControllerProvider para MenuAppController
  bool _isExpanded = true;

  bool get isExpanded => _isExpanded;

  void toggle() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  void set(bool value) {
    _isExpanded = value;
    notifyListeners();
  }
}
*/

// Seu InboxController (UI TEMP/controller/get_code.dart)
// Você deve ter algo parecido com isso:
/*
import 'package:flutter/material.dart';

class InboxController extends ChangeNotifier {
  int _pageselecter = 0;

  int get pageselecter => _pageselecter;

  void setTextIsTrue(int index) {
    _pageselecter = index;
    notifyListeners();
  }
}
*/

// import 'package:eva_icons_flutter/eva_icons_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:totem/core/extensions.dart';
// import 'package:totem/themes/classic/widgets/store_card.dart';
// import 'package:totem/themes/classic/temp/upgrade_premium_card.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../../../helpers/constants.dart';
// import '../../../models/store.dart';
// import '../../../pages/home/store_cubit.dart';
// import '../../../widgets/selection_button.dart';
// import '../../ds_theme.dart';
// import '../../ds_theme_switcher.dart';
//
// class SidebarClassicTheme extends StatelessWidget {
//   const SidebarClassicTheme({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//
//     final Store? store = context.watch<StoreCubit>().state.store;
//
//     final theme = context.watch<DsThemeSwitcher>().theme;
//
//     return
//     Container(
//       color: context.dsTheme.sidebarBackgroundColor,
//       height: MediaQuery.of(context).size.height,
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           return SingleChildScrollView(
//             controller: ScrollController(),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(minHeight: constraints.maxHeight),
//               child: IntrinsicHeight(
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: StoreCardData(),
//                     ),
//                     const Divider(thickness: 1),
//
//                     // Menu de navegação
//                     SelectionButton(
//                       selectedTextColor: theme.primaryColor,
//                       unselectedTextColor: context.dsTheme.sidebarTextColor,
//                       data: [
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.grid,
//                           icon: EvaIcons.gridOutline,
//                           label: "Dashboard",
//                         ),
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.archive,
//                           icon: EvaIcons.archiveOutline,
//                           label: "Reports",
//                         ),
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.calendar,
//                           icon: EvaIcons.calendarOutline,
//                           label: "Calendar",
//                         ),
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.email,
//                           icon: EvaIcons.emailOutline,
//                           label: "Email",
//                           totalNotif: 20,
//                         ),
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.person,
//                           icon: EvaIcons.personOutline,
//                           label: "Profil",
//                         ),
//                         SelectionButtonData(
//                           activeIcon: EvaIcons.settings,
//                           icon: EvaIcons.settingsOutline,
//                           label: "Setting",
//                         ),
//                       ],
//                       onSelected: (index, value) {},
//                       title: '',
//                     ),
//
//                     // Espaço entre o conteúdo principal e o rodapé
//                     Spacer(),
//
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12.0),
//                       child: Column(
//                         children: [
//                           storeAddress(store, theme),
//                           SizedBox(height: kSpacing),
//                           _socialIcons(store, theme),
//                           SizedBox(height: 16),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//
//   }
//
//   Widget _socialIcons(Store? store, DsTheme theme) {
//     if (store == null) return const SizedBox.shrink();
//
//     final List<Widget> icons = [];
//
//     if (store.facebook != null && store.facebook!.isNotEmpty) {
//       final url = formatSocialUrl('https://facebook.com/', store.facebook!);
//       icons.add(_socialIcon(FontAwesomeIcons.facebookF, url, theme));
//     }
//
//     if (store.instagram != null && store.instagram!.isNotEmpty) {
//       final url = formatSocialUrl('https://instagram.com/', store.instagram!);
//       icons.add(_socialIcon(FontAwesomeIcons.instagram, url, theme));
//     }
//
//     if (store.tiktok != null && store.tiktok!.isNotEmpty) {
//       final url = formatSocialUrl('https://tiktok.com/@', store.tiktok!);
//       icons.add(_socialIcon(FontAwesomeIcons.tiktok, url, theme));
//     }
//
//     if (icons.isEmpty) return const SizedBox.shrink();
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 20),
//       child: Column(
//         children: [
//           const SizedBox(height: 8),
//           Row(
//
//             children: icons,
//           ),
//
//         ],
//       ),
//     );
//
//   }
//
//   Widget _socialIcon(IconData icon, String url, DsTheme theme) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
//       child: InkWell(
//         onTap: () => launchUrl(Uri.parse(url)),
//         child: Icon(icon, size: 20, color: theme.sidebarIconColor,),
//       ),
//     );
//   }
//
//   String formatSocialUrl(String baseUrl, String userInput) {
//     if (userInput.trim().startsWith('http')) {
//       return userInput.trim();
//     }
//     return '$baseUrl${userInput.trim()}';
//   }
//
//   Widget storeAddress(Store? store, DsTheme theme) {
//     if (store == null) return const SizedBox.shrink();
//
//     final addressLine = [
//       store.street,
//       if (store.number?.isNotEmpty ?? false) store.number,
//       if (store.neighborhood?.isNotEmpty ?? false) ' ${store.neighborhood}',
//       if (store.complement?.isNotEmpty ?? false) '- ${store.complement}',
//       if (store.reference?.isNotEmpty ?? false) '- ${store.reference}',
//       ' ${store.city} / ${store.state}',
//     ].where((part) => part != null && part.toString().trim().isNotEmpty).join(', ');
//
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//            Icon(Icons.location_on_outlined, color: theme.sidebarIconColor),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               addressLine,
//               style:  TextStyle(fontSize: 16, color: theme.sidebarTextColor, fontWeight: FontWeight.w600),
//               softWrap: true,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
// }
//
//
