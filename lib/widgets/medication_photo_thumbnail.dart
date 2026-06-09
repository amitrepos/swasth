import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MedicationPhotoThumbnail extends StatelessWidget {
  final Uint8List? bytes;
  final bool hasPhoto;
  final bool loading;
  final double size;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const MedicationPhotoThumbnail({
    super.key,
    required this.hasPhoto,
    this.bytes,
    this.loading = false,
    this.size = 52,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: _buildInner()),
    );
    final labeled = semanticsLabel == null
        ? child
        : Semantics(label: semanticsLabel, button: onTap != null, child: child);
    if (onTap == null) return labeled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: labeled,
    );
  }

  Widget _buildInner() {
    if (loading) {
      return const ColoredBox(
        color: AppColors.bgGrouped,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (hasPhoto && bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: AppColors.bgGrouped,
      child: const Icon(
        Icons.add_a_photo_outlined,
        color: AppColors.textSecondary,
        size: 18,
      ),
    );
  }
}
