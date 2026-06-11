import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
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
    return parts.isNotEmpty ? parts.join(' · ') : '—';
  }

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Colis & destinataire',
      child: Column(
        children: [
          InfoRow(label: 'Colis', value: _colisLabel),
          if (bid.description != null && bid.description!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(label: 'Description', value: bid.description!),
          ],
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: 'Valeur déclarée',
            value: bid.declaredValueEur != null
                ? '${bid.declaredValueEur!.toStringAsFixed(2)} €'
                : '— (à compléter)',
          ),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: 'Destinataire', value: bid.recipientName ?? '—'),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: 'Téléphone', value: bid.recipientPhone ?? '—'),
        ],
      ),
    );
  }
}
