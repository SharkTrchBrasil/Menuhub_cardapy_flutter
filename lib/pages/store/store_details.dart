import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/pages/store/widgetss/payment_methods.dart';
import 'package:totem/pages/store/widgetss/store_opening_hours.dart';
import '../../core/extensions.dart';
import '../../models/rating.dart';
// import '../../themes/ds_theme_switcher.dart'; // Removido, se não for mais necessário para o tema
import '../../themes/ds_theme_switcher.dart';
import '../../widgets/app_rating_item_widget.dart';
import '../../widgets/app_review_rating_widget.dart';
import '../../cubit/store_cubit.dart';

class StoreDetails extends StatefulWidget {
  final int initialTabIndex;

  const StoreDetails({super.key, this.initialTabIndex = 0});

  @override
  State<StoreDetails> createState() => _StoreDetailsState();
}

class _StoreDetailsState extends State<StoreDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    // Removida a linha que pega o tema, se não for mais usada para outras cores.
    final theme = context.watch<DsThemeSwitcher>().theme;

    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded, // seta fina e moderna
                  color: Colors.red,
                  size: 22,
                ),
                onPressed: () => context.pop(),
              ),

              expandedHeight: 400, // ✅ Aumentado para acomodar conteúdo
              flexibleSpace: FlexibleSpaceBar(
                background: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    store.name ?? 'Nome da Loja',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (store
                                          .store_operation_config
                                          ?.deliveryMinOrder !=
                                      null)
                                    Text(
                                      'Pedido mínimo: R\$ ${store.store_operation_config!.deliveryMinOrder!.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 12),
                                  if (store.ratingsSummary != null)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          store.ratingsSummary!.averageRating
                                              .toStringAsFixed(1)
                                              .replaceAll('.', ','),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (index) {
                                            final starIndex = index + 1;
                                            return Icon(
                                              starIndex <=
                                                      store
                                                          .ratingsSummary!
                                                          .averageRating
                                                          .round()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 20,
                                            );
                                          }),
                                        ),
                                        // ✅ Removido Flexible - Wrap não suporta Flexible
                                        // Usando Text com constraints via SizedBox para limitar largura
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Text(
                                            '(${store.ratingsSummary!.totalRatings} ${store.ratingsSummary!.totalRatings == 1 ? "avaliação" : "avaliações"})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // ✅ Imagem com tamanho fixo para evitar overflow
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  store.image?.url ??
                                      'https://images.ctfassets.net/kugm9fp9ib18/3aHPaEUU9HKYSVj1CTng58/d6750b97344c1dc31bdd09312d74ea5b/menu-default-image_220606_web.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  // ✅ Tratamento de erro - mostra placeholder se falhar
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.store,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (store.ratingsSummary != null)
                          AppReviewRatingWidget(
                            ratingsSummary: store.ratingsSummary!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  dividerColor: Colors.transparent,
                  unselectedLabelColor: theme.categoryTextColor,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  controller: _tabController,
                  tabs: const [
                    Tab(text: "Avaliações"),
                    Tab(text: "Informações"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  (store.ratingsSummary?.ratings != null &&
                          store.ratingsSummary!.ratings.isNotEmpty)
                      ? ListView.builder(
                        itemCount: store.ratingsSummary!.ratings.length,
                        itemBuilder: (context, index) {
                          final rating = store.ratingsSummary!.ratings[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: AppRatingItemWidget(rating: rating),
                          );
                        },
                      )
                      : const Center(
                        child: Text("Nenhuma avaliação disponível"),
                      ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Descrição",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (store.description != null)
                    Text(
                      store.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 16),
                  StoreOpeningHours(hours: store.hours ?? [], store: store),
                  PaymentMethodsWidget(
                    paymentGroups: store.paymentMethodGroups,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Endereço",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${store.street ?? '-'}, ${store.number ?? '-'}\n"
                    "${store.neighborhood ?? '-'}, ${store.city ?? '-'} - ${store.state ?? '-'}\n"
                    "CEP: ${store.zip_code ?? '-'}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      // Remova ou comente esta linha para usar o tema padrão
      // color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return false;
  }
}
