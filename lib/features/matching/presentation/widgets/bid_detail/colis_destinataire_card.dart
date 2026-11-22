import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_declined_panel.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte fusionnée « Colis & destinataire » (vue expéditeur).
///
/// Combine [ColisCard] et [DestinataireCard] en une seule surface.
/// Champs : poids/catégorie, description (si non vide), valeur déclarée,
/// nom et téléphone du destinataire.
class ColisDestinataireCard extends StatelessWidget {
  final BidModel bid;

  /// Vue expéditeur : le téléphone du destinataire est toujours affiché. Vue
  /// voyageur : seulement une fois le colis retiré
  /// ([bidAllowsRecipientContact], FLUTTER-JT), même si un ancien serveur
  /// sert déjà le numéro à `ACCEPTED`.
  final bool isSender;

  /// `false` : contenu seul, posé dans un bottom sheet qui porte le titre.
  /// Pas de `DetailCard`, pas de titre de carte.
  final bool framed;

  const ColisDestinataireCard({
    super.key,
    required this.bid,
    this.isSender = true,
    this.framed = true,
  });

  String _colisLabel(AppLocalizations l) {
    final parts = <String>[];
    final weight = bid.displayWeightKg;
    if (weight != null) {
      final added = bid.acquiredAddedWeightKg;
      parts.add(
        added > 0
            ? l.bidDetailParcelWeightWithAdded(
                formatWeightKg(l, weight),
                formatWeightKg(l, added),
              )
            : formatWeightKg(l, weight),
      );
    }
    if (bid.contentCategory != null && bid.contentCategory!.isNotEmpty) {
      parts.add(contentCategoriesDisplayName(l, bid.contentCategory!));
    }
    return parts.isNotEmpty ? parts.join(' · ') : '-';
  }

  String get _bareName {
    final n = bid.recipientName ?? '';
    return n.startsWith('@') ? n.substring(1) : n;
  }

  /// Vue expéditeur : désigné par identifiant, lien ni confirmé ni refusé.
  bool get _isPendingDesignation =>
      isSender &&
      bid.recipientDesignatedByUsername &&
      bid.recipientAppStatus != 'CONFIRMED' &&
      bid.recipientAppStatus != 'DECLINED';

  /// Vue voyageur : pour un destinataire désigné par identifiant dont le lien
  /// est absent ou en attente, le back sert « @identifiant » brut, sans numéro
  /// ni statut, et jamais le drapeau de désignation (réservé à l'expéditeur).
  bool get _isTravelerUnconfirmed =>
      !isSender &&
      !bid.recipientDeclined &&
      (bid.recipientName ?? '').startsWith('@') &&
      bid.recipientAppStatus != 'CONFIRMED' &&
      (bid.recipientPhone ?? '').isEmpty;

  bool get _showPhoneRow {
    if (_isPendingDesignation || _isTravelerUnconfirmed) return false;
    final noPhone = (bid.recipientPhone ?? '').isEmpty;
    // Désigné par identifiant et confirmé, numéro masqué : pas de ligne vide.
    // Un colis par numéro a toujours un numéro saisi, il n'est pas concerné.
    if (noPhone && !bid.recipientPhoneHidden) {
      if (isSender && bid.recipientDesignatedByUsername) return false;
      if (bid.recipientAppStatus == 'CONFIRMED' &&
          !(bid.recipientName ?? '').startsWith('@')) {
        return false;
      }
    }
    return isSender ||
        (bidAllowsRecipientContact(bid.status) && !bid.recipientDeclined);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = Column(
      children: [
        if (bid.photos.isNotEmpty) ...[
          _PhotoGallery(photos: bid.photos),
          const SizedBox(height: DonySpacing.md),
        ],
        InfoRow(label: l.bidDetailParcelLabel, value: _colisLabel(l)),
        if (bid.description != null && bid.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: l.bidDetailDescriptionLabel, value: bid.description!),
        ],
        const SizedBox(height: DonySpacing.sm),
        // Vue voyageur, destinataire en refus (FLUTTER-E8) : ni nom ni
        // numéro, l'encart propose d'en demander un autre à l'expéditeur.
        if (!isSender && bid.recipientDeclined) ...[
          const SizedBox(height: DonySpacing.xs),
          RecipientDeclinedPanel(bid: bid),
        ] else if (_isPendingDesignation) ...[
          // Désigné par identifiant, lien pas encore confirmé : « @identifiant »
          // et une pastille, sans numéro (il n'existe pas encore).
          InfoRow(
            label: l.bidDetailRecipientLabel,
            value: '@${bid.recipientUsername ?? _bareName}',
          ),
          const SizedBox(height: DonySpacing.xs),
          const _PendingConfirmationPill(),
        ] else if (_isTravelerUnconfirmed) ...[
          InfoRow(
            label: l.bidDetailRecipientLabel,
            value: l.recipientNotConfirmedLabel,
          ),
        ] else ...[
          InfoRow(
            label: l.bidDetailRecipientLabel,
            value: bid.recipientName ?? '-',
          ),
        ],
        if (_showPhoneRow) ...[
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: l.bidDetailPhoneLabel,
            value: bid.recipientPhoneHidden
                ? l.recipientPhoneHiddenLabel
                : bid.recipientPhone ?? '-',
          ),
        ],
        // Jusqu'à la remise, l'expéditeur peut changer de destinataire.
        if (isSender && bid.canChangeRecipient)
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: l.recipientChangeEditTooltip,
              child: TextButton.icon(
                onPressed: () => openRecipientChangeSheet(context, bid),
                icon: DonyIcon(
                  'square-pen',
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(l.commonEdit),
              ),
            ),
          ),
      ],
    );
    if (!framed) return content;
    return DetailCard(title: l.bidDetailParcelRecipientTitle, child: content);
  }
}

/// Pastille « En attente de confirmation » du destinataire désigné par
/// identifiant, alignée sur la colonne des valeurs.
class _PendingConfirmationPill extends StatelessWidget {
  const _PendingConfirmationPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xs,
            ),
            child: Text(
              context.l10n.designatedUserPending,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos});
  final List<BidPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = photos.take(3).toList();
    final extra = photos.length - shown.length;
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => BidPhotoViewerModal.show(
                context,
                photos: photos,
                initialIndex: i,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: shown[i].url,
                        cacheKey: DonyImage.stableCacheKey(shown[i].url),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            ColoredBox(color: cs.surfaceContainerHighest),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (i == shown.length - 1 && extra > 0)
                        ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Text(
                              '+$extra',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (i != shown.length - 1) const SizedBox(width: DonySpacing.sm),
        ],
      ],
    );
  }
}
