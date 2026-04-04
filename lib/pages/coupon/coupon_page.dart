// Em: lib/pages/coupon/coupon_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/core/upper_case_text_formatter.dart';

// Models
import 'package:totem/models/coupon.dart';

// Cubits e States
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';

// Widgets e Temas
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

class TicketClipper extends CustomClipper<Path> {
  final double holeRadius;
  final double top;

  TicketClipper({this.holeRadius = 10.0, this.top = 0.5});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.addOval(
      Rect.fromCircle(center: Offset(0, size.height * top), radius: holeRadius),
    );
    path.addOval(
      Rect.fromCircle(
        center: Offset(size.width, size.height * top),
        radius: holeRadius,
      ),
    );
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  bool _isLoading = false;
  final TextEditingController _couponCodeController = TextEditingController();
  final Set<String> _expandedCoupons = {};

  @override
  void dispose() {
    _couponCodeController.dispose();
    super.dispose();
  }

  /// Aplica um cupom - Se já tiver outro, remove primeiro
  Future<void> _applyCoupon(String code) async {
    if (_isLoading || code.isEmpty) return;
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final cartCubit = context.read<CartCubit>();
      final currentCoupon = cartCubit.state.cart.couponCode;

      // ✅ Se já tem cupom diferente, remove primeiro para garantir só 1
      if (currentCoupon != null &&
          currentCoupon.toUpperCase() != code.toUpperCase()) {
        await cartCubit.removeCoupon();
      }

      await cartCubit.applyCoupon(code);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Remove o cupom atual e limpa descontos
  Future<void> _removeCoupon() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await context.read<CartCubit>().removeCoupon();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cupom removido'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        // ✅ NÃO dá pop() aqui - deixa o usuário na tela de cupons
        setState(() {}); // Força rebuild para refletir o estado
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao remover cupom: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.primaryColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'CUPONS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade100, height: 1.0),
        ),
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, cartState) {
          final appliedCouponCode = cartState.cart.couponCode;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCouponCodeField(theme),
                ),
                const SizedBox(height: 24),
                _buildFreeCouponsBanner(theme),
                const SizedBox(height: 24),
                _buildNoCouponOption(theme, appliedCouponCode),
                const SizedBox(height: 16),
                _buildCouponsList(theme, appliedCouponCode),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCouponCodeField(DsTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.local_offer, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _couponCodeController,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                hintText: 'Código de cupom',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          TextButton(
            onPressed:
                _couponCodeController.text.isNotEmpty && !_isLoading
                    ? () => _applyCoupon(_couponCodeController.text)
                    : null,
            child: Text(
              'Aplicar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    _couponCodeController.text.isNotEmpty
                        ? theme.primaryColor
                        : Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCouponsBanner(DsTheme theme) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        final availableCount =
            state.store?.coupons.where((c) => c.isValidForDisplay).length ?? 0;
        if (availableCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipPath(
            clipper: TicketClipper(holeRadius: 8, top: 0.5),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Você ganhou cupom grátis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer,
                                size: 14,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$availableCount disponíveis',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoCouponOption(DsTheme theme, String? appliedCouponCode) {
    final isSelected = appliedCouponCode == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected ? Border.all(color: theme.primaryColor, width: 1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              appliedCouponCode != null
                  ? _removeCoupon
                  : null, // ✅ Só habilita se tiver cupom
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Não quero cupom',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected ? theme.primaryColor : Colors.grey.shade200,
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCouponsList(DsTheme theme, String? appliedCouponCode) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        final coupons =
            state.store?.coupons.where((c) => c.isValidForDisplay).toList() ??
            [];

        return Column(
          children:
              coupons.map((coupon) {
                final isSelected =
                    appliedCouponCode?.toUpperCase() ==
                    coupon.code.toUpperCase();
                return _buildCouponCard(coupon, theme, isSelected);
              }).toList(),
        );
      },
    );
  }

  Widget _buildCouponCard(Coupon coupon, DsTheme theme, bool isSelected) {
    bool isExpanded = _expandedCoupons.contains(coupon.code);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _applyCoupon(coupon.code),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_offer,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDiscountValue(coupon),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCouponDescription(coupon),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (coupon.minOrderValue != null &&
                              coupon.minOrderValue! > 0)
                            Text(
                              'Válido para pedidos acima de ${coupon.minOrderValue!.toCurrency}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected
                                    ? theme.primaryColor
                                    : Colors.grey.shade200,
                          ),
                          child:
                              isSelected
                                  ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        if (coupon.endDate != null)
                          Text(
                            _getExpiryText(coupon),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        const SizedBox(height: 2),
                        const Text(
                          '1 disponível',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCoupons.remove(coupon.code);
                      } else {
                        _expandedCoupons.add(coupon.code);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Regras',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  ..._buildRulesList(coupon),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRulesList(Coupon coupon) {
    final texts = <String>[];
    if (coupon.isForFirstOrder) texts.add('Válido apenas para primeira compra');
    if (coupon.maxUsesPerCustomer != null)
      texts.add('Limite de ${coupon.maxUsesPerCustomer} uso(s) por cliente');
    if (coupon.targetAudience != null && coupon.targetAudience != 'ALL')
      texts.add(coupon.targetAudienceText);
    if (coupon.deliveryRadius != null)
      texts.add('Raio de entrega: ${coupon.deliveryRadius}');
    if (texts.isEmpty) texts.add('Sem regras adicionais');

    return texts
        .map(
          (t) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 4, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  String _getDiscountValue(Coupon coupon) {
    if (coupon.discountType == 'PERCENTAGE')
      return '${coupon.discountValue.toInt()}%';
    if (coupon.discountType == 'FIXED_AMOUNT')
      return coupon.discountValue.toInt().toCurrency;
    if (coupon.discountType == 'FREE_DELIVERY') return 'FRETE GRÁTIS';
    return '';
  }

  String _getCouponDescription(Coupon coupon) {
    if (coupon.title != null) return coupon.title!;
    if (coupon.discountType == 'PERCENTAGE')
      return '${coupon.discountValue.toInt()}% para pedir onde quiser';
    if (coupon.discountType == 'FIXED_AMOUNT')
      return '${coupon.discountValue.toInt().toCurrency} para pedir onde quiser';
    return 'Aproveite seu desconto';
  }

  String _getExpiryText(Coupon coupon) {
    if (coupon.endDate == null) return '';
    final diff = coupon.endDate!.difference(DateTime.now());
    if (diff.isNegative) return 'Expirado';
    if (diff.inDays > 0) return 'Acaba em ${diff.inDays}d';
    if (diff.inHours > 0)
      return 'Acaba em ${diff.inHours}h ${diff.inMinutes % 60}min';
    return 'Acaba em ${diff.inMinutes}min';
  }
}
