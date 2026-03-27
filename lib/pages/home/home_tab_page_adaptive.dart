import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/catalog_state.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/pages/home/mobile/mobile_home.dart';
import 'package:totem/pages/home/desktop/desktop_home.dart';

import 'package:totem/main.dart' show homeReadySignal;

/// Entry point adaptativo para a página Home
/// Escolhe automaticamente entre mobile e desktop
///
/// ✅ CORREÇÃO: homeReadySignal só dispara quando DADOS estão prontos,
/// não apenas quando o widget é montado. Isso elimina a tela branca.
class HomeTabPageAdaptive extends StatefulWidget {
  const HomeTabPageAdaptive({super.key});

  @override
  State<HomeTabPageAdaptive> createState() => _HomeTabPageAdaptiveState();
}

class _HomeTabPageAdaptiveState extends State<HomeTabPageAdaptive> {
  @override
  void initState() {
    super.initState();
    // ✅ Verifica se os dados já estão disponíveis no primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSignalReady();
    });
  }

  /// ✅ Verifica se CatalogCubit + StoreCubit já possuem dados
  /// e só então sinaliza homeReady para o overlay fazer fade-out.
  void _checkAndSignalReady() {
    if (!mounted || homeReadySignal.value) return;

    final catalogState = context.read<CatalogCubit>().state;
    final storeState = context.read<StoreCubit>().state;

    final hasProducts =
        catalogState.products != null && catalogState.products!.isNotEmpty;
    final hasStore = storeState.store != null;

    if (hasProducts && hasStore) {
      // ✅ Dados prontos → espera mais 1 frame para a UI pintar, depois sinaliza
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !homeReadySignal.value) {
          print('✅ [HomeTabPageAdaptive] Dados prontos! Sinalizando homeReady.');
          homeReadySignal.value = true;
        }
      });
    }
    // Se dados ainda não chegaram, o MultiBlocListener abaixo irá detectar
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // ✅ Escuta CatalogCubit: quando produtos chegarem, verifica readiness
        BlocListener<CatalogCubit, CatalogState>(
          listenWhen: (previous, current) =>
              previous.products != current.products,
          listener: (context, state) => _checkAndSignalReady(),
        ),
        // ✅ Escuta StoreCubit: quando store chegar, verifica readiness
        BlocListener<StoreCubit, StoreState>(
          listenWhen: (previous, current) =>
              previous.store == null && current.store != null,
          listener: (context, state) => _checkAndSignalReady(),
        ),
      ],
      child: ResponsiveBuilder(
        mobileBuilder: (context, constraints) => const MobileHome(),
        tabletBuilder: (context, constraints) => const MobileHome(),
        desktopBuilder: (context, constraints) => const DesktopHome(),
      ),
    );
  }
}
