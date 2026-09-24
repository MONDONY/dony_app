import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte fusionnée « Colis & destinataire » (vue expéditeur).
///
/// Combine [ColisCard] et [DestinataireCard] en une seule surface.
/// Champs : poids/catégorie, description (si non vide), valeur déclarée,
/// nom et téléphone du destinataire.
class ColisDestinataireCard extends StatelessWidget {
  final BidModel bid;

  const ColisDestinataireCard({super.key, required this.bid});

  String get _colisLabel {
    final parts = <String>[];
    if (bid.weightKg != null) {
      parts.add('${bid.weightKg} kg');
    }
    if (bid.contentCategory != null && bid.contentCategory!.isNotEmpty) {
      parts.add(bid.contentCategory!);
    }
    return parts.isNotEmpty ? parts.join(' · ') : '-';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DetailCard(
      title: l.bidDetailParcelRecipientTitle,
      child: Column(
        children: [
          if (bid.photos.isNotEmpty) ...[
            _PhotoGallery(photos: bid.photos),
            const SizedBox(height: DonySpacing.md),
          ],
          InfoRow(label: l.requestCreateRecapPackage, value: _colisLabel),
          if (bid.description != null && bid.description!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(label: l.requestDescriptionLabel, value: bid.description!),
          ],
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: l.requestCreateRecipientSection,
            value: bid.recipientName ?? '-',
          ),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: l.requestCreateRecipientPhoneLabel,
            value: bid.recipientPhone ?? '-',
          ),
        ],
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
