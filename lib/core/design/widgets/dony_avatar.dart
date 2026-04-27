import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { sm, md, lg, xl }

class DonyAvatar extends StatelessWidget {
  const DonyAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DonyAvatarSize.md,
    this.verified = false,
  });

  final String name;
  final String? imageUrl;
  final DonyAvatarSize size;
  final bool verified;

  double get _dimension => switch (size) {
    DonyAvatarSize.sm => 32,
    DonyAvatarSize.md => 44,
    DonyAvatarSize.lg => 56,
    DonyAvatarSize.xl => 72,
  };

  double get _fontSize => switch (size) {
    DonyAvatarSize.sm => 12,
    DonyAvatarSize.md => 16,
    DonyAvatarSize.lg => 20,
    DonyAvatarSize.xl => 26,
  };

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static const _avatarColors = [
    DonyColors.green400,
    DonyColors.terra500,
    DonyColors.ink900,
    DonyColors.info,
    DonyColors.purple,
    DonyColors.teal,
  ];

  Color get _bgColor {
    final code = _initials.codeUnits.fold(0, (a, b) => a + b);
    return _avatarColors[code % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimension;
    return Stack(
      children: [
        Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            color: imageUrl != null ? DonyColors.grey100 : _bgColor,
            shape: BoxShape.circle,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _InitialsText(initials: _initials, fontSize: _fontSize),
                  ),
                )
              : _InitialsText(initials: _initials, fontSize: _fontSize),
        ),
        if (verified)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dim * 0.33,
              height: dim * 0.33,
              decoration: const BoxDecoration(color: DonyColors.success, shape: BoxShape.circle),
              child: Icon(Icons.check, color: DonyColors.white, size: dim * 0.2),
            ),
          ),
      ],
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText({required this.initials, required this.fontSize});
  final String initials;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: DonyColors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
