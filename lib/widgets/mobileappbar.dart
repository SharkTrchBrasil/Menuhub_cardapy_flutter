// ignore_for_file: camel_case_types, deprecated_member_use

import 'package:flutter/material.dart';

import '../core/responsive_builder.dart';


class AppBarCustom extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLeadingButton; // Novo parâmetro para controlar a exibição do leading

  const AppBarCustom({
    super.key,
    required this.title,
    this.actions,
    this.showLeadingButton = false, // Valor padrão: não mostrar o leading
  });

  @override
  State<AppBarCustom> createState() => _AppBarCustomState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBarCustomState extends State<AppBarCustom> {
  bool tap = false; // Este 'tap' não está sendo usado, pode ser removido se não for necessário

  @override
  Widget build(BuildContext context) {
    // Verifica se a tela é mobile usando seu método de responsividade
    final bool isMobile = ResponsiveBuilder.isMobile(context);

    return AppBar(
      scrolledUnderElevation: 0.0,
      title: Text(widget.title),
      leading: (isMobile || widget.showLeadingButton) ? const BackButton() : null,
      elevation: 0,
      actions: widget.actions,
    );
  }
}

































// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:get/get.dart';
// import 'package:provider/provider.dart';
//
// import '../ConstData/colorfile.dart';
// import '../ConstData/theme_provider.dart';
// import '../ConstData/typography.dart';
// import '../UI TEMP/controller/appbarcontroller.dart';
// import '../UI TEMP/controller/drawercontroller.dart';
//
// class AppBarCode extends StatefulWidget implements PreferredSizeWidget {
//   const AppBarCode({super.key, required this.title});
//
//   final String title;
//
//   @override
//   State<AppBarCode> createState() => _AppBarCodeState();
//
//   @override
//   Size get preferredSize => const Size.fromHeight(kToolbarHeight);
// }
//
// class _AppBarCodeState extends State<AppBarCode> {
//
//   late final DrawerControllerr controllerr;
//   late final AppBarController appBarController;
//
//   @override
//   void initState() {
//     super.initState();
//     controllerr = Get.put(DrawerControllerr());
//     appBarController = Get.put(AppBarController());
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     notifire = Provider.of<ColorNotifire>(context,listen: true);
//     return GetBuilder<AppBarController>(
//         builder: (appBarController) {
//           return LayoutBuilder(builder: (context, constraints) {
//             return constraints.maxWidth < 600
//                 ? appbarr(isphon: true,size: constraints.maxWidth)
//                 : PreferredSize(
//               preferredSize: const Size.fromHeight(115),
//               child: appbarr(isphon: false,size: constraints.maxWidth),
//             );
//           });
//         }
//     );
//   }
//
//   PreferredSizeWidget appbarr({required bool isphon,required double size}) {
//   notifire = Provider.of<ColorNotifire>(context, listen: true);
//     return AppBar(
//       automaticallyImplyLeading: false,
//       toolbarHeight: 80,
//       scrolledUnderElevation: 0.0,
//       backgroundColor: notifire.getBgColor,
//       elevation: 0,
//       actions: [
//         isphon? PopupMenuButton(
//           padding: const EdgeInsets.all(0),
//           offset: const Offset(0, 55),
//           color: notifire.getDrawerColor,
//           tooltip: "",
//           constraints: BoxConstraints(
//             minWidth: MediaQuery.of(context).size.width,
//             maxWidth: MediaQuery.of(context).size.width,
//           ),
//           shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8)),
//           child: Container(
//             height: 42,
//             width: 42,
//             decoration: BoxDecoration(
//                 shape: BoxShape.circle, color: notifire.getDrawerColor),
//             child: Center(child: SvgPicture.asset(appBarController.isSearch?  "assets/images/times.svg": "assets/images/Search.svg", height: 24, width: 24, color: notifire.getIconColor)),
//           ),
//           itemBuilder: (context) {
//             return [
//               search(),
//             ];
//           },):
//         InkWell(
//           onTap: () {
//             appBarController.selectisSearch(appBarController.isSearch =! appBarController.isSearch);
//           },
//           child: Container(
//             height: 42,
//             width: 42,
//             decoration: BoxDecoration(
//                 shape: BoxShape.circle, color: notifire.getDrawerColor),
//             child: Center(child: SvgPicture.asset(appBarController.isSearch?  "assets/images/times.svg": "assets/images/Search.svg", height: 24, width: 24, color: notifire.getIconColor)),
//           ),
//         ),
//         isphon? const SizedBox(width: 10,): const SizedBox(),
//
//
//
//
//         Stack(
//           alignment: Alignment.center,
//           children: [
//             Container(
//               height: 48,
//               margin: const EdgeInsets.symmetric(horizontal: 8),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(120),
//                 color: appBarController.isAccount?  notifire.getGry100_300Color :notifire.getDrawerColor,
//               ),
//               width: isphon? 50 :165,
//             ),
//             PopupMenuButton(
//               onOpened: () {
//                 appBarController.setisAccount(true);
//               },
//               onCanceled: () {
//                 appBarController.setisAccount(false);
//               },
//               color: notifire.getContainerColor,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               offset:  Offset(10, isphon? 55 :85),
//               constraints:  BoxConstraints(
//                   minHeight: size<600? 500 : 450,
//                   maxHeight: size<600? 500 : 450,
//                   maxWidth: 280,
//                   minWidth: 280
//               ),
//               tooltip: "",
//               itemBuilder: (ctx) => [
//                 account(isphon: isphon),
//               ],
//               padding: EdgeInsets.zero,
//               child: isphon?   const CircleAvatar(
//                   radius: 15,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/05.png")) : Container(
//                 // height: 48,
//                 width: 180,
//                 color: Colors.transparent,
//                 child: Center(
//                   child: ListTile(
//                     onTap: null,
//                     trailing: Transform.translate(
//                         offset: const Offset(-10, 0),
//                         child: SvgPicture.asset(appBarController.isAccount? "assets/images/chevron-up.svg"  :"assets/images/chevron-down.svg")),
//                     leading:  const CircleAvatar(
//                         radius: 15,
//                         backgroundColor: Colors.transparent,
//                         backgroundImage:
//                         AssetImage("assets/images/05.png")),
//                     title: Text("Elon ".tr, style: Typographyy.bodyLargeMedium.copyWith(color:  notifire.getTextColor)),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//       leadingWidth: isphon? 60 : 150,
//       leading: isphon ? InkWell(
//           onTap: () {
//             Scaffold.of(context).openDrawer();
//           },
//           child: SizedBox(
//               height: 20,
//               width: 40,
//               child: Center(child: SvgPicture.asset("assets/images/menu-left.svg",height: 20,width: 20,color: notifire.getTextColor,))) ) : Center(child: Text(widget.title, overflow: TextOverflow.ellipsis, style: Typographyy.heading5.copyWith(color: notifire.getTextColor))),
//
//
//
//
//       centerTitle: true,
//       title: Row(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           appBarController.isSearch ? Flexible(
//             child: SizedBox(
//               height: 42,
//               width: 500,
//               child: Center(
//                 child: TextField(
//                   style: Typographyy.bodyMediumMedium.copyWith(color: notifire.getGry500_600Color),
//                   decoration: InputDecoration(
//                       hintStyle: Typographyy.bodyMediumMedium.copyWith(color: notifire.getGry500_600Color),
//                       isDense: true,
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: BorderSide(color: notifire.getGry700_300Color)),
//                       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: BorderSide(color: notifire.getGry700_300Color)),
//                       hintText: "Search.."
//                   ),
//                 ),
//               ),
//             ),
//           ): const SizedBox(),
//         ],
//       ),
//     );
//   }
//
//   PopupMenuItem search(){
//     return PopupMenuItem(
//         enabled: false,
//         child: SizedBox(
//           height: 42,
//           child: Center(
//             child: TextField(
//               style: Typographyy.bodyMediumMedium.copyWith(color: notifire.getGry500_600Color),
//               decoration: InputDecoration(
//                   hintStyle: Typographyy.bodyMediumMedium.copyWith(color: notifire.getGry500_600Color),
//                   isDense: true,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: BorderSide(color: notifire.getGry700_300Color)),
//                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: BorderSide(color: notifire.getGry700_300Color)),
//                   hintText: "Search.."
//               ),
//             ),
//           ),
//         ));
//   }
//   PopupMenuItem language(){
//     return PopupMenuItem(
//         padding: EdgeInsets.zero,
//         child:
//         SizedBox(
//           height: 300,
//           width: 160,
//           child: ListView.builder(
//             shrinkWrap: true,
//             padding: const EdgeInsets.all(0),
//             itemCount: appBarController.countryLogo.length,
//             itemBuilder: (context, index) {
//               return ListTile(
//                 onTap: () {
//                   appBarController.selectlanguage(index);
//                   Future.delayed(const Duration(milliseconds: 200),() {
//                     Get.back();
//                   },);
//                 },
//                 leading: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: CircleAvatar(
//                     radius: 15,
//                     backgroundColor: Colors.transparent,
//                     child: SvgPicture.asset(appBarController.countryLogo[index]),
//                   ),
//                 ),
//                 title: Text(appBarController.lanuage[index], style: Typographyy.bodyLargeMedium.copyWith(color:  notifire.getTextColor),maxLines: 1),
//               );
//             },),
//         ));
//   }
//   PopupMenuItem account({required bool isphon}) {
//     return PopupMenuItem(
//         enabled: true,
//         padding: EdgeInsets.zero,
//         child:  GetBuilder<DrawerControllerr>(
//             builder: (controllerr) {
//               return StatefulBuilder(
//                   builder: (context, setState){
//                     return Padding(
//                       padding: const EdgeInsets.all(8),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           ListTile(
//                             title: Text(
//                               "Elon Musk",
//                               style: Typographyy.bodyLargeExtraBold
//                                   .copyWith(color: notifire.getTextColor),
//                             ),
//                             subtitle: Padding(
//                               padding: const EdgeInsets.only(top: 4),
//                               child: Text("Business account",
//                                   style: Typographyy.bodySmallMedium
//                                       .copyWith(color: notifire.getGry500_600Color)),
//                             ),
//                           ),
//                           Divider(
//                             color: notifire.getGry700_300Color,
//                             height: 8,
//                           ),
//                           ListTile(
//                             onTap: () {
//                               Get.back();
//                               controllerr.colorSelecter(value: 17);
//                               controllerr.function(value: -1);
//                               Navigator.pushNamed(context, '/settings');
//                             },
//                             dense: true,
//                             leading: SizedBox(
//                                 height: 22,
//                                 width: 22,
//                                 child: SvgPicture.asset("assets/images/user.svg",height: 22,width: 22,color: notifire.getGry500_600Color,)),
//                             title: Text("Your details".tr,style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                             subtitle: Text("Important account details".tr,style: Typographyy.bodySmallMedium.copyWith(color: notifire.getGry500_600Color)),
//                           ),
//                           ListTile(
//                             onTap: () {
//                               Get.back();
//                               controllerr.colorSelecter(value: 17);
//                               controllerr.function(value: -1);
//                               Navigator.pushNamed(context, '/settings');
//                             },
//                             dense: true,
//                             leading: SizedBox(
//                                 height: 22,
//                                 width: 22,
//                                 child: SvgPicture.asset("assets/images/fingerprint-viewfinder.svg",height: 22,width: 22,color: notifire.getGry500_600Color,)),
//
//                             subtitle: Text("Setup 2FA for more security".tr,style: Typographyy.bodySmallMedium.copyWith(color: notifire.getGry500_600Color)),
//                             title: Text("2FA security".tr,style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                           ),
//                           ListTile(
//                             onTap: () {
//                               Get.back();
//                               controllerr.colorSelecter(value: 17);
//                               controllerr.function(value: -1);
//                               Navigator.pushNamed(context, '/settings');
//                             },
//                             dense: true,
//                             leading: SizedBox(
//                                 height: 22,
//                                 width: 22,
//                                 child: SvgPicture.asset("assets/images/share.svg",height: 22,width: 22,color: notifire.getGry500_600Color,)),
//
//                             subtitle: Text("Invite your friends and earn rewards".tr,style: Typographyy.bodySmallMedium.copyWith(color: notifire.getGry500_600Color)),
//                             title: Text("Referrals".tr,style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                           ),
//                           ListTile(
//                             onTap: () {
//                               Get.back();
//                               controllerr.colorSelecter(value: 17);
//                               controllerr.function(value: -1);
//                               Navigator.pushNamed(context, '/settings');
//                             },
//                             dense: true,
//                             leading: SizedBox(
//                                 height: 22,
//                                 width: 22,
//                                 child: SvgPicture.asset("assets/images/settings.svg",height: 22,width: 22,color: notifire.getGry500_600Color,)),
//
//                             subtitle: Text("View additional settings".tr,style: Typographyy.bodySmallMedium.copyWith(color: notifire.getGry500_600Color)),
//                             title: Text("Account settings".tr,style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                           ),
//                           const SizedBox(height: 8,),
//                           ListTile(
//                             onTap: () {
//                               Get.back();
//
//                               controllerr.colorSelecter(value: 8);
//                             },
//                             dense: true,
//                             leading: SizedBox(
//                                 height: 22,
//                                 width: 22,
//                                 child: SvgPicture.asset("assets/images/tabler_logout.svg",height: 22,width: 22,color: notifire.getGry500_600Color,)),
//                             title: Text("Log out".tr,style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                           ),
//                           Divider(
//                             color: notifire.getGry700_300Color,
//                             height: 8,
//                           ),
//                           Consumer<ColorNotifire>(
//                             builder: (context, value, child) => ListTile(
//                               title: Text("Dark mode",style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                               trailing: Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                                 child: CupertinoSwitch(
//                                   value: notifire.getIsDark,
//                                   activeColor: Colors.black,
//                                   offLabelColor: Colors.grey,
//                                   onChanged: (value) async{
//                                     notifire.isavalable(value);
//                                     Get.back();
//                                   },),
//                               ),
//                             ),
//                           ),
//                           ListTile(
//                             title: Text("RTL",style: Typographyy.bodyMediumSemiBold.copyWith(color: notifire.getTextColor)),
//                             trailing:  Switch(
//                               value: controllerr.isRtl,
//                               onChanged: (bool value) {
//                                 controllerr.setRTL(value);
//                                 Get.back();
//                                 if (value == true) {
//                                   Get.updateLocale(const Locale('ur', 'PK'));
//                                   Get.back();
//                                 } else {
//                                   Get.updateLocale(const Locale('en', 'US'));
//                                   Get.back();
//                                 }
//
//
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }
//               );
//             }
//         )
//     );
//   }
//   PopupMenuItem notification({required bool isphon}) {
//     return PopupMenuItem(
//         enabled: false,
//         padding: EdgeInsets.zero,
//         child: SizedBox(
//           height: isphon? 420 :700,
//           width: 396,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text("Notifications".tr,
//                         style: Typographyy.bodyLargeExtraBold
//                             .copyWith(color: notifire.getTextColor)),
//                     Row(
//                       children: [
//                         SvgPicture.asset("assets/images/checks.svg",
//                             width: 20, height: 20),
//                         const SizedBox(
//                           width: 5,
//                         ),
//                         Text("Mark all as read".tr,
//                             style: Typographyy.bodyMediumExtraBold
//                                 .copyWith(color: notifire.getBgPrimaryColor)),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Divider(color: notifire.getGry700_300Color, height: 20),
//               ListTile(
//                 titleAlignment: ListTileTitleAlignment.top,
//                 leading: const CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/05.png"),
//                 ),
//                 title: Text("Modi Ji".tr, style: Typographyy.bodyMediumExtraBold.copyWith(color: notifire.getTextColor)),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                         text: TextSpan(children: [
//                           TextSpan(
//                               text: "You have sent ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "\$200.00 ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: const Color(0xffFF784B))),
//                           TextSpan(
//                               text: "to ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "Elon Musk".tr,
//                               style: Typographyy.bodySmallExtraBold
//                                   .copyWith(color: notifire.getTextColor)),
//                         ])),
//                     const SizedBox(
//                       height: 8,
//                     ),
//                     Text(
//                       "2 mins ago".tr,
//                       style: Typographyy.bodySmallExtraBold
//                           .copyWith(color: notifire.getGry500_600Color),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 10,),
//               ListTile(
//                 titleAlignment: ListTileTitleAlignment.top,
//                 leading: const CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/Frame 24.png"),
//                 ),
//                 title: Text("New Invoice Sent".tr,
//                     style: Typographyy.bodyMediumExtraBold
//                         .copyWith(color: notifire.getTextColor)),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                         text: TextSpan(children: [
//                           TextSpan(
//                               text: "You have sent a new invoice of ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "\$4,567.00  ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: const Color(0xff22C55E))),
//                           TextSpan(
//                               text: "to ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "Messi".tr,
//                               style: Typographyy.bodySmallExtraBold
//                                   .copyWith(color: notifire.getTextColor)),
//                         ])),
//                     const SizedBox(
//                       height: 8,
//                     ),
//                     Text(
//                       "5 mins ago".tr,
//                       style: Typographyy.bodySmallExtraBold
//                           .copyWith(color: notifire.getGry500_600Color),
//                     )
//                   ],
//                 ),
//               ),
//               isphon?  const SizedBox(): const SizedBox(height: 10,),
//               isphon?  const SizedBox():ListTile(
//                 titleAlignment: ListTileTitleAlignment.top,
//                 leading: const CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/01.png"),
//                 ),
//                 title: Text("Cristiano Ronaldo".tr,
//                     style: Typographyy.bodyMediumExtraBold
//                         .copyWith(color: notifire.getTextColor)),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                         text: TextSpan(children: [
//                           TextSpan(
//                               text: "You have a new payment request from ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "M.s Dhoni ".tr,
//                               style: Typographyy.bodySmallExtraBold
//                                   .copyWith(color: notifire.getTextColor)),
//                           TextSpan(
//                               text: "for ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "\$800.00 ",
//                               style: Typographyy.bodySmallExtraBold
//                                   .copyWith(color: const Color(0xffFF784B))),
//                         ])),
//                     const SizedBox(
//                       height: 8,
//                     ),
//                     Text(
//                       "1 hour ago".tr,
//                       style: Typographyy.bodySmallExtraBold
//                           .copyWith(color: notifire.getGry500_600Color),
//                     ),
//                     const SizedBox(
//                       height: 16,
//                     ),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                               onPressed: () {},
//                               style: OutlinedButton.styleFrom(
//                                   side: BorderSide(
//                                       color: notifire.getGry700_300Color),
//                                   shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(8)),
//                                   fixedSize: const Size.fromHeight(40)),
//                               child: Text(
//                                 "Decline".tr,
//                                 style: Typographyy.bodySmallExtraBold
//                                     .copyWith(color: notifire.getTextColor),
//                               )),
//                         ),
//                         const SizedBox(
//                           width: 12,
//                         ),
//                         Expanded(
//                           child: OutlinedButton(
//                               onPressed: () {},
//                               style: OutlinedButton.styleFrom(
//                                   side: BorderSide(color: notifire.getBgPrimaryColor),
//                                   backgroundColor: notifire.getBgPrimaryColor,
//                                   shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(8)),
//                                   fixedSize: const Size.fromHeight(40)),
//                               child: Text(
//                                 "Pay Now".tr,
//                                 style: Typographyy.bodySmallExtraBold
//                                     .copyWith(color: whiteColor),
//                               )),
//                         )
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               isphon?  const SizedBox(): const SizedBox(height: 10,),
//               ListTile(
//                 titleAlignment: ListTileTitleAlignment.top,
//                 leading: const CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/avatar-11.png"),
//                 ),
//                 title: Text("Payment Received".tr,
//                     style: Typographyy.bodyMediumExtraBold
//                         .copyWith(color: notifire.getTextColor)),
//                 subtitle: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                         text: TextSpan(children: [
//                           TextSpan(
//                               text: "Received a new payment ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "\$100  ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: const Color(0xff194BFB))),
//                           TextSpan(
//                               text: "from ".tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                           TextSpan(
//                               text: "Jonathan Amral".tr,
//                               style: Typographyy.bodySmallExtraBold
//                                   .copyWith(color: notifire.getTextColor)),
//                         ])),
//                     const SizedBox(
//                       height: 8,
//                     ),
//                     Text(
//                       "18 hour ago".tr,
//                       style: Typographyy.bodySmallExtraBold
//                           .copyWith(color: notifire.getGry500_600Color),
//                     )
//                   ],
//                 ),
//               ),
//               const SizedBox(
//                 height: 10,
//               ),
//               ListTile(
//                 titleAlignment: ListTileTitleAlignment.top,
//                 leading: const CircleAvatar(
//                   radius: 24,
//                   backgroundColor: Colors.transparent,
//                   backgroundImage: AssetImage("assets/images/icon.png"),
//                 ),
//                 title: Text("Deposit Cryptocurrency".tr,
//                     style: Typographyy.bodyMediumExtraBold
//                         .copyWith(color: notifire.getTextColor)),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                         text: TextSpan(children: [
//                           TextSpan(
//                               text:
//                               "Massa, vel donec tempor at quisque eget sapien. Ut sit orc"
//                                   .tr,
//                               style: Typographyy.bodySmallMedium
//                                   .copyWith(color: notifire.getGry500_600Color)),
//                         ])),
//                     const SizedBox(
//                       height: 8,
//                     ),
//                     Text(
//                       "Yesterday".tr,
//                       style: Typographyy.bodySmallExtraBold
//                           .copyWith(color: notifire.getGry500_600Color),
//                     )
//                   ],
//                 ),
//               ),
//               Divider(color: notifire.getGry700_300Color, height: 20),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text("See all notifications".tr,
//                         style: Typographyy.bodyMediumExtraBold
//                             .copyWith(color: notifire.getBgPrimaryColor)),
//                     SvgPicture.asset(
//                       "assets/images/settings.svg",
//                       height: 24,
//                       width: 24,
//                     ),
//                   ],
//                 ),
//               )
//             ],
//           ),
//         ));
//   }
// }
