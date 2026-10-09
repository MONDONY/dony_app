import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_photo_viewer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Fiche détaillée du colis d'un fil de négociation (FLUTTER-G9) : catégorie,
/// poids, articles de la grille, photos et description.
///
/// Lecture seule, sans bouton : la feuille se ferme d'un glissement. Les
/// photos s'ouvrent en plein écran, comme depuis le récapitulatif du fil.
abstract final class BidNegotiationParcelSheet {
  static Future<void> show(
    BuildContext context, {
    required BidNegotiation negotiation,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: context.l10n.negotiationThreadParcelSectionTitle,
      child: _ParcelDetails(negotiation: negotiation),
    );
  }
}

/// Poids lisible, sans décimale inutile (« 5 kg », « 2,5 kg »).
String negotiationParcelWeightLabel(double weight) =>
    '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg';

class _ParcelDetails extends StatelessWidget {
  const _ParcelDetails({required this.negotiation});

  final BidNegotiation negotiation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final category = negotiation.contentCategory;
    final weight = negotiation.weightKg;
    final description = negotiation.description;
    final hasItems =
        negotiation.gridItems.isNotEmpty || negotiation.customItems.isNotEmpty;

    return Column(
      key: const Key('nego-parcel-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (category != null && category.isNotEmpty)
          DonyInfoRow(
            label: l.negotiationParcelSheetCategory,
            value: contentCategoriesDisplayName(l, category),
          ),
        if (weight != null && weight > 0)
          DonyInfoRow(
            label: l.negotiationParcelSheetWeight,
            value: negotiationParcelWeightLabel(weight),
          ),
        if (hasItems) ...[
          const SizedBox(height: DonySpacing.base),
          _SectionTitle(l.negotiationParcelSheetItems),
          for (final line in negotiation.gridItems)
            DonyInfoRow(
              label: line.label,
              value:
                  '${line.quantity} × ${formatPriceIn(line.unitPriceDisplayEur, negotiation.currency)}',
            ),
          for (final item in negotiation.customItems)
            DonyInfoRow(
              label: item.label,
              value:
                  '${item.quantity} × ${formatPriceIn(item.amountEur, negotiation.currency)}',
            ),
        ],
        if (negotiation.photoUrls.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          _SectionTitle(l.negotiationParcelSheetPhotos),
          const SizedBox(height: DonySpacing.sm),
          NegotiationParcelPhotoStrip(
            urls: negotiation.photoUrls,
            size: 96,
            keyPrefix: 'nego-sheet-photo',
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          _SectionTitle(l.negotiationParcelSheetDescription),
          const SizedBox(height: DonySpacing.xs),
          Text(
            description,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
        ],
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: tt.titleSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Vignettes des photos du colis, chacune ouvrant la galerie plein écran à sa
/// position. Partagée par le récapitulatif du fil et la fiche du colis.
class NegotiationParcelPhotoStrip extends StatelessWidget {
  const NegotiationParcelPhotoStrip({
    super.key,
    required this.urls,
    this.size = 72,
    this.keyPrefix = 'nego-photo',
  });

  final List<String> urls;
  final double size;

  /// Préfixe des clés de vignette (`<prefix>-<index>`), stable pour les tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: DonySpacing.sm),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: l.negotiationParcelPhotoSemantics(i + 1),
          child: DonyPressable(
            key: Key('$keyPrefix-$i'),
            onTap: () =>
                RequestPhotoViewer.show(context, urls: urls, initialIndex: i),
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                // Liseré neutre : la photo garde un bord net sur n'importe
                // quel fond (noir en clair, blanc en sombre).
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                child: DonyImage(url: urls[i], width: size, height: size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
