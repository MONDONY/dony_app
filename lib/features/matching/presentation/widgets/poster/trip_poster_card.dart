import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
/// De haut en bas : la marque, le corridor dans un bandeau bleu nuit (drapeaux
/// des deux pays, date de départ en gros, horaire, voyageur avec note, trajets
/// et identité vérifiée), trois tuiles chiffrées (prix, place libre avec sa
/// jauge, dépôt limite en rouge), la grille de prix par article, le lieu de
/// remise, puis un QR code vers la page publique du trajet.
///
/// **La grille d'articles prend la place des moyens de paiement et des types
/// d'objets acceptés** : une affiche de 360 x 450 ne porte pas tout, et le prix
/// par article répond à la première question de l'expéditeur. Sans grille,
/// ces deux lignes reviennent.
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

  /// Horaire du bloc de départ : « 14h30 → 20h05 ». L'arrivée porte sa date
  /// quand elle tombe un autre jour (vol de nuit), sinon son heure seule.
  /// `null` sans heure de départ : le bloc ne garde alors que la date.
  static String? timesLabel(AppLocalizations l, AnnouncementModel a) {
    final locale = l.localeName;
    final departureAt = _at(a.departureDate, a.departureTime);
    if (departureAt == null) return null;
    final departure = timeLabel(l, locale, departureAt);

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
        : l.tripPosterTimeRange(departure, arrival);
  }

  /// Réduction maximale tolérée pour garder le corridor sur une seule ligne.
  ///
  /// En deçà, le titre de l'affiche deviendrait plus petit que les libellés qui
  /// le suivent, ce qui inverserait la hiérarchie de lecture. On passe alors
  /// sur deux lignes plutôt que de continuer à rapetisser.
  static const double _corridorMinScale = 0.8;
  static const double _corridorIconSize = 22;
  static const double _corridorGap = 8;

  /// Padding horizontal du bandeau, déduit de la largeur du corridor.
  static const double _heroPadding = 28;

  /// Espacement entre blocs quand la grille d'articles est affichée.
  static const double _denseGap = 6;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final a = announcement;
    final pickup = a.pickupAddress?.label;
    final delivery = a.deliveryAddress?.label;
    final payment = paymentLabel(l, a);
    final hasGrid = a.priceGridItems.isNotEmpty;
    // La grille d'articles ajoute une rangée de plus : on resserre les blocs
    // pour que l'affiche reste lisible sans réduire tout le contenu.
    final gap = hasGrid ? _denseGap : PosterLayout.gap;
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
                        SizedBox(height: gap),
                        PosterHero(
                          background: PosterPalette.ink,
                          corridor: _corridor(text),
                          body: PosterDateBlock(
                            color: PosterPalette.terra,
                            label: l
                                .tripPosterDateLabel(
                                  DateFormat.E(
                                    l.localeName,
                                  ).format(a.departureDate),
                                )
                                .toUpperCase(),
                            value: DateFormat(
                              'd MMM',
                              l.localeName,
                            ).format(a.departureDate).toUpperCase(),
                            valueKey: const Key('poster-departure-day'),
                            title: timesLabel(l, a),
                            // Avec la grille, la place manque pour une ligne de
                            // lieux : la remise passe sous l'horaire.
                            detail: hasGrid && pickup != null
                                ? l.tripPosterCaptionHandover(pickup)
                                : _transportDetail(l),
                          ),
                          footer: a.traveler == null
                              ? null
                              : _TravelerRow(traveler: a.traveler!),
                        ),
                        SizedBox(height: gap),
                        _tiles(l),
                        if (hasGrid) ...[
                          SizedBox(height: gap),
                          _ItemsGrid(
                            items: a.priceGridItems,
                            currency: a.currency,
                          ),
                        ] else ...[
                          if (pickup != null || delivery != null) ...[
                            SizedBox(height: gap),
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
                            SizedBox(height: gap),
                            PosterChipRow(
                              label: l.tripPosterAccepts,
                              items: accepted,
                              background: PosterPalette.blueTint,
                              foreground: PosterPalette.blue,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
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

  /// « Avion · Vol direct » : mode de transport et escales, sous l'horaire.
  /// `null` quand le trajet ne déclare ni l'un ni l'autre.
  String? _transportDetail(AppLocalizations l) {
    final mode = announcement.transportMode;
    final stops = announcement.stops;
    final parts = [
      if (mode != null) mode.label(l),
      if (stops != null) tripStopsBadgeLabel(l, stops),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
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
      fontSize: 28,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: PosterPalette.paper,
    );

    final departure = announcement.departureCity.toUpperCase();
    final arrival = announcement.arrivalCity.toUpperCase();
    final departureFlag = countryFlagEmoji(announcement.departureCountryCode);
    final arrivalFlag = countryFlagEmoji(announcement.arrivalCountryCode);

    // Un drapeau absent (code pays manquant ou mal formé) disparaît avec son
    // espace : le corridor ne garde pas de trou.
    final flagsWidth =
        (departureFlag == null ? 0 : _Flag.size + _corridorGap) +
        (arrivalFlag == null ? 0 : _Flag.size + _corridorGap);
    final available = PosterLayout.innerWidth - _heroPadding;
    final oneLineWidth =
        _textWidth(departure, style) +
        _textWidth(arrival, style) +
        _corridorIconSize +
        _corridorGap * 2 +
        flagsWidth;
    final fitsOnOneLine = oneLineWidth <= available / _corridorMinScale;

    Widget city(String name, String? flag, {required bool flagFirst}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flag != null && flagFirst) ...[
          _Flag(emoji: flag),
          const SizedBox(width: _corridorGap),
        ],
        Text(name, style: style),
        if (flag != null && !flagFirst) ...[
          const SizedBox(width: _corridorGap),
          _Flag(emoji: flag),
        ],
      ],
    );

    if (fitsOnOneLine) {
      return _corridorLine([
        city(departure, departureFlag, flagFirst: true),
        const SizedBox(width: _corridorGap),
        _plane(),
        const SizedBox(width: _corridorGap),
        city(arrival, arrivalFlag, flagFirst: false),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _corridorLine([city(departure, departureFlag, flagFirst: true)]),
        _corridorLine([
          _plane(),
          const SizedBox(width: _corridorGap),
          city(arrival, arrivalFlag, flagFirst: false),
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
    // Heure murale de la ville de départ, comme le départ (PROD-1R).
    final deadlineInstant = a.handoverDeadline;
    final deadline = deadlineInstant == null
        ? null
        : tripWallTime(deadlineInstant, a.departureTimezone).wallClock;
    final locale = l.localeName;
    final total = a.totalKg;
    final tiles = <Widget>[
      _priceTile(l),
      PosterTile(
        label: l.tripPosterTileCapacity,
        value: capacityLabel(l, a),
        gauge: a.isKgFree || total <= 0 ? null : a.availableKg / total,
      ),
      if (deadline != null)
        PosterTile(
          label: l.tripPosterTileDeadline,
          value: DateFormat.MMMd(locale).format(deadline),
          // La date limite de dépôt est le vrai butoir commercial : c'est elle
          // qui déclenche la décision de l'expéditeur. Les affiches du marché
          // la mettent en rouge, sur fond plein pour qu'elle saute aux yeux.
          background: PosterPalette.danger,
          valueColor: PosterPalette.paper,
          labelColor: PosterPalette.paper.withValues(alpha: 0.85),
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
    // Prix frais de service inclus, comme la carte de recherche
    // (YADONY-FLUTTER-PROD-1J).
    final grid = a.searchCheapestGridPrice;
    final senderPricePerKg = a.searchCardPricePerKg;
    final hasKg = a.hasKgPrice;

    final String value;
    final String? detail;
    if (hasKg && senderPricePerKg != null) {
      // Le prix au kilo est celui que l'expéditeur compare d'abord (« 10 €/kg »
      // sur toutes les affiches du marché) ; la grille, qui s'affiche en
      // dessous, ne reste ici qu'un « dès » en précision.
      value = l.tripPosterPricePerKgShort(
        formatPriceIn(senderPricePerKg, currency),
      );
      detail = grid != null
          ? l.tripPosterPriceFromItem(formatPriceIn(grid, currency))
          : null;
    } else if (grid != null) {
      // « dès », parce qu'un prix de grille est un point d'entrée : c'est
      // l'article le moins cher, pas le tarif de tous les articles.
      value = l.tripPosterFromPrice(formatPriceIn(grid, currency));
      detail = l.tripPosterUnitPerItem;
    } else {
      value = l.tripPosterPriceUnavailable;
      detail = null;
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
        //
        // **Le nom cède en premier.** La note et le nombre de trajets sont ce
        // qui rassure l'expéditeur : coupés en « 12 traj… » ils ne disent plus
        // rien, alors qu'un nom raccourci reste reconnaissable.
        Expanded(
          child: _NameAndStats(
            name: traveler.travelerName(l),
            stats: stats,
            baseStyle: (text.bodySmall ?? const TextStyle()).copyWith(
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
        if (traveler.gpPro) ...[
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
                const DonyIcon('luggage', size: 12, color: PosterPalette.paper),
                const SizedBox(width: 4),
                Text(
                  l.gpProBadgeLabel,
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

/// Drapeau d'un pays dans une pastille ronde, posé de part et d'autre du
/// corridor : les deux pays se lisent avant même les noms de villes.
///
/// L'emoji et non une image : un asset de plus à précharger avant la capture,
/// pour un rendu que le système de l'appareil fournit déjà.
class _Flag extends StatelessWidget {
  const _Flag({required this.emoji});

  final String emoji;

  static const double size = 28;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const Key('poster-flag'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: PosterPalette.paper,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16, height: 1)),
      ),
    );
  }
}

/// Grille de prix par article : six cases au plus, sur deux rangées de trois.
/// Au-delà de six articles, la sixième case devient « + N » et renvoie à
/// l'application, via le QR code du pied.
class _ItemsGrid extends StatelessWidget {
  const _ItemsGrid({required this.items, required this.currency});

  final List<AnnouncementGridItemModel> items;
  final String currency;

  static const int _slots = 6;
  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final overflow = items.length > _slots;
    final shown = overflow ? items.take(_slots - 1).toList() : items;
    final hidden = items.length - shown.length;

    final cells = <Widget>[
      for (final item in shown)
        _ItemCell(
          label: item.label,
          price: formatPriceIn(item.unitPriceDisplay, currency),
        ),
      if (overflow) _MoreCell(count: hidden, label: l.tripPosterItemsMore),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.tripPosterItemsTitle.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: PosterPalette.muted,
                ),
              ),
            ),
            Text(
              l.tripPosterItemsCount(items.length),
              maxLines: 1,
              style: text.labelSmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: PosterPalette.terra,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (var start = 0; start < cells.length; start += _columns) ...[
          if (start > 0) const SizedBox(height: 5),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _columns; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: start + i < cells.length
                        ? cells[start + i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemCell extends StatelessWidget {
  const _ItemCell({required this.label, required this.price});

  final String label;
  final String price;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('poster-item'),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: PosterPalette.tile,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Réduit plutôt que tronqué : « Ordinateur portable » coupé en
          // « Ordinateur po… » ne dit plus de quel article on parle.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: text.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PosterPalette.ink,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              price,
              maxLines: 1,
              style: text.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: PosterPalette.blue,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCell extends StatelessWidget {
  const _MoreCell({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('poster-items-more'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosterPalette.blueTint,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+ $count',
            maxLines: 1,
            style: text.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PosterPalette.blue,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: text.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PosterPalette.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nom du voyageur suivi de sa note et de ses trajets, sur une ligne : le nom
/// est tronqué avec « … » pour laisser toute la place aux statistiques, qui ne
/// se réduisent que si elles dépassent à elles seules la largeur disponible.
class _NameAndStats extends StatelessWidget {
  const _NameAndStats({
    required this.name,
    required this.stats,
    required this.baseStyle,
  });

  final String name;
  final String stats;
  final TextStyle baseStyle;

  /// Part minimale de la largeur réservée au nom.
  static const double _nameMinShare = 0.45;

  @override
  Widget build(BuildContext context) {
    final nameStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
    final statsStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w500,
      color: PosterPalette.paper.withValues(alpha: 0.8),
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    if (stats.isEmpty) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      );
    }
    final statsText = ' · $stats';
    return LayoutBuilder(
      builder: (context, constraints) {
        final statsWidth = TripPosterCard._textWidth(statsText, statsStyle);
        // Le nom garde un plancher, même avec deux badges : sans lui, des
        // statistiques larges l'effaçaient et il ne restait que « · ★ 4,8 ».
        // Un nom court n'est jamais coupé : c'est alors la note qui se réduit
        // légèrement.
        final nameFloor = math.min(
          TripPosterCard._textWidth(name, nameStyle),
          constraints.maxWidth * _nameMinShare,
        );
        final nameMax = (constraints.maxWidth - statsWidth).clamp(
          nameFloor,
          constraints.maxWidth,
        );
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: nameMax),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  statsText,
                  maxLines: 1,
                  softWrap: false,
                  style: statsStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
