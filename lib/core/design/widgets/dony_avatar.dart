import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { sm, md, lg, xl }

const Color _kVerifiedBlue = DonyColors.primary;
const Color _kVerifiedGold = Color(0xFFF0B829);

class DonyAvatar extends StatelessWidget {
  const DonyAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DonyAvatarSize.md,
    this.verified = false,
    this.pro = false,
  });

  final String name;
  final String? imageUrl;
  final DonyAvatarSize size;
  final bool verified;
  final bool pro;

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
    DonyColors.primary,
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
            color: imageUrl != null ? DonyColors.neutral100 : _bgColor,
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
            right: -dim * 0.02,
            bottom: -dim * 0.02,
            child: _VerifiedBadge(size: dim * 0.42, isPro: pro),
          ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.size, required this.isPro});

  final double size;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final color = isPro ? _kVerifiedGold : _kVerifiedBlue;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.verified_rounded, size: size, color: DonyColors.white),
          Icon(Icons.verified_rounded, size: size * 0.88, color: color),
        ],
      ),
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
