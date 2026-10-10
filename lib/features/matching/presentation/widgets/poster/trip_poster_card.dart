import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_stops_badge.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Affiche partageable d'un trajet, destinée à être capturée en PNG puis
/// postée par le voyageur sur ses propres canaux (Facebook, WhatsApp, TikTok).
///
/// De haut en bas : la marque, le corridor dans un bandeau bleu nuit avec
/// l'horaire et le voyageur (note, trajets, identité vérifiée), trois tuiles
/// chiffrées (place libre avec sa jauge, prix, dépôt limite), les lieux, les
/// objets acceptés, puis un QR code vers la page publique du trajet.
///
/// **Aucun numéro de téléphone.** Les affiches concurrentes en placardent deux
/// à quatre ; celle-ci n'en porte aucun, les demandes arrivent qualifiées dans
/// l'application.
///
/// **Aucune URL écrite.** Elle n'est cliquable sur aucune plateforme et
/// personne ne recopie 80 caractères portant un UUID. Le lien vit dans la
/// légende, et dans le QR code pour qui ne voit que l'image.
///
/// **Chaque ligne est facultative.** Une information absente (pas de dépôt
/// limite, pas d'adresse, voyageur sans note) retire sa ligne sans laisser de
/// trou, et une affiche très remplie se réduit légèrement plutôt que de
/// déborder : le pied, lui, reste toujours à sa place.
class TripPosterCard extends StatelessWidget {
  const TripPosterCard({super.key, required this.announcement, this.qrData});

  final AnnouncementModel announcement;

  /// Lien encodé dans le QR code du pied. Sans lui, pas de QR.
  final String? qrData;

  static const double logicalWidth = PosterLayout.width;
  static const double logicalHeight = PosterLayout.height;

  /// Publics car l'écran d'aperçu doit les précharger avant de rastériser.
  static const String appStoreBadgeAsset = PosterAssets.appStoreBadge;
  static const String googlePlayBadgeAsset = PosterAssets.googlePlayBadge;

  /// Formats de date partagés avec la légende de l'écran d'aperçu, ce qui
  /// garantit que l'image et le texte du post annoncent la même chose.
  static DateFormat dayFormat(String locale) => DateFormat.MMMMEEEEd(locale);

  /// `HH'h'mm` (fr) / `h:mm a` (en) : « 14h05 » est une typographie française
  /// que le squelette intl `jm` ne produit pas, d'où un motif stocké dans
  /// l'ARB (`tripPosterTimePattern`) plutôt qu'un squelette.
  static String timeLabel(AppLocalizations l, String locale, DateTime t) =>
      DateFormat(l.tripPosterTimePattern, locale).format(t);

  static String deadlineLabel(
    AppLocalizations l,
    String locale,
    DateTime deadline,
  ) => l.commonDateAtTime(
    DateFormat.MMMMd(locale).format(deadline),
    timeLabel(l, locale, deadline),
  );

  /// Capacité telle qu'elle doit être annoncée.
  ///
  /// `KG_FREE` signifie « pas de plafond déclaré » : `availableKg` n'est alors
  /// qu'une valeur de forme, et l'imprimer comme une limite tromperait
  /// l'expéditeur. Tout le reste de l'application dit « Kg libre » dans ce cas.
  static String capacityLabel(AppLocalizations l, AnnouncementModel a) =>
      a.isKgFree ? l.tripKgFree : '${formatKgPrice(a.availableKg)} kg';

  /// Moyens de paiement acceptés, dans l'ordre de l'énumération (carte,
  /// espèces, puis mobile money) : « Carte, Espèces, Wave ». Vide si le
  /// trajet n'en déclare aucun. Les libellés sont ceux de la demande d'envoi,
  /// les deux énumérations partageant leurs valeurs d'API.
  static String paymentLabel(AppLocalizations l, AnnouncementModel a) => [
    for (final m in BidPaymentMethod.values)
      if (a.acceptedPaymentMethods.contains(m))
        PaymentMethod.tryFromWire(m.apiValue)?.label(l),
  ].nonNulls.join(', ');

  /// Heure « HH:mm » saisie par le voyageur, posée sur [day]. `null` si
  /// absente ou illisible : la ligne se contente alors du jour.
  static DateTime? _at(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// Ligne horaire du bandeau : « Départ sam. 18 oct., 14h05 · arrivée
  /// 21h40 ». L'arrivée porte sa date quand elle tombe un autre jour (vol de
  /// nuit), sinon son heure seule. Jour abrégé : en toutes lettres, la ligne
  /// ne tient pas sur la largeur de l'affiche dès qu'une arrivée s'y ajoute.
  static String scheduleLabel(AppLocalizations l, AnnouncementModel a) {
    final locale = l.localeName;
    final day = DateFormat.MMMEd(locale).format(a.departureDate);
    final departureAt = _at(a.departureDate, a.departureTime);
    final departure = departureAt == null
        ? l.tripPosterHeroDeparture(day)
        : l.tripPosterHeroDepartureAt(day, timeLabel(l, locale, departureAt));

    final arrivalDay = a.arrivalDate;
    final arrivalAt = _at(arrivalDay ?? a.departureDate, a.arrivalTime);
    final otherDay =
        arrivalDay != null && !DateUtils.isSameDay(arrivalDay, a.departureDate);
    final String? arrival;
    if (otherDay) {
      final date = DateFormat.MMMd(locale).format(arrivalDay);
      arrival = arrivalAt == null
          ? date
          : l.commonDateAtTime(date, timeLabel(l, locale, arrivalAt));
    } else {
      arrival = arrivalAt == null ? null : timeLabel(l, locale, arrivalAt);
    }
    return arrival == null
        ? departure
        : '$departure · ${l.tripPosterHeroArrival(arrival)}';
  }

  /// Réduction maximale tolérée pour garder le corridor sur une seule ligne.
  ///
  /// En deçà, le titre de l'affiche deviendrait plus petit que les libellés qui
  /// le suivent, ce qui inverserait la hiérarchie de lecture. On passe alors
  /// sur deux lignes plutôt que de continuer à rapetisser.
  static const double _corridorMinScale = 0.8;
  static const double _corridorIconSize = 26;
  static const double _corridorGap = 10;

  /// Padding horizontal du bandeau, déduit de la largeur du corridor.
  static const double _heroPadding = 28;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final a = announcement;
    final pickup = a.pickupAddress?.label;
    final delivery = a.deliveryAddress?.label;
    final payment = paymentLabel(l, a);
    final accepted = [
      for (final t in a.acceptedContentTypes ?? const <String>[])
        contentCategoryDisplayName(l, t),
    ];

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
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
                          label: l.tripPosterBadge,
                          background: PosterPalette.blueTint,
                          foreground: PosterPalette.blue,
                        ),
                        const SizedBox(height: PosterLayout.gap),
                        PosterHero(
                          background: PosterPalette.ink,
                          eyebrow: _eyebrow(l),
                          corridor: _corridor(text),
                          subtitle: scheduleLabel(l, a),
                          footer: a.traveler == null
                              ? null
                              : _TravelerRow(traveler: a.traveler!),
                        ),
                        const SizedBox(height: PosterLayout.gap),
                        _tiles(l),
                        if (pickup != null || delivery != null) ...[
                          const SizedBox(height: PosterLayout.gap),
                          if (pickup != null)
                            PosterPlaceRow(
                              label: l.tripPosterHandoverLabel,
                              value: pickup,
                            ),
                          if (pickup != null && delivery != null)
                            const SizedBox(height: 4),
                          if (delivery != null)
                            PosterPlaceRow(
                              label: l.tripPosterPickupLabel,
                              value: delivery,
                            ),
                        ],
                        if (payment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          PosterPlaceRow(
                            label: l.tripPosterPayment,
                            value: payment,
                          ),
                        ],
                        if (accepted.isNotEmpty) ...[
                          const SizedBox(height: PosterLayout.gap),
                          PosterChipRow(
                            label: l.tripPosterAccepts,
                            items: accepted,
                            background: PosterPalette.blueTint,
                            foreground: PosterPalette.blue,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PosterLayout.gap),
              PosterFooter(
                title: l.tripPosterFooterTitle,
                subtitle: l.tripPosterFooterSubtitle,
                qrData: qrData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « TRAJET · AVION · VOL DIRECT » : nature, mode de transport, escales.
  String _eyebrow(AppLocalizations l) {
    final mode = announcement.transportMode;
    final stops = announcement.stops;
    return [
      l.tripPosterEyebrow,
      if (mode != null) mode.label(l),
      if (stops != null) tripStopsBadgeLabel(l, stops),
    ].join(' · ');
  }

  /// Corridor : départ puis arrivée, séparés par l'avion qui pointe vers la
  /// droite, dans le sens de la lecture donc du voyage.
  ///
  /// **La disposition suit la longueur des noms.** « MARSEILLE ✈ OUAGADOUGOU »
  /// est deux fois plus large que « PARIS ✈ DAKAR » : tout ramener de force
  /// sur une ligne le réduirait à la taille du corps de texte. Au-delà de
  /// [_corridorMinScale], on repasse donc sur deux lignes.
  ///
  /// Jamais de troncature : une ellipse amputerait un nom de ville et rendrait
  /// l'affiche inutilisable. On réduit, ou on réorganise.
  Widget _corridor(TextTheme text) {
    final style = (text.displayLarge ?? const TextStyle()).copyWith(
      fontSize: 30,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: PosterPalette.paper,
    );

    final departure = announcement.departureCity.toUpperCase();
    final arrival = announcement.arrivalCity.toUpperCase();

    final available = PosterLayout.innerWidth - _heroPadding;
    final oneLineWidth =
        _textWidth(departure, style) +
        _textWidth(arrival, style) +
        _corridorIconSize +
        _corridorGap * 2;
    final fitsOnOneLine = oneLineWidth <= available / _corridorMinScale;

    if (fitsOnOneLine) {
      return _corridorLine([
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
        _corridorLine([Text(departure, style: style)]),
        _corridorLine([
          _plane(),
          const SizedBox(width: _corridorGap),
          Text(arrival, style: style),
        ]),
      ],
    );
  }

  /// Une ligne de corridor, mise à l'échelle si elle dépasse encore : un seul
  /// nom de ville peut à lui seul être trop large.
  Widget _corridorLine(List<Widget> children) => SizedBox(
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
      color: PosterPalette.terra,
    ),
  );

  /// Largeur rendue d'un texte, pour arbitrer la disposition avant de peindre.
  static double _textWidth(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      // `intl` exporte lui aussi un TextDirection : sans le préfixe, c'est le
      // sien qui gagne et il n'a pas de membre `ltr`.
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Les trois tuiles chiffrées, de même hauteur. Sans dépôt limite, il en
  /// reste deux, plus larges, plutôt qu'une case vide.
  Widget _tiles(AppLocalizations l) {
    final a = announcement;
    final deadline = a.handoverDeadline;
    final locale = l.localeName;
    final total = a.totalKg;
    final tiles = <Widget>[
      PosterTile(
        label: l.tripPosterTileCapacity,
        value: capacityLabel(l, a),
        detail: a.isKgFree || total <= 0
            ? null
            : l.tripPosterCapacityOf('${formatKgPrice(total)} kg'),
        gauge: a.isKgFree || total <= 0 ? null : a.availableKg / total,
      ),
      _priceTile(l),
      if (deadline != null)
        PosterTile(
          label: l.tripPosterTileDeadline,
          value: DateFormat.MMMd(locale).format(deadline),
          // La date limite de dépôt est le vrai butoir commercial : c'est elle
          // qui déclenche la décision de l'expéditeur. Toutes les affiches du
          // marché la mettent en avant en couleur chaude.
          valueColor: PosterPalette.terra,
          detail: l.tripPosterTileDeadlineTime(timeLabel(l, locale, deadline)),
        ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  /// Tuile prix, déclinée selon le mode de tarification du trajet.
  ///
  /// Un trajet vendu à l'article n'a pas forcément de tarif au kilo : la
  /// colonne backend étant `NOT NULL`, le formulaire y écrit `0.0`, si bien
  /// qu'un affichage naïf annoncerait « 0 € le kilo ». Le mode commande donc
  /// ce qui est mis en avant. Le prix est toujours celui que paie
  /// l'expéditeur, commission comprise : `pricePerKg` seul est le net
  /// voyageur, un tarif que personne ne paie.
  Widget _priceTile(AppLocalizations l) {
    final a = announcement;
    final currency = a.currency;
    final grid = a.cheapestGridPrice;
    final senderPricePerKg = a.senderPricePerKg;
    final hasKg = a.hasKgPrice;

    final String value;
    final String detail;
    if (grid != null) {
      // « dès », parce qu'un prix de grille est un point d'entrée : c'est
      // l'article le moins cher, pas le tarif de tous les articles.
      value = l.tripPosterFromPrice(formatPriceIn(grid, currency));
      detail = hasKg && senderPricePerKg != null
          ? '${l.tripPosterUnitPerItem} · '
                '${l.tripPosterPricePerKg(formatPriceIn(senderPricePerKg, currency))}'
          : l.tripPosterUnitPerItem;
    } else {
      value = hasKg
          ? formatPriceIn(senderPricePerKg!, currency)
          : l.tripPosterPriceUnavailable;
      detail = l.tripPosterUnitPerKg;
    }
    return PosterTile(
      label: l.tripPosterTilePrice,
      value: value,
      detail: detail,
      background: PosterPalette.blue,
      valueColor: PosterPalette.paper,
      labelColor: PosterPalette.blueOnDark,
    );
  }
}

/// Ligne du voyageur, au pied du bandeau : initiales, nom, note et trajets,
/// badge d'identité vérifiée quand il est vrai.
///
/// Les initiales et non la photo : une image réseau peut ne pas être chargée
/// au moment de la capture, et une affiche ne doit pas changer selon la
/// qualité de la connexion.
class _TravelerRow extends StatelessWidget {
  const _TravelerRow({required this.traveler});

  final TravelerProfile traveler;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final rating = traveler.averageRating;
    final trips = traveler.totalTrips;
    final stats = [
      if (rating != null && rating > 0)
        '★ ${NumberFormat('0.0', l.localeName).format(rating)}',
      if (trips != null && trips > 0) l.tripPosterTravelerTrips(trips),
    ].join(' · ');

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: PosterPalette.blue,
            shape: BoxShape.circle,
          ),
          child: Text(
            traveler.resolvedInitials,
            style: text.labelLarge?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: PosterPalette.paper,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Nom puis note et trajets sur une seule ligne : le bandeau porte
        // déjà le titre de l'affiche, la place se gagne ici.
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: traveler.travelerName(l),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (stats.isNotEmpty)
                  TextSpan(
                    text: ' · $stats',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: PosterPalette.paper.withValues(alpha: 0.8),
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 12,
              color: PosterPalette.paper,
            ),
          ),
        ),
        if (traveler.kycVerified) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: PosterPalette.paper.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 12,
                  color: PosterPalette.paper,
                ),
                const SizedBox(width: 4),
                Text(
                  l.tripPosterVerified,
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PosterPalette.paper,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
