import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/tokens/animation_tokens.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/widgets/dony_image.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { xs, sm, md, lg, xl }

const Color _kVerifiedBlue = DonyColors.primary;

class DonyAvatar extends StatelessWidget {
  const DonyAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DonyAvatarSize.md,
    this.verified = false,
    this.pro = false,
    this.gpPro = false,
  });

  final String name;
  final String? imageUrl;
  final DonyAvatarSize size;
  final bool verified;

  /// Compte PRO : coche dorée (prime sur [gpPro]).
  final bool pro;

  /// Voyageur GP Pro : coche verte, sauf si le compte est aussi PRO.
  final bool gpPro;

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

  static final _letterPattern = RegExp(
    r'[A-Za-zÀ-ÿ]', // i18n-ignore : motif de détection d'initiale
  );

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
          decoration: BoxDecoration(color: _bgColor, shape: BoxShape.circle),
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
                    placeholder: (_, _) => initials,
                    errorWidget: (_, _, _) => initials,
                  ),
                )
              : initials,
        ),
        if (verified)
          Positioned(
            right: -dim * 0.02,
            bottom: 0,
            child: DonyVerifiedBadge(size: dim * 0.30, pro: pro, gpPro: gpPro),
          ),
      ],
    );
  }
}

/// Coche « identité vérifiée ». Sa couleur dit le niveau du compte : bleue pour
/// un compte vérifié seul, vert pour un GP Pro, or pour un PRO (l'or prime
/// quand le compte est PRO et GP Pro).
class DonyVerifiedBadge extends StatelessWidget {
  const DonyVerifiedBadge({
    super.key,
    required this.size,
    this.pro = false,
    this.gpPro = false,
    this.ringColor = DonyColors.white,
  });

  final double size;
  final bool pro;
  final bool gpPro;

  /// Contour derrière la coche (blanc par défaut, couleur du fond sinon).
  final Color ringColor;

  /// Couleur de la coche pour un niveau de compte, partagée avec les écrans
  /// qui la dessinent eux-mêmes (titre replié de l'onglet Moi).
  static Color colorFor({required bool pro, required bool gpPro}) {
    if (pro) return DonyColors.kycBadgeGold;
    if (gpPro) return DonyColors.kycBadgeGpPro;
    return _kVerifiedBlue;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(pro: pro, gpPro: gpPro);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DonyIcon('badge-check', size: size, color: ringColor),
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
