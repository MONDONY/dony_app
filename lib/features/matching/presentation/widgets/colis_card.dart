import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';

class ColisCard extends StatelessWidget {
  final BidModel bid;
  const ColisCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Colis',
      child: Column(
        children: [
          InfoRow(label: 'Catégorie', value: bid.contentCategory ?? '-'),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: 'Description', value: bid.description ?? '-'),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: 'Poids', value: bid.weightKg != null ? '${bid.weightKg} kg' : '-'),
        ],
      ),
    );
  }
}
