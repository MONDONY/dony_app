import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/tokens/animation_tokens.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/widgets/dony_image.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { xs, sm, md, lg, xl }

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
    DonyAvatarSize.xs => 24,
    DonyAvatarSize.sm => 32,
    DonyAvatarSize.md => 44,
    DonyAvatarSize.lg => 56,
    DonyAvatarSize.xl => 72,
  };

  double get _fontSize => switch (size) {
    DonyAvatarSize.xs => 9,
    DonyAvatarSize.sm => 12,
    DonyAvatarSize.md => 16,
    DonyAvatarSize.lg => 20,
    DonyAvatarSize.xl => 26,
  };

  static final _letterPattern = RegExp(r'[A-Za-zÀ-ÿ]');

  /// Première lettre de [s], en ignorant les caractères non alphabétiques
  /// (ex: le `+` d'un numéro de téléphone utilisé en repli de nom).
  static String? _firstLetter(String s) {
    for (final rune in s.runes) {
      final char = String.fromCharCode(rune);
      if (_letterPattern.hasMatch(char)) {
        return char;
      }
    }
    return null;
  }

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = _firstLetter(parts[0]);
      final second = _firstLetter(parts[1]);
      if (first != null && second != null) {
        return '$first$second'.toUpperCase();
      }
    }
    final single = parts.isNotEmpty ? _firstLetter(parts.first) : null;
    return single?.toUpperCase() ?? '?';
  }

  // Fonds d'initiales. Le texte posé dessus est blanc, donc chaque couleur
  // doit tenir 4.5:1 avec du blanc. terra500 n'y arrivait pas (3.46:1), d'où
  // terra700 (6.92:1) ; les cinq autres passent déjà.
  static const _avatarColors = [
    DonyColors.primary,
    DonyColors.terra700,
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
    final initials = _InitialsText(initials: _initials, fontSize: _fontSize);
    return Stack(
      children: [
        Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            color: _bgColor,
            shape: BoxShape.circle,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    cacheKey: DonyImage.stableCacheKey(imageUrl!),
                    width: dim,
                    height: dim,
                    fit: BoxFit.cover,
                    fadeInDuration: DonyDuration.micro,
                    fadeInCurve: DonyCurve.enter,
                    fadeOutDuration: DonyDuration.micro,
                    fadeOutCurve: DonyCurve.exit,
                    placeholder: (_, __) => initials,
                    errorWidget: (_, __, ___) => initials,
                  ),
                )
              : initials,
        ),
        if (verified)
          Positioned(
            right: -dim * 0.02,
            bottom: 0,
            child: _VerifiedBadge(size: dim * 0.30, isPro: pro),
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
          DonyIcon('badge-check', size: size, color: DonyColors.white),
          DonyIcon('badge-check', size: size * 0.88, color: color),
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
