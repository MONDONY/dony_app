import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class DonyCard extends StatelessWidget {
  const DonyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(DonySpacing.base),
      child: child,
    );
    if (onTap != null) {
      return Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: inner,
        ),
      );
    }
    return Card(child: inner);
  }
}
