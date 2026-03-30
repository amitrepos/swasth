import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable glassmorphism card.
///
/// Wraps [child] in a frosted-glass surface:
///   ClipRRect → BackdropFilter(blur:12) → Container(semi-white, white border, soft shadow)
///
/// Usage:
///   GlassCard(child: Text('hello'))
///   GlassCard(borderRadius: 24, padding: EdgeInsets.all(20), child: ...)
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.color,
    this.border,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Override the fill color. Defaults to [AppColors.bgCard] (45% white).
  final Color? color;

  /// Override the border. Defaults to a 1px 50%-white border.
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.bgCard,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(color: AppColors.glassCardBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 24,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}
