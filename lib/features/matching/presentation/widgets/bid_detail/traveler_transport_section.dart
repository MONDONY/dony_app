import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_detail_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Section « Votre transport » de la fiche colis (vue voyageur) : un titre puis
/// la grille des tuiles de [travelerTilesFor], chacune ouvrant son bottom sheet
/// ([openTravelerTileSheet]).
///
/// Le tap ouvre le sheet avec le contexte de ce widget (jamais celui de la
/// tuile) : la liste des tuiles change au rafraîchissement du colis et le
/// sheet ne doit pas dépendre d'une tuile qui disparaît.
class TravelerTransportSection extends StatelessWidget {
  const TravelerTransportSection({super.key, required this.bid});

  final BidModel bid;

  /// Première valeur non blanche de [values], `null` si aucune.
  static String? _firstText(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Colis accepté, pas encore remis, avec une date limite de dépôt connue.
  bool get _showsDeadline =>
      bid.status == 'ACCEPTED' && bid.handoverDeadline != null;

  /// Résumé de la tuile Lieux : où remettre le colis tant qu'il n'est pas chez
  /// le voyageur, où le destinataire le récupère ensuite. La ville d'abord, à
  /// défaut le libellé de l'adresse ; `null` quand l'étape n'a rien de connu.
  ///
  /// Il ne parle que d'une ligne que la feuille Lieux montre (le dépôt si une
  /// adresse ou un texte de dépôt existe, la récupération si une adresse
  /// d'arrivée existe) : une ville sans cette ligne promettrait un lieu que
  /// la feuille n'affiche pas.
  ///
  /// Colis accepté, pas encore remis, avec une date limite de dépôt connue :
  /// cette échéance d'abord, en heure locale (décision du propriétaire, elle
  /// n'est sinon que dans « Plus de détails »).
  String? _placesSubtitle(AppLocalizations l) {
    final deadline = bid.handoverDeadline;
    if (_showsDeadline && deadline != null) {
      // Instant UTC : jour et heure de l'appareil, comme les autres
      // échéances de la fiche (PROD-1R).
      final local = deadline.toLocal();
      return l.travelerTileLieuxDeadline(
        DateFormat.MMMEd(l.localeName).format(local),
        DateFormat.jm(l.localeName).format(local),
      );
    }
    if (!kParcelHandedOverStatuses.contains(bid.status)) {
      final hasHandoverRow =
          bid.handoverAddress != null ||
          (bid.handoverLocation?.trim().isNotEmpty ?? false);
      if (!hasHandoverRow) return null;
      final place = _firstText([
        bid.departureCity,
        bid.handoverAddress?.label,
        bid.handoverLocation,
      ]);
      return place == null ? null : l.travelerTileLieuxDropoff(place);
    }
    if (bid.deliveryAddress == null) return null;
    final place = _firstText([bid.arrivalCity, bid.deliveryAddress?.label]);
    return place == null ? null : l.travelerTileLieuxPickup(place);
  }

  /// Résumé de la tuile Colis : poids puis destinataire. Un destinataire qui a
  /// refusé n'est pas nommé : la carte du sheet cache aussi son nom.
  String? _parcelSubtitle(AppLocalizations l) {
    final weight = bid.displayWeightKg;
    if (weight == null) return null;
    final recipient = bid.recipientName?.trim() ?? '';
    if (recipient.isEmpty || bid.recipientDeclined) {
      return formatWeightKg(l, weight);
    }
    return l.travelerTileColisSubtitle(formatWeightKg(l, weight), recipient);
  }

  /// Le destinataire a refusé (ou s'est retiré, FLUTTER-E8) et le voyageur
  /// peut demander un autre destinataire : colis en cours de transport, et
  /// pas de demande envoyée depuis moins de 12 h. Le geste vit dans le sheet
  /// Colis (`RecipientDeclinedPanel`) : la tuile porte alors une pastille,
  /// sinon il resterait invisible. [now] : horloge de « À traiter » de
  /// l'écran du trajet (`tripTodoFor`), par défaut l'heure de l'appareil.
  static bool recipientNeedsReplacement(BidModel bid, {DateTime? now}) {
    if (!bid.recipientDeclined || !bid.canChangeRecipient) return false;
    final next = bid.nextRecipientReplacementAllowedAt;
    return next == null || !next.isAfter(now ?? DateTime.now());
  }

  Widget _tileFor(BuildContext context, TravelerTile tile) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;

    final (iconName, label, color) = switch (tile) {
      TravelerTile.lieux => ('map-pin', l.travelerTileLieux, cs.secondary),
      TravelerTile.colis => ('package', l.travelerTileColis, cs.primary),
      TravelerTile.details => ('file-text', l.bidDetailMoreDetails, cs.primary),
    };
    final subtitle = switch (tile) {
      TravelerTile.lieux => _placesSubtitle(l),
      TravelerTile.colis => _parcelSubtitle(l),
      TravelerTile.details => l.travelerTileDetailsSubtitle,
    };

    return DonyActionTile(
      key: Key('traveler-tile-${tile.name}'),
      iconName: iconName,
      label: label,
      subtitle: subtitle,
      // La date limite de dépôt (date et heure) reste entière à 360 dp et en
      // grand texte.
      subtitleMaxLines: tile == TravelerTile.lieux && _showsDeadline ? 3 : 2,
      color: color,
      badge: tile == TravelerTile.colis && recipientNeedsReplacement(bid)
          ? ToolStatusBadge(
              ready: false,
              tone: ToolStatusTone.news,
              label: l.travelerTileBadgeTodo,
              semanticsLabel: l.recipientDeclinedTravelerTitle,
            )
          : null,
      onTap: () => unawaited(openTravelerTileSheet(context, bid, tile)),
    );
  }

  @override
  Widget build(BuildContext context) => BidDetailSection(
    title: context.l10n.bidDetailSectionTransport,
    spacing: DonySpacing.md,
    children: [
      DonyActionTileGrid(
        tiles: [
          for (final tile in travelerTilesFor(bid)) _tileFor(context, tile),
        ],
      ),
    ],
  );
}
