import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { sm, md, lg }

class DonyAvatar extends StatelessWidget {
  const DonyAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = DonyAvatarSize.md,
    this.backgroundColor,
  });

  final String? imageUrl;
  final String? initials;
  final DonyAvatarSize size;
  final Color? backgroundColor;

  double get _dimension => switch (size) {
    DonyAvatarSize.sm => 32,
    DonyAvatarSize.md => 44,
    DonyAvatarSize.lg => 56,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = _dimension;

    if (imageUrl != null) {
      return CircleAvatar(
        radius: dim / 2,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }

    return CircleAvatar(
      radius: dim / 2,
      backgroundColor: backgroundColor ?? DonyColors.blue100,
      child: Text(
        (initials ?? '?').substring(0, 1).toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: cs.onPrimaryContainer,
          fontSize: dim * 0.36,
        ),
      ),
    );
  }
}
