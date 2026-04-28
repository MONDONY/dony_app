import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Icône centrée dans un conteneur circulaire coloré.
/// Usage : illustrations d'état, en-têtes de section, badges d'action.
class DonyIconContainer extends StatelessWidget {
  const DonyIconContainer({
    super.key,
    required this.icon,
    this.size = DonyIconContainerSize.md,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
  });

  final IconData icon;
  final DonyIconContainerSize size;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final (containerSize, iconSize) = switch (size) {
      DonyIconContainerSize.sm => (32.0, 16.0),
      DonyIconContainerSize.md => (DonySpacing.icon, DonySpacing.iconSm),
      DonyIconContainerSize.lg => (56.0, 28.0),
      DonyIconContainerSize.xl => (72.0, 36.0),
    };

    final bg = backgroundColor ?? DonyColors.green50;
    final ic = iconColor ?? DonyColors.green400;
    final radius = borderRadius ?? containerSize / 2;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: ic),
    );
  }
}

enum DonyIconContainerSize { sm, md, lg, xl }
