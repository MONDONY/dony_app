import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Affiche partageable d'un trajet, destinée à être capturée en PNG puis
/// postée par le voyageur sur ses propres canaux (Facebook, WhatsApp, TikTok).
///
/// **Couleurs figées, pas de tokens de thème.** Le rendu part en image : il doit
/// être identique que l'utilisateur soit en clair ou en sombre au moment de la
/// capture. Lire `Theme.of(context).colorScheme` produirait deux affiches
/// différentes pour le même trajet, ce qui casserait l'identité visuelle sur
/// les canaux du voyageur. Seule la famille typographique est reprise du thème,
/// elle ne dépend pas de la luminosité.
///
/// **Aucun numéro de téléphone.** Les affiches concurrentes en placardent deux à
/// quatre ; celle-ci porte uniquement le lien Yadony. C'est cohérent avec le
/// masquage du numéro déjà en place côté profil, et c'est un argument en soi :
/// le voyageur n'est plus appelé à toute heure, les demandes arrivent
/// qualifiées dans l'application.
class TripPosterCard extends StatelessWidget {
  const TripPosterCard({
    super.key,
    required this.announcement,
    required this.shareUrl,
  });

  final AnnouncementModel announcement;

  /// URL publique imprimée en pied d'affiche.
  final String shareUrl;

  /// Largeur logique de composition. La capture applique un `pixelRatio` de 3
  /// pour sortir 1080 x 1350, le format 4:5 du fil Facebook et Instagram.
  static const double logicalWidth = 360;
  static const double logicalHeight = 450;

  static const Color _ink = DonyColors.ink900;
  static const Color _blue = DonyColors.blue500;
  static const Color _terra = DonyColors.terra500;
  static const Color _paper = DonyColors.neutral0;
  static const Color _muted = DonyColors.neutral500;
  static const Color _line = DonyColors.neutral200;

  /// Prix affiché à l'expéditeur, commission Yadony comprise.
  ///
  /// L'affiche s'adresse aux expéditeurs : montrer `pricePerKg`, qui est le net
  /// voyageur, annoncerait un prix que personne ne paiera réellement.
  double get _displayPrice =>
      announcement.pricePerKgDisplay ?? announcement.pricePerKg;

  String get _currencySymbol => switch (announcement.currency) {
    'EUR' => '€',
    'USD' => r'$',
    'GBP' => '£',
    'CAD' => r'$ CA',
    'XOF' => 'F CFA',
    _ => announcement.currency,
  };

  String _formatAmount(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dayFmt = DateFormat('EEEE d MMMM', 'fr');
    final deadlineFmt = DateFormat("d MMMM 'à' HH'h'mm", 'fr');

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      child: ColoredBox(
        color: _paper,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _wordmark(text),
              const SizedBox(height: 18),
              _corridor(text),
              const SizedBox(height: 18),
              _departureBlock(text, dayFmt),
              const SizedBox(height: 10),
              if (announcement.handoverDeadline != null) ...[
                _deadlineBlock(text, deadlineFmt),
                const SizedBox(height: 10),
              ],
              _capacityBlock(text),
              const Spacer(),
              _priceBlock(text),
              const SizedBox(height: 14),
              _footer(text),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête volontairement réduit à la seule marque.
  ///
  /// Une pastille d'accroche y a été essayée puis retirée : elle débordait dès
  /// que la police de rendu était plus large que prévu, et elle répétait ce que
  /// dit déjà le pied d'affiche. Un en-tête à un seul élément ne peut pas
  /// déborder, quelle que soit la typographie disponible sur l'appareil.
  Widget _wordmark(TextTheme text) {
    return Text(
      'Yadony',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.headlineLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: _blue,
      ),
    );
  }

  Widget _corridor(TextTheme text) {
    final style = text.displayLarge?.copyWith(
      fontSize: 40,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.6,
      color: _ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          announcement.departureCity.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        Row(
          children: [
            const Icon(Icons.flight_rounded, size: 26, color: _blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                announcement.arrivalCity.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _departureBlock(TextTheme text, DateFormat fmt) {
    return _InfoRow(
      label: 'Départ',
      value: fmt.format(announcement.departureDate),
      valueColor: _ink,
      textTheme: text,
    );
  }

  /// La date limite de dépôt est le vrai butoir commercial, pas la date de
  /// départ : c'est elle qui déclenche la décision de l'expéditeur. Toutes les
  /// affiches du marché la mettent en avant en rouge, on garde ce code visuel.
  Widget _deadlineBlock(TextTheme text, DateFormat fmt) {
    return _InfoRow(
      label: 'Dernier dépôt',
      value: fmt.format(announcement.handoverDeadline!),
      valueColor: _terra,
      textTheme: text,
    );
  }

  Widget _capacityBlock(TextTheme text) {
    return _InfoRow(
      label: 'Place disponible',
      value: '${_formatAmount(announcement.availableKg)} kg',
      valueColor: _ink,
      textTheme: text,
    );
  }

  Widget _priceBlock(TextTheme text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      // Mise à l'échelle plutôt que troncature : « 6000F CFA » est deux fois
      // plus large que « 8€ », et un prix coupé par une ellipse serait pire
      // qu'un prix légèrement plus petit. Le bloc reste lisible quelle que soit
      // la devise du corridor.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_formatAmount(_displayPrice)}$_currencySymbol',
              style: text.displayLarge?.copyWith(
                fontSize: 38,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: DonyColors.neutral0,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'le kilo',
                style: text.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DonyColors.blue50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: _line),
        const SizedBox(height: 10),
        Text(
          'Paiement sécurisé, suivi du colis, voyageurs vérifiés',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shareUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelMedium?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _blue,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.textTheme,
  });

  final String label;
  final String value;
  final Color valueColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: TripPosterCard._muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
