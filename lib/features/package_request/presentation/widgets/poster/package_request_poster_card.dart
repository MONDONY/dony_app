import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Affiche partageable d'une demande d'envoi, capturée en PNG puis postée par
/// l'expéditeur pour trouver un voyageur sur son axe.
///
/// Jumelle de l'affiche de trajet (mêmes briques, même format 4:5), mais en
/// terracotta : sur un fil Facebook ou un groupe WhatsApp, on distingue d'un
/// coup d'œil « je propose des kilos » de « je cherche un voyageur ».
///
/// **Ni nom ni numéro de l'expéditeur.** L'affiche circule hors de
/// l'application, chez des inconnus : les propositions arrivent dans
/// l'application, où l'identité est vérifiée.
///
/// **Photo du colis quand elle existe.** Sinon, une illustration à la même
/// place : la mise en page ne dépend jamais de la présence d'une image ni de
/// la connexion au moment de la capture.
class PackageRequestPosterCard extends StatelessWidget {
  const PackageRequestPosterCard({
    super.key,
    required this.request,
    this.qrData,
    this.photo,
  });

  final PackageRequest request;

  /// Lien encodé dans le QR code du pied. Sans lui, pas de QR.
  final String? qrData;

  /// Photo du colis, préchargée par l'écran avant la capture. `null` :
  /// illustration à la place.
  final ImageProvider? photo;

  static DateFormat dayFormat(String locale) => DateFormat.MMMMEEEEd(locale);

  /// « Autour du vendredi 24 octobre, à 3 jours près ».
  static String dateLabel(AppLocalizations l, PackageRequest r) {
    final day = dayFormat(l.localeName).format(r.desiredDate);
    return r.dateToleranceDays > 0
        ? l.requestPosterDateTolerance(r.dateToleranceDays, day)
        : l.requestPosterDate(day);
  }

  /// Budget tel que le paie l'expéditeur : le brut, avec repli sur le net
  /// pour un ancien payload. Jamais les deux (la différence révélerait la
  /// commission). `null` sans budget.
  static String? budgetLabel(PackageRequest r) {
    final price = r.grossPriceEur ?? r.targetPriceEur;
    if (price == null || price <= 0) return null;
    return formatPriceIn(price, r.currency);
  }

  static String weightLabel(AppLocalizations l, PackageRequest r) =>
      '${formatKg(l, r.weightKg)} kg';

  /// « Lyon, Guillotière », ou la ville seule sans quartier.
  static String placeLabel(String city, String? neighborhood) =>
      (neighborhood == null || neighborhood.trim().isEmpty)
      ? city
      : '$city, ${neighborhood.trim()}';

  static const double _corridorMinScale = 0.8;
  static const double _corridorIconSize = 26;
  static const double _corridorGap = 10;
  static const double _heroPadding = 28;
  static const double _photoWidth = 104;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final r = request;
    final contents = [
      for (final c in r.categories) contentCategoryDisplayName(l, c),
    ];
    final payments = [for (final m in r.acceptedPaymentMethods) m.label(l)];

    return SizedBox(
      width: PosterLayout.width,
      height: PosterLayout.height,
      child: ColoredBox(
        color: PosterPalette.paper,
        child: Padding(
          padding: PosterLayout.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: PosterLayout.innerWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PosterHeader(
                          label: l.requestPosterBadge,
                          background: PosterPalette.terraTint,
                          foreground: PosterPalette.terraDeep,
                        ),
                        const SizedBox(height: PosterLayout.gap),
                        PosterHero(
                          background: PosterPalette.terra,
                          eyebrow: [
                            l.requestPosterEyebrow,
                            r.transportMode.label(l),
                          ].join(' · '),
                          corridor: _corridor(text),
                          subtitle: dateLabel(l, r),
                        ),
                        const SizedBox(height: PosterLayout.gap),
                        _details(l, payments),
                        const SizedBox(height: PosterLayout.gap),
                        PosterPlaceRow(
                          label: l.requestPosterFrom,
                          value: placeLabel(
                            r.departureCity,
                            r.pickupNeighborhood,
                          ),
                        ),
                        const SizedBox(height: 4),
                        PosterPlaceRow(
                          label: l.requestPosterTo,
                          value: placeLabel(
                            r.arrivalCity,
                            r.deliveryNeighborhood,
                          ),
                        ),
                        if (contents.isNotEmpty) ...[
                          const SizedBox(height: PosterLayout.gap),
                          PosterChipRow(
                            label: l.requestPosterContents,
                            items: contents,
                            background: PosterPalette.terraTint,
                            foreground: PosterPalette.terraDeep,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PosterLayout.gap),
              PosterFooter(
                title: l.requestPosterFooterTitle(
                  r.departureCity,
                  r.arrivalCity,
                ),
                subtitle: l.requestPosterFooterSubtitle,
                qrData: qrData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Photo à gauche, tuiles à droite : poids et budget côte à côte, moyens de
  /// paiement dessous quand l'expéditeur en a choisi.
  Widget _details(AppLocalizations l, List<String> payments) {
    final r = request;
    final budget = budgetLabel(r);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _photoWidth,
            child: _Photo(photo: photo),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: PosterTile(
                          label: l.requestPosterTileWeight,
                          value: weightLabel(l, r),
                          detail: l.requestPosterSize(
                            r.parcelSize.label(l).toLowerCase(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: PosterTile(
                          label: l.requestPosterTileBudget,
                          value: budget ?? l.requestPosterBudgetNone,
                          detail: r.negotiable
                              ? l.requestPosterNegotiable
                              : l.requestPosterFirmPrice,
                          background: PosterPalette.ink,
                          valueColor: PosterPalette.paper,
                          labelColor: PosterPalette.inkOnDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _PaymentTile(
                    label: l.requestPosterTilePayment,
                    value: payments.join(', '),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Même règle que le corridor de l'affiche de trajet : une ligne quand elle
  /// tient sans trop rapetisser, deux sinon, jamais de troncature.
  Widget _corridor(TextTheme text) {
    final style = (text.displayLarge ?? const TextStyle()).copyWith(
      fontSize: 30,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: PosterPalette.paper,
    );
    final departure = request.departureCity.toUpperCase();
    final arrival = request.arrivalCity.toUpperCase();

    final available = PosterLayout.innerWidth - _heroPadding;
    final oneLineWidth =
        _textWidth(departure, style) +
        _textWidth(arrival, style) +
        _corridorIconSize +
        _corridorGap * 2;

    if (oneLineWidth <= available / _corridorMinScale) {
      return _line([
        Text(departure, style: style),
        const SizedBox(width: _corridorGap),
        _plane(),
        const SizedBox(width: _corridorGap),
        Text(arrival, style: style),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line([Text(departure, style: style)]),
        _line([
          _plane(),
          const SizedBox(width: _corridorGap),
          Text(arrival, style: style),
        ]),
      ],
    );
  }

  Widget _line(List<Widget> children) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );

  Widget _plane() => Transform.rotate(
    angle: math.pi / 2,
    child: const Icon(
      Icons.flight_rounded,
      size: _corridorIconSize,
      color: PosterPalette.ink,
    ),
  );

  static double _textWidth(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// Photo du colis, ou illustration à sa place.
class _Photo extends StatelessWidget {
  const _Photo({required this.photo});

  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    const placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DonyColors.sand200, DonyColors.sand400],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          size: 44,
          color: DonyColors.sand500,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            placeholder
          else
            Image(
              key: const Key('request-poster-photo'),
              image: photo,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => placeholder,
            ),
          // Liseré discret : une photo claire se détache du fond blanc.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: DonyColors.neutral900.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile des moyens de paiement : une liste de noms, pas un chiffre, d'où
/// une valeur sur deux lignes au lieu d'une valeur mise à l'échelle.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: PosterPalette.tile,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: PosterPalette.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: PosterPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}
