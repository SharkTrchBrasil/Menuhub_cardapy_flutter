// Em: lib/pages/coupon/coupon_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:coupon_uikit/coupon_uikit.dart';

import 'package:totem/core/upper_case_text_formatter.dart';

// Models
import 'package:totem/models/coupon.dart';

// Cubits e States
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';

// Widgets e Temas
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/ds_text_field.dart';


class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  String? _selectedCouponCode;
  bool _isLoading = false;
  final TextEditingController _couponCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicia com o cupom que já está no carrinho
    _selectedCouponCode = context.read<CartCubit>().state.cart.couponCode;
  }

  @override
  void dispose() {
    _couponCodeController.dispose();
    super.dispose();
  }

  /// Aplica um cupom e trata a resposta
  Future<void> _applyCoupon(String code) async {
    if (_isLoading || code.isEmpty) return;

    setState(() => _isLoading = true);
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
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Mapeia mensagens de erro para mensagens amigáveis
        if (errorMessage.toLowerCase().contains('cupom inválido') ||
            errorMessage.toLowerCase().contains('invalid') ||
            errorMessage.toLowerCase().contains('não é válido')) {
          errorMessage = 'Este cupom não é válido para sua compra.';
        } else if (errorMessage.toLowerCase().contains('expirado') ||
                   errorMessage.toLowerCase().contains('expired')) {
          errorMessage = 'Este cupom já expirou.';
        } else if (errorMessage.toLowerCase().contains('limite') ||
                   errorMessage.toLowerCase().contains('limit')) {
          errorMessage = 'Este cupom atingiu o limite de usos.';
        } else if (errorMessage.toLowerCase().contains('primeira compra') ||
                   errorMessage.toLowerCase().contains('first order')) {
          errorMessage = 'Este cupom é válido apenas para a primeira compra.';
        } else if (errorMessage.toLowerCase().contains('pedido mínimo') ||
                   errorMessage.toLowerCase().contains('min subtotal')) {
          errorMessage = 'O valor do pedido não atende ao mínimo exigido.';
        } else if (errorMessage.toLowerCase().contains('não encontrado') ||
                   errorMessage.toLowerCase().contains('not found')) {
          errorMessage = 'Cupom não encontrado.';
        } else if (errorMessage.isEmpty || errorMessage == 'null') {
          errorMessage = 'Não foi possível aplicar o cupom.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Remove o cupom aplicado
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
      // Erro silencioso
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
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Cupons',
          style: theme.displayMediumTextStyle
              .colored(theme.productTextColor)
              .weighted(FontWeight.bold),
        ),
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.productTextColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seção de digitar código manual
            _buildManualCodeSection(theme),
            
            const SizedBox(height: 32),
            
            // Divider com texto
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'ou escolha um cupom',
                    style: theme.smallTextStyle.colored(Colors.grey),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Lista de cupons do StoreCubit
            _buildCouponsList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCodeSection(DsTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Tem um código?',
                style: theme.bodyTextStyle
                    .colored(theme.productTextColor)
                    .weighted(FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DsTextField(
                  hint: 'Digite o código do cupom',
                  controller: _couponCodeController,
                  formatters: [UpperCaseTextFormatter()],
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: DsPrimaryButton(
                  label: 'Aplicar',
                  onPressed: _couponCodeController.text.isNotEmpty && !_isLoading
                      ? () => _applyCoupon(_couponCodeController.text)
                      : null,
                  child: _isLoading && _couponCodeController.text.isNotEmpty
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponsList(DsTheme theme) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        final allCoupons = state.store?.coupons ?? [];
        final activeCoupons = allCoupons.where((c) => c.isActive).toList();

        if (activeCoupons.isEmpty) {
          return _buildEmptyState(theme);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cupons disponíveis',
              style: theme.bodyTextStyle
                  .colored(theme.productTextColor)
                  .weighted(FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Opção de não usar cupom (se já tem um aplicado)
            if (_selectedCouponCode != null) ...[
              _buildRemoveCouponOption(theme),
              const SizedBox(height: 12),
            ],
            
            // Lista de cupons com cards do coupon_uikit
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeCoupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final coupon = activeCoupons[index];
                final isSelected = _selectedCouponCode == coupon.code;
                return _buildCouponCard(coupon, theme, isSelected);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(DsTheme theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum cupom disponível',
            style: theme.bodyTextStyle.colored(Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Digite um código acima se você tiver um cupom.',
            style: theme.smallTextStyle.colored(Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveCouponOption(DsTheme theme) {
    return InkWell(
      onTap: _isLoading ? null : _removeCoupon,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.remove_circle_outline, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Remover cupom aplicado',
                style: theme.bodyTextStyle.colored(Colors.orange.shade600),
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(Coupon coupon, DsTheme theme, bool isSelected) {
    final discountText = _getDiscountText(coupon);
    final conditionsText = _getConditionsText(coupon);

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedCouponCode = coupon.code);
              _applyCoupon(coupon.code);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: CouponCard(
          height: 100,
          backgroundColor: theme.cardColor,
          curveAxis: Axis.vertical,
          curvePosition: 90,
          curveRadius: 12,
          borderRadius: 14,
          border: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
          firstChild: Container(
            width: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withAlpha(204),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCouponIcon(coupon),
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          secondChild: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coupon.code.toUpperCase(),
                        style: theme.bodyTextStyle
                            .colored(theme.productTextColor)
                            .weighted(FontWeight.bold),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conditionsText,
                  style: theme.smallTextStyle.colored(Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDiscountText(Coupon coupon) {
    if (coupon.discountType == 'PERCENTAGE') {
      return '${coupon.discountValue.toInt()}%';
    } else if (coupon.discountType == 'FIXED_AMOUNT') {
      final valueInReais = coupon.discountValue / 100;
      return 'R\$${valueInReais.toStringAsFixed(0)}';
    } else if (coupon.discountType == 'FREE_DELIVERY') {
      return 'FRETE\nGRÁTIS';
    }
    return '${coupon.discountValue.toInt()}%';
  }

  String _getConditionsText(Coupon coupon) {
    final conditions = <String>[];
    
    if (coupon.isFreeDelivery) {
      conditions.add('Frete grátis no pedido');
    } else if (coupon.targetProductId != null) {
      conditions.add('Desconto em produto específico');
    } else {
      conditions.add('Desconto em toda a sacola');
    }
    
    if (coupon.minOrderValue != null && coupon.minOrderValue! > 0) {
      final minValue = coupon.minOrderValue! / 100;
      conditions.add('Mínimo R\$ ${minValue.toStringAsFixed(0)}');
    }
    
    if (coupon.isForFirstOrder) {
      conditions.add('Apenas primeira compra');
    }
    
    return conditions.join(' • ');
  }

  IconData _getCouponIcon(Coupon coupon) {
    if (coupon.discountType == 'FREE_DELIVERY') {
      return Icons.local_shipping;
    } else if (coupon.discountType == 'PERCENTAGE') {
      return Icons.percent;
    }
    return Icons.sell;
  }
}



