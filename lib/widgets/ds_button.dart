import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

// ✨ Widget para a animação de "3 pontos"
class _ThreeDotsLoading extends StatefulWidget {
  final Color? dotsColor;

  const _ThreeDotsLoading({this.dotsColor});

  @override
  State<_ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<_ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dotsColor ?? Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return FadeTransition(
          opacity: DelayTween(
            begin: 0.2,
            end: 1.0,
            delay: index * 0.2,
          ).animate(_controller),
          child: Text(
            "●",
            style: TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        );
      }),
    );
  }
}

// Helper para a animação escalonada
class DelayTween extends Tween<double> {
  final double delay;
  DelayTween({required super.begin, required super.end, required this.delay});

  @override
  double lerp(double t) {
    return super.lerp((t - delay).clamp(0.0, 1.0));
  }
}

enum DsButtonStyle {
  primary,
  secondary,
  custom,
}

class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    this.label,
    this.child,
    this.onPressed,
    this.style = DsButtonStyle.primary,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.loadingDotsColor,
    this.labelColor,
    this.padding,
    this.minimumSize,
    this.maxWidth,
    this.constrained = false,
  }) : assert(label != null || child != null,
  'É necessário fornecer ou uma "label" ou um "child".');

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final DsButtonStyle style;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Color? loadingDotsColor;
  final Color? labelColor; 
  final EdgeInsets? padding;
  final Size? minimumSize;
  final double? maxWidth;
  final bool constrained;

  // Métodos de estilo adaptados para DsTheme do Totem
  Color _getEffectiveBackgroundColor(Set<WidgetState> states, DsTheme theme) {
    if (states.contains(WidgetState.disabled)) {
      return disabledBackgroundColor ?? theme.inactiveColor;
    }
    switch (style) {
      case DsButtonStyle.custom: return backgroundColor ?? theme.primaryColor;
      case DsButtonStyle.primary: return backgroundColor ?? theme.primaryColor;
      case DsButtonStyle.secondary: return Colors.transparent;
    }
  }

  Color _getEffectiveForegroundColor(Set<WidgetState> states, DsTheme theme) {
    if (states.contains(WidgetState.disabled)) {
      return disabledForegroundColor ?? theme.onInactiveColor;
    }
    switch (style) {
      case DsButtonStyle.custom: return foregroundColor ?? theme.onPrimaryColor;
      case DsButtonStyle.primary: return foregroundColor ?? theme.onPrimaryColor;
      case DsButtonStyle.secondary: return foregroundColor ?? theme.primaryColor;
    }
  }
  
  Color _getEffectiveLabelColor(DsTheme theme) {
    if (labelColor != null) {
      return labelColor!;
    }
    return _getEffectiveForegroundColor({}, theme);
  }

  Color _getEffectiveBorderColor(DsTheme theme) {
    if (borderColor != null) return borderColor!;
    switch (style) {
      case DsButtonStyle.custom: return backgroundColor ?? theme.primaryColor;
      case DsButtonStyle.primary: return theme.primaryColor;
      case DsButtonStyle.secondary: return theme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;
    final textStyle = theme.bodyTextStyle.copyWith(fontWeight: FontWeight.w600);

    final bool isEffectivelyDisabled = isLoading || isDisabled || onPressed == null;
    final VoidCallback? finalOnPressed = isEffectivelyDisabled ? null : onPressed;

    final baseStyle = ButtonStyle(
      padding: WidgetStateProperty.all<EdgeInsets>(padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
      minimumSize: WidgetStateProperty.all(minimumSize ?? const Size(80, 48)),
      maximumSize: WidgetStateProperty.all(constrained && maxWidth != null ? Size(maxWidth!, minimumSize?.height ?? 48) : Size(double.infinity, minimumSize?.height ?? 48)),
      alignment: Alignment.center,
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) => _getEffectiveBackgroundColor(states, theme)),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) => _getEffectiveForegroundColor(states, theme)),
    );

    final effectiveLabelColor = _getEffectiveLabelColor(theme);
    final buttonContent = child ?? _ResponsiveButtonContent(icon: icon, label: label!, textStyle: textStyle.copyWith(color: effectiveLabelColor), constrained: constrained);
    final finalChild = isLoading ? _ThreeDotsLoading(dotsColor: loadingDotsColor ?? _getEffectiveForegroundColor({}, theme)) : buttonContent;

    Widget buildButton() {
      switch (style) {
        case DsButtonStyle.secondary:
          return OutlinedButton(onPressed: finalOnPressed, style: baseStyle.copyWith(side: WidgetStateProperty.all(BorderSide(color: _getEffectiveBorderColor(theme), width: 0.5))), child: finalChild);
        case DsButtonStyle.custom:
        case DsButtonStyle.primary:
        default:
          return ElevatedButton(onPressed: finalOnPressed, style: baseStyle.copyWith(side: style == DsButtonStyle.custom ? WidgetStateProperty.all(BorderSide(color: _getEffectiveBorderColor(theme), width: 0.5)) : null), child: finalChild);
      }
    }

    return constrained && maxWidth != null ? ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: buildButton()) : buildButton();
  }
}

class _ResponsiveButtonContent extends StatelessWidget {
  const _ResponsiveButtonContent({required this.icon, required this.label, required this.textStyle, this.constrained = false});
  final IconData? icon;
  final String label;
  final TextStyle textStyle;
  final bool constrained;

  @override
  Widget build(BuildContext context) {
    if (constrained) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: textStyle.color), const SizedBox(width: 8)],
          Flexible(child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      );
    } else {
      return LayoutBuilder(builder: (context, constraints) {
        final bool useVerticalLayout = (icon != null && constraints.maxWidth < 150);
        if (useVerticalLayout) {
          return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: textStyle.color), const SizedBox(height: 4)],
            Flexible(child: Text(label, style: textStyle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2)),
          ]);
        } else {
          return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: textStyle.color), const SizedBox(width: 8)],
            Flexible(child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]);
        }
      });
    }
  }
}
