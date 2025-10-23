// Em: lib/pages/coupon/coupon_page.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/core/upper_case_text_formatter.dart';

// Models e Repositories
import 'package:totem/models/coupon.dart';
import 'package:totem/repositories/realtime_repository.dart';

// Cubits e States
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';

// Widgets e Temas
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/ds_secondary_button.dart';
import 'package:totem/widgets/ds_text_field.dart';
import 'package:totem/widgets/dot_loading.dart';


class CouponPage extends StatefulWidget {
  const CouponPage({super.key, required this.realtimeRepository});

  final RealtimeRepository realtimeRepository;

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  // O estado agora é mínimo e focado na UI
  String? _selectedCouponCode;
  bool _isLoading = false;
  late Future<List<Coupon>> _availableCouponsFuture;
  final TextEditingController _couponCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _availableCouponsFuture = _fetchAvailableCoupons();
    // Inicia o RadioList com o cupom que já está no carrinho, vindo do backend.
    _selectedCouponCode = context.read<CartCubit>().state.cart.couponCode;
  }

  @override
  void dispose() {
    _couponCodeController.dispose();
    super.dispose();
  }

  Future<List<Coupon>> _fetchAvailableCoupons() async {
    try {
      // ✅ Agora a chamada é direta e o tipo de retorno é o que o FutureBuilder espera.
      return await widget.realtimeRepository.listCoupons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Retorna uma lista vazia em caso de erro.
      return [];
    }
  }

  /// Ação unificada para aplicar um cupom e tratar a resposta.
  Future<void> _applyCoupon(String code) async {
    if (_isLoading || code.isEmpty) return;

    setState(() => _isLoading = true);
    // Limpa o foco para esconder o teclado
    FocusScope.of(context).unfocus();

    try {
      await context.read<CartCubit>().applyCoupon(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cupom "${code.toUpperCase()}" aplicado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Sucesso, volta para a tela anterior
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Ação unificada para remover o cupom.
  Future<void> _removeCoupon() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await context.read<CartCubit>().removeCoupon();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cupom removido.'),
            backgroundColor: Colors.orange,
          ),
        );
        context.pop();
      }
    } catch (e) {
      // Tratar erro se necessário
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Adicionar Cupom',
          style: theme.displayMediumTextStyle.colored(theme.productTextColor).weighted(FontWeight.bold),
        ),
        backgroundColor: theme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Informe o código do cupom', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                DsTextField(
                  hint: 'Código do cupom',
                  controller: _couponCodeController,
                  formatters: [UpperCaseTextFormatter()],
                  onChanged: (value) {
                    if (value.isNotEmpty && _selectedCouponCode != null) {
                      // Desmarca a seleção da lista se o usuário começar a digitar
                      setState(() => _selectedCouponCode = null);
                    }
                  },
                ),
                const SizedBox(height: 16),

                DsPrimaryButton(

                  onPressed: _couponCodeController.text.isNotEmpty && !_isLoading
                      ? () => _applyCoupon(_couponCodeController.text)
                      : null, label: '',

                  child: _isLoading && _couponCodeController.text.isNotEmpty
                      ? const DotLoading()
                      : const Text('Adicionar Cupom'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                const Text('Cupons disponíveis para você', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FutureBuilder<List<Coupon>>(
                  future: _availableCouponsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Nenhum cupom disponível no momento.', textAlign: TextAlign.center);
                    } else {
                      return Column(
                        children: [
                          RadioListTile<String?>(
                            title: const Text('Não usar cupom'),
                            value: null,
                            groupValue: _selectedCouponCode,
                            onChanged: (value) {
                              if (_isLoading) return;
                              setState(() => _selectedCouponCode = value);
                              _couponCodeController.clear();
                              _removeCoupon();
                            },
                            activeColor: theme.primaryColor,
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final coupon = snapshot.data![index];
                              return RadioListTile<String?>(
                                title: Text(coupon.code.toUpperCase()),

                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    if (coupon.discountType == 'percentage')
                                      Text(
                                        '${coupon.discountValue}% OFF',
                                        style: theme.smallTextStyle
                                            .colored(theme.primaryColor)
                                            .weighted(FontWeight.w600),
                                      )
                                    else if (coupon.discountType == 'fixed')
                                      Text(
                                        '${coupon.discountValue.toCurrency} OFF',
                                        style: theme.smallTextStyle
                                            .colored(theme.primaryColor)
                                            .weighted(FontWeight.w600),
                                      ),


                                    const SizedBox(height: 4),
                                    if (coupon.product != null)
                                      Text(
                                        'Apenas para ${coupon.product!.name}',
                                        style: theme.smallTextStyle
                                            .colored(theme.onCardColor.withOpacity(0.8)),
                                      )
                                    else
                                      Text(
                                        'Válido para toda a sacola.',
                                        style: theme.smallTextStyle
                                            .colored(theme.onCardColor.withOpacity(0.8)),
                                      ),
                                  ],
                                ),

                                value: coupon.code,
                                groupValue: _selectedCouponCode,
                                onChanged: (value) {
                                  if (_isLoading || value == null) return;
                                  setState(() => _selectedCouponCode = value);
                                  _couponCodeController.clear();
                                  _applyCoupon(value);
                                },
                                activeColor: theme.primaryColor,
                              );
                            },
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



