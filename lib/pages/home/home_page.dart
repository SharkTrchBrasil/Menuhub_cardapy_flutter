// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
//
// import 'package:totem/pages/home/widgets/ds_responsive_grid.dart';
// import 'package:totem/widgets/footer.dart';
// import 'package:totem/themes/classic/widgets/product_list_card.dart';
//
//
// import '../../core/extensions.dart';
// import '../../cubit/store_state.dart';
// import '../../models/store.dart';
// import '../../themes/ds_theme.dart';
// import '../../themes/ds_theme_switcher.dart';
// import '../../widgets/ds_vertical_fade.dart';
//
//
// import '../base/BasePage.dart';
// import '../../cubit/store_cubit.dart';
//
//
//
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   int _selectedIndex = 0;
//   bool isCartExpanded = false;
//
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     final DsTheme theme = context.watch<DsThemeSwitcher>().theme;
//
//     return BlocBuilder<StoreCubit, StoreState>(
//         builder: (_, state)
//     {
//       final Store? store = state.store;
//       final DsTheme theme = context
//           .watch<DsThemeSwitcher>()
//           .theme;
//       return BasePage(
//
//
//         bodyMobile:
//          SingleChildScrollView(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 2.0),
//               child: Column(
//                 children: [
//
//                   AppBar( // AppBar específica para o mobile dentro do bodyMobile
//                     backgroundColor: theme.secondaryColor,
//                     title: _topMenu(
//                       title: store?.name ?? 'Loja',
//                       subTitle: store?.description ?? '',
//                       action: _search(),
//                     ),
//                     toolbarHeight: 100,
//                     automaticallyImplyLeading: false,
//                   ),
//
//                   const SizedBox(height: 16),
//                   Container(
//                     height: 100,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: ListView.builder(
//                       scrollDirection: Axis.horizontal,
//                       itemCount: state.categories.length,
//                       itemBuilder: (context, i) {
//                         final category = state.categories[i];
//                         return Padding(
//                           padding: const EdgeInsets.only(right: 12),
//                           child: _itemTab(
//                             icon: category.imageUrl!,
//                             title: category.name,
//                             isActive: state.selectedCategory?.id ==
//                                 category.id,
//                             onTap: () {
//                               context.read<StoreCubit>().selectCategory(
//                                 category,
//                               );
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   LayoutBuilder(
//                     builder: (context, constraints) {
//                       final double itemWidth = 180;
//                       int crossAxisCount =
//                       (constraints.maxWidth / itemWidth).floor();
//                       if (crossAxisCount < 2) crossAxisCount = 2;
//
//                       return GridView.builder(
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         padding: const EdgeInsets.all(24),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: crossAxisCount,
//                           childAspectRatio: (1 / 1.2),
//                           crossAxisSpacing: 20,
//                           mainAxisSpacing: 20,
//                         ),
//                         itemCount: state.products!.length,
//                         itemBuilder: (context, i) {
//                           final product = state.products![i];
//                           return _item(
//                             image: product.imageUrl!,
//                             title: product.name,
//                             price: '\$${product.basePrice.toStringAsFixed(
//                                 2)}',
//                           );
//                         },
//                       );
//                     },
//                   ),
//
//                 ],
//               ),
//             ),
//           ),
//
//
//
//
//         bodyDesktop:
//
//             SizedBox( // O SizedBox com altura da tela aqui não é ideal para rolagem do conteúdo interno
//               height: MediaQuery
//                   .of(context)
//                   .size
//                   .height,
//               // Remover esta linha se quiser que o conteúdo dentro dela role
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 28.0),
//                 child: SingleChildScrollView( // Permite rolagem vertical de todo o conteúdo do desktop
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     children: [
//                       // Seus widgets GetPremiumCard e outros itens fixos do desktop podem ir aqui.
//                       // A linha do Row com GetPremiumCard e o container escuro.
//                       Row(
//                         children: [
//
//                                    Expanded(
//                             child: GetPremiumCard( // Substitua pelo seu GetPremiumCard real
//                               onPressed: () {},
//                               backgroundColor: const Color(0XFF201f2b),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       // Espaçamento após o cabeçalho personalizado do desktop
//
//                       // Conteúdo da sua HomePage original para desktop
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//
//                           const SizedBox(width: 24),
//                           TapRegion(
//                             onTapInside: (_) {
//                               if (isCartExpanded) {
//                                 setState(() {
//                                   isCartExpanded = false;
//                                 });
//                               }
//                             },
//                             child: Column( // Esta Column agora é o conteúdo central rolável
//                               children: [
//
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: Container(
//                                         height: 100,
//                                         padding: const EdgeInsets.symmetric(
//                                           vertical: 24,
//                                           horizontal: 24,
//                                         ),
//                                         child: ListView.builder(
//                                           scrollDirection: Axis.horizontal,
//                                           itemCount: state.categories.length,
//                                           itemBuilder: (context, i) {
//                                             final category = state
//                                                 .categories[i];
//                                             return Padding(
//                                               padding: const EdgeInsets.only(
//                                                   right: 26),
//                                               child: _itemTab(
//                                                 icon: category.imageUrl!,
//                                                 title: category.name,
//                                                 isActive: state
//                                                     .selectedCategory?.id ==
//                                                     category.id,
//                                                 onTap: () {
//                                                   context.read<
//                                                       StoreCubit>()
//                                                       .selectCategory(
//                                                     category,
//                                                   );
//                                                 },
//                                               ),
//                                             );
//                                           },
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 state.selectedCategory != null
//                                     ? Column(
//                                   crossAxisAlignment: CrossAxisAlignment
//                                       .start,
//                                   children: [
//                                     DsVerticalFade(
//                                       child: DsResponsiveGrid(
//                                         itemSpacing: 24,
//                                         itemMaxWidth: 200,
//                                         padding: const EdgeInsets.all(24),
//                                         children: [
//                                           for(final p in state.products!
//                                               .where((p) =>
//                                           p.category ==
//                                               state.selectedCategory))
//                                             ProductListCard(product: p),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 )
//                                     : Container(),
//                               ],
//                             ),
//                           ),
//
//
//                         ],
//                       ),
//
//                       // Footer para desktop
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//
//
//         bodyTablet: Container(),
//
//         rightDesktopWidget:    Flexible(
//           flex: 2,
//           child: SingleChildScrollView( // Rolagem para a seção de pedidos
//             child: Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(24.0),
//                   child: _topMenu(
//                     title: 'Order',
//                     subTitle: 'Table 8',
//                     action: Container(),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Padding(
//                   padding: const EdgeInsets.all(24.0),
//                   child: Container(
//                     padding: const EdgeInsets.all(20),
//                     margin: const EdgeInsets.symmetric(
//                         vertical: 10),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(14),
//                       color: const Color(0xff1f2029),
//                     ),
//                     child: Column(
//                       children: [
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: const [
//                             Text(
//                               'Sub Total',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             Text(
//                               '\$40.32',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: const [
//                             Text(
//                               'Tax',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             Text(
//                               '\$4.32',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                         Container(
//                           margin: const EdgeInsets.symmetric(
//                             vertical: 20,
//                           ),
//                           height: 2,
//                           width: double.infinity,
//                           color: Colors.white,
//                         ),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: const [
//                             Text(
//                               'Total',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             Text(
//                               '\$44.64',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 30),
//                         ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             foregroundColor: Colors.white,
//                             backgroundColor: Colors
//                                 .deepOrange,
//                             padding: const EdgeInsets
//                                 .symmetric(
//                               vertical: 8,
//                             ),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius
//                                   .circular(8),
//                             ),
//                           ),
//                           onPressed: () {
//                             // Implement print bill logic
//                           },
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment
//                                 .center,
//                             children: const [
//                               Icon(Icons.print, size: 16),
//                               SizedBox(width: 6),
//                               Text('Print Bills'),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//
//
//
//
//       );
//     });
//   }
//
//   // --- Funções Auxiliares (inalteradas) ---
//   bool isStoreOpenNow(Store store) {
//     final now = DateTime.now();
//     final today = now.weekday % 7;
//     final todayHours = store.hours.where((h) => h.dayOfWeek == today && h.isActive);
//
//     final nowTime = TimeOfDay.fromDateTime(now);
//
//     for (final hour in todayHours) {
//       final open = hour.openingTime;
//       final close = hour.closingTime;
//
//       if (open != null && close != null) {
//         final afterOpen = compareTime(nowTime, open) >= 0;
//         final beforeClose = compareTime(nowTime, close) <= 0;
//
//         if (afterOpen && beforeClose) {
//           return true;
//         }
//       }
//     }
//     return false;
//   }
//
//   Widget _itemOrder({
//     required String image,
//     required String title,
//     required String qty,
//     required String price,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(14),
//         color: const Color(0xff1f2029),
//       ),
//       child: Row(
//         children: [
//           Container(
//             height: 60,
//             width: 60,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               image: DecorationImage(
//                 image: image.startsWith('http')
//                     ? NetworkImage(image) as ImageProvider
//                     : AssetImage(image),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   price,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Text(
//             '$qty x',
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _item({
//     required String image,
//     required String title,
//     required String price,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18),
//         color: const Color(0xff1f2029),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             child: Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(16),
//                 image: DecorationImage(
//                   image: image.startsWith('http')
//                       ? NetworkImage(image) as ImageProvider
//                       : AssetImage(image),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 price,
//                 style: const TextStyle(color: Colors.deepOrange, fontSize: 20),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _topMenu({
//     required String title,
//     required String subTitle,
//     required Widget action,
//   }) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.start,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Column(
//           mainAxisAlignment: MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               subTitle,
//               style: const TextStyle(color: Colors.white54, fontSize: 10),
//             ),
//           ],
//         ),
//         Expanded(flex: 1, child: Container(width: double.infinity)),
//         Expanded(flex: 5, child: action),
//       ],
//     );
//   }
//
//   Widget _search() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       width: double.infinity,
//       height: 40,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18),
//         color: const Color(0xff1f2029),
//       ),
//       child: const Row(
//         children: [
//           Icon(Icons.search, color: Colors.white54),
//           SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               'Search menu here...',
//               style: TextStyle(color: Colors.white54, fontSize: 11),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _itemTab({
//     required String icon,
//     required String title,
//     required bool isActive,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 180,
//         margin: const EdgeInsets.only(right: 26),
//         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(10),
//           color: const Color(0xff1f2029),
//           border: isActive
//               ? Border.all(color: Colors.deepOrangeAccent, width: 3)
//               : Border.all(color: const Color(0xff1f2029), width: 3),
//         ),
//         child: Row(
//           children: [
//             Image.network(
//               icon,
//               width: 38,
//             ),
//             const SizedBox(width: 8),
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // Assumo que você tem o GetPremiumCard em algum lugar, criei um placeholder
// class GetPremiumCard extends StatelessWidget {
//   final VoidCallback onPressed;
//   final Color backgroundColor;
//
//   const GetPremiumCard({
//     super.key,
//     required this.onPressed,
//     required this.backgroundColor,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 200,
//       color: backgroundColor,
//       alignment: Alignment.center,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Text(
//             'Get Premium',
//             style: TextStyle(color: Colors.white, fontSize: 22),
//           ),
//           const SizedBox(height: 10),
//           ElevatedButton(
//             onPressed: onPressed,
//             child: const Text('Upgrade Now'),
//           ),
//         ],
//       ),
//     );
//   }
// }