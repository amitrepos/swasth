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
    // Why the inner Material(type: transparency):
    // ListTile (which is the most common child of GlassCard) renders
    // its own background + ink splashes onto the NEAREST Material
    // ancestor. Without a Material between the colored Container
    // below and ListTile, Flutter fires a debug assertion at paint
    // time ("ListTile background color or ink splashes may be
    // invisible") and the widget-test harness counts every such
    // assertion as a test failure — CI showed five of these per
    // ProfileScreen test run, masking the actual assertions.
    // A transparent Material gives ListTile the ancestor it needs
    // for ink splashes to land on the glass surface (the visible
    // background still comes from the BoxDecoration below it).
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
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}
