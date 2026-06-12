import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Stat value + label used under Insights chart cards.
class InsightStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final double scale;

  const InsightStatCell({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.scale = 1.0,
  });

  static const double _baseValueSize = 18;
  static const double _baseLabelSize = 11;
  static const double _maxValueSize = 32;

  @override
  Widget build(BuildContext context) {
    final valueSize = (_baseValueSize * scale).clamp(
      _baseValueSize,
      _maxValueSize,
    );
    final labelSize = (_baseLabelSize * scale).clamp(
      _baseLabelSize,
      _maxValueSize,
    );

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: labelSize, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
