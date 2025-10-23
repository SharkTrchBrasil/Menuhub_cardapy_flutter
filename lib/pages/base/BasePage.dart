

import 'package:flutter/material.dart';


import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive_builder.dart';
import '../../helpers/constants.dart';
import '../../themes/classic/widgets/sidebar.dart';




class BasePage extends StatefulWidget {




  BasePage(
      {super.key,
        required this.bodyMobile,
        required this.bodyTablet,
        this.shouldShowAppBar = false,
        this.shouldShowDrawer = true,
        this.showLeading = false,
        this.rightDesktop = true,
        this.showActions = false,
        required this.rightDesktopWidget,
        required this.bodyDesktop



      });

  final Widget bodyMobile;
  final Widget bodyTablet;
  final Widget bodyDesktop;
  Widget? rightDesktopWidget;
  final bool rightDesktop;
  final bool shouldShowDrawer;
  final bool shouldShowAppBar;
  final bool showLeading;
  final bool showActions;

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {


  final GlobalKey<ScaffoldState> _key = GlobalKey();

  @override
  Widget build(BuildContext context) {

    widget.showActions == true;

    return Scaffold(
      key: _key,


      body: ResponsiveBuilder(
        mobileBuilder: (context, constraints) {
          return widget.bodyMobile;
        },
        tabletBuilder: (context, constraints) {
          return ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                        flex: (constraints.maxWidth < 950) ? 6 : 9,
                        child: widget.bodyTablet),

                    /*

              Flexible(
                flex: 4,
                child: Column(
                  children: [
                    SizedBox(height: kSpacing * (kIsWeb ? 0.5 : 1.5)),
                    //  buildProfile(),
                    //    const Divider(thickness: 1),
                    //   const SizedBox(height: kSpacing),
                    //   _buildTeamMember(data: controller.getMember()),
                    //    const SizedBox(height: kSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing),
                      child: GetPremiumCard(onPressed: () {}),
                    ),
                    SizedBox(height: kSpacing),
                    Divider(thickness: 1),
                    SizedBox(height: kSpacing),
                    buildRecentMessages(),
                  ],
                ),
              )


               */
                  ],
                ),
              ]);
        },
        desktopBuilder: (context, constraints) {
          return Row(
            children: [


              Expanded(
                flex: 6,
                child: widget.bodyDesktop,
              ),
              SizedBox(
                width: 10,
              ),
              widget.rightDesktopWidget == null
                  ? Flexible(
                flex: 2,
                child: ListView(

                  children: [


                    // Observer(
                    //   builder: (BuildContext context) {
                    //
                    //
                    //     return HeaderBase(
                    //         showSeeAllButton: false,
                    //         onPressedSeeAll: () {},
                    //         title: AppLocalizations.of(context)!.newRadiosAdded,
                    //         child: SizedBox(
                    //             height: 140,
                    //             child: ListView.builder(
                    //                 padding: EdgeInsets.zero,
                    //                 itemCount: homeStore
                    //                     .listAddRec.length,
                    //                 itemBuilder: (context, index) =>
                    //                     BaseTile(
                    //                       radioModel: homeStore
                    //                           .listAddRec[index],
                    //                     ))));
                    //   },
                    // ),
                    // SizedBox(height: kSpacing),
                    // userController.isLoggedIn
                    //     ? Observer(
                    //   builder: (BuildContext context) {
                    //     if (favoriteStore.theeFavorites.isEmpty) {
                    //       return const SizedBox();
                    //     }
                    //
                    //     return HeaderBase(
                    //       showSeeAllButton: true,
                    //       onPressedSeeAll: () {
                    //         GoRouter.of(context)
                    //             .go(RouteUri.favorites);
                    //       },
                    //       title: AppLocalizations.of(context)!
                    //           .favorites,
                    //       child: SizedBox(
                    //         height: 200,
                    //         child: ListView.builder(
                    //             padding: EdgeInsets.zero,
                    //             itemCount: favoriteStore
                    //                 .theeFavorites.length,
                    //             itemBuilder: (context, index) =>
                    //                 BaseTile(
                    //                   radioModel: favoriteStore
                    //                       .theeFavorites[index],
                    //                   trailing: true,
                    //                 )),
                    //       ),
                    //     );
                    //   },
                    // )
                    //     : SizedBox(),
                    // SizedBox(height: kSpacing),
                    // userController.isLoggedIn
                    //     ? Observer(
                    //   builder: (BuildContext context) {
                    //     if (browsingStore
                    //         .recentBrowsing.isEmpty) {
                    //       return const SizedBox();
                    //     }
                    //
                    //     return HeaderBase(
                    //       showSeeAllButton: true,
                    //       onPressedSeeAll: () {
                    //         GoRouter.of(context)
                    //             .go(RouteUri.history);
                    //       },
                    //       title: AppLocalizations.of(context)!
                    //           .history,
                    //       child: SizedBox(
                    //         height: 320,
                    //         child: ListView.builder(
                    //             padding: EdgeInsets.zero,
                    //             itemCount: browsingStore
                    //                 .recentBrowsing.length,
                    //             itemBuilder: (context, index) =>
                    //                 BaseTile(
                    //                   trailingArrow: true,
                    //                   radioModel: browsingStore
                    //                       .recentBrowsing[index],
                    //                 )),
                    //       ),
                    //     );
                    //   },
                    // )
                    //     : SizedBox(),
                    // const SizedBox(height: kSpacing),
                    // Observer(
                    //   builder: (BuildContext context) {
                    //     if (partNerStore.listRadiosPartners.isEmpty) {
                    //       return const SizedBox();
                    //     }
                    //
                    //     return HeaderBase(
                    //       showSeeAllButton: true,
                    //       onPressedSeeAll: () {
                    //         GoRouter.of(context)
                    //             .go(RouteUri.partners);
                    //       },
                    //       title: AppLocalizations.of(context)!
                    //           .partners,
                    //       child: SizedBox(
                    //         height: 320,
                    //         child: ListView.builder(
                    //             padding: EdgeInsets.zero,
                    //             itemCount: partNerStore.partnersCount,
                    //             itemBuilder: (context, index) =>
                    //                 BaseTile(
                    //                   trailingArrow: false,
                    //                   radioModel: partNerStore.listRadiosPartners[index],
                    //                 )),
                    //       ),
                    //     );
                    //   },
                    // ),
                    //






                  ],
                ),
              )
                  : widget.rightDesktopWidget!,


              //   FooterView()

            ],
          );

          /*
          return SingleChildScrollView(

            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Sidebar(),
                    ),
                    Flexible(
                        flex: 9, child: widget.bodyDesktop),



                    widget.rightDesktop ?



                    Flexible(
                      flex: 4,
                      child: SingleChildScrollView(

                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [


                            Observer(
                              builder: (BuildContext context) {
                                if (homeStore.radiosGetPopular.isEmpty) {
                                  return const SizedBox();
                                }

                                return HeaderBase(
                                    showSeeAllButton: false,
                                    onPressedSeeAll: () {},
                                    title: 'ULTIMAS ADICIONADAS',
                                    child: SizedBox(
                                        height: 180,
                                        child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            itemCount:
                                                homeStore.radiosAddRecent.length,
                                            itemBuilder: (context, index) =>
                                                BaseTile(
                                                  radioModel: homeStore
                                                      .radiosAddRecent[index],
                                                ))));
                              },
                            ),
                            SizedBox(height: kSpacing),
                            userController.isLoggedIn
                                ? Observer(
                                    builder: (BuildContext context) {
                                      if (favoriteStore.theeFavorites.isEmpty) {
                                        return const SizedBox();
                                      }

                                      return HeaderBase(
                                        showSeeAllButton: true,
                                        onPressedSeeAll: () {
                                          GoRouter.of(context)
                                              .go(RouteUri.favorites);
                                        },
                                        title: AppLocalizations.of(context)!
                                            .favorites,
                                        child: SizedBox(
                                          height: 200,
                                          child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: favoriteStore
                                                  .theeFavorites.length,
                                              itemBuilder: (context, index) =>
                                                  BaseTile(
                                                    radioModel: favoriteStore
                                                        .theeFavorites[index],
                                                    trailing: true,
                                                  )),
                                        ),
                                      );
                                    },
                                  )
                                : SizedBox(),
                            SizedBox(height: kSpacing),
                            userController.isLoggedIn
                                ? Observer(
                                    builder: (BuildContext context) {
                                      if (browsingStore.recentBrowsing.isEmpty) {
                                        return const SizedBox();
                                      }

                                      return HeaderBase(
                                        showSeeAllButton: true,
                                        onPressedSeeAll: () {
                                          GoRouter.of(context)
                                              .go(RouteUri.history);
                                        },
                                        title:
                                            AppLocalizations.of(context)!.history,
                                        child: SizedBox(
                                          height: 320,
                                          child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: browsingStore
                                                  .recentBrowsing.length,
                                              itemBuilder: (context, index) =>
                                                  BaseTile(
                                                    trailingArrow: true,
                                                    radioModel: browsingStore
                                                        .recentBrowsing[index],
                                                  )),
                                        ),
                                      );
                                    },
                                  )
                                : SizedBox(),
                            const SizedBox(height: kSpacing),
                          ],
                        ),
                      ),
                    ): SizedBox.shrink(),
                  ],
                ),
                FooterView()
              ],
            ),
          );



           */


        },
      ),
   //   bottomNavigationBar: widget.,
    );
  }
//
// Widget _buildRecentRadios() {
//   return Column(children: [
//     const SizedBox(height: kSpacing / 2),
//     ...homeStore.radiosAddRecent
//         .map(
//           (e) => Container(
//             child: Text(e.title),
//           ),
//         )
//         .toList(),
//   ]);
// }
}
