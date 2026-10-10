import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Briques communes aux affiches partageables (trajet, demande d'envoi).
///
/// **Couleurs figées, pas de tokens de thème.** Une affiche part en image :
/// elle doit être identique que l'utilisateur soit en clair ou en sombre au
/// moment de la capture. Seule la famille typographique est reprise du thème,
/// elle ne dépend pas de la luminosité.
abstract final class PosterPalette {
  static const Color paper = DonyColors.neutral0;
  static const Color ink = DonyColors.ink900;
  static const Color blue = DonyColors.blue500;
  static const Color blueTint = DonyColors.blue50;
  static const Color blueOnDark = DonyColors.blue100;
  static const Color terra = DonyColors.terra500;
  static const Color terraDeep = DonyColors.terra600;
  static const Color terraTint = DonyColors.terra50;
  static const Color tile = DonyColors.sand100;
  static const Color muted = DonyColors.neutral500;
  static const Color line = DonyColors.neutral200;
  static const Color inkOnDark = DonyColors.ink200;
}

/// Dimensions partagées : 360 x 450 logiques, capturées avec un `pixelRatio`
/// de 3, soit 1080 x 1350, le format 4:5 du fil Facebook et Instagram (le
/// plus haut affiché sans recadrage).
abstract final class PosterLayout {
  static const double width = 360;
  static const double height = 450;
  static const double pixelRatio = 3;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 14);

  /// Largeur utile, padding horizontal déduit.
  static double get innerWidth => width - padding.horizontal;

  /// Espacement vertical entre les blocs de l'affiche.
  static const double gap = 8;
}

/// Badges officiels des deux stores, en français, embarqués tels quels : Apple
/// et Google exigent leur propre artwork, non modifié. Publics car les écrans
/// d'aperçu doivent les précharger avant de rastériser l'affiche.
abstract final class PosterAssets {
  static const String appStoreBadge = 'assets/logos/store/app-store-fr.png';
  static const String googlePlayBadge = 'assets/logos/store/google-play-fr.png';

  /// Tout ce qu'une affiche peint depuis les assets : à précharger.
  static const List<String> all = [
    DonyLogo.asset,
    appStoreBadge,
    googlePlayBadge,
  ];
}

/// En-tête : le mot-logo officiel à gauche, une pastille de nature à droite
/// (« KILOS DISPONIBLES », « CHERCHE UN VOYAGEUR »).
class PosterHeader extends StatelessWidget {
  const PosterHeader({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        // DonyLogo fixe la hauteur et déduit la largeur du ratio : la mise en
        // page reste stable même avant le décodage de l'image.
        const DonyLogo(fontSize: 22),
        const SizedBox(width: 12),
        // La pastille se réduit plutôt que de déborder : sa longueur dépend
        // de la langue, la largeur de l'affiche ne bouge pas.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bandeau coloré qui porte le corridor, titre de l'affiche.
class PosterHero extends StatelessWidget {
  const PosterHero({
    super.key,
    required this.background,
    required this.eyebrow,
    required this.corridor,
    this.subtitle,
    this.footer,
  });

  final Color background;
  final String eyebrow;
  final Widget corridor;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    final footer = this.footer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: PosterPalette.paper.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          corridor,
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PosterPalette.paper.withValues(alpha: 0.92),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: PosterPalette.paper.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 8),
            footer,
          ],
        ],
      ),
    );
  }
}

/// Tuile chiffrée : petit libellé en capitales, valeur en grand, précision
/// dessous. La valeur est mise à l'échelle plutôt que tronquée : « 6 000 F
/// CFA » est deux fois plus large que « 8 € », et un prix coupé serait pire
/// qu'un prix légèrement plus petit.
class PosterTile extends StatelessWidget {
  const PosterTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.background = PosterPalette.tile,
    this.valueColor = PosterPalette.ink,
    this.labelColor = PosterPalette.muted,
    this.gauge,
  });

  final String label;
  final String value;
  final String? detail;
  final Color background;
  final Color valueColor;
  final Color labelColor;

  /// Taux de remplissage d'une jauge (0 à 1) sous la valeur, ou rien.
  final double? gauge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    final gauge = this.gauge;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: text.displaySmall?.copyWith(
                  fontSize: 21,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
          if (gauge != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: gauge.clamp(0, 1).toDouble(),
                  backgroundColor: PosterPalette.line,
                  color: PosterPalette.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne « libellé : valeur » des lieux (remise, retrait, quartiers).
class PosterPlaceRow extends StatelessWidget {
  const PosterPlaceRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PosterPalette.muted,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: PosterPalette.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rangée de puces sur une seule ligne, avec un « +N » quand tout ne tient
/// pas. Le nombre de puces visibles est borné par [maxVisible] : une puce
/// coupée en plein mot serait pire que l'indication du reste.
class PosterChipRow extends StatelessWidget {
  const PosterChipRow({
    super.key,
    required this.label,
    required this.items,
    required this.background,
    required this.foreground,
    this.maxVisible = 3,
  });

  final String label;
  final List<String> items;
  final Color background;
  final Color foreground;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final visible = items.take(maxVisible).toList();
    final rest = items.length - visible.length;
    final chipStyle = text.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: foreground,
    );

    Widget chip(String value, {Color? bg, TextStyle? style}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? background,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(value, maxLines: 1, style: style ?? chipStyle),
    );

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              label.toUpperCase(),
              style: text.labelSmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: PosterPalette.muted,
              ),
            ),
            for (final item in visible) ...[
              const SizedBox(width: 5),
              chip(item),
            ],
            if (rest > 0) ...[
              const SizedBox(width: 5),
              chip(
                '+$rest',
                bg: PosterPalette.tile,
                style: chipStyle?.copyWith(color: PosterPalette.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pied d'affiche : QR code vers la page publique, appel à l'action et badges
/// des deux stores.
///
/// Le QR rend le lien utilisable quand l'image circule seule (statut WhatsApp,
/// capture transférée, impression) : une URL écrite n'y serait cliquable nulle
/// part, et personne ne recopie 80 caractères portant un UUID. Sans
/// [qrData] (aperçus, tests), le pied se réduit au texte et aux badges.
class PosterFooter extends StatelessWidget {
  const PosterFooter({
    super.key,
    required this.title,
    required this.subtitle,
    this.qrData,
  });

  final String title;
  final String subtitle;
  final String? qrData;

  /// Hauteur de rendu du badge Apple, qui n'a pas de marge intégrée.
  static const double _badgeHeight = 20;

  /// Part utile du badge Google : son PNG officiel réserve 23 % de sa hauteur
  /// à la zone de dégagement imposée par la charte. Sans ce facteur, rendu à
  /// la même hauteur qu'Apple, il paraîtrait nettement plus petit.
  static const double _googleBadgeContentRatio = 0.77;

  static const double qrSize = 68;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final qrData = this.qrData;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: PosterPalette.line),
        const SizedBox(height: 9),
        Row(
          children: [
            if (qrData != null) ...[
              Container(
                key: const Key('poster-qr'),
                width: qrSize,
                height: qrSize,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: PosterPalette.paper,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(color: PosterPalette.ink, width: 1.5),
                ),
                child: QrImageView(
                  data: qrData,
                  padding: EdgeInsets.zero,
                  // M : tolère une affiche un peu abîmée (compression JPEG des
                  // messageries, capture d'écran) sans densifier le motif.
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: PosterPalette.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: PosterPalette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 11),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: PosterPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: PosterPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Image.asset(
                        PosterAssets.appStoreBadge,
                        height: _badgeHeight,
                      ),
                      const SizedBox(width: 6),
                      Image.asset(
                        PosterAssets.googlePlayBadge,
                        height: _badgeHeight / _googleBadgeContentRatio,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
