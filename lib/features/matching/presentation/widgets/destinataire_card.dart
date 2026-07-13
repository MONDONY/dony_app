import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';

class DestinataireCard extends StatelessWidget {
  final BidModel bid;
  const DestinataireCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Destinataire',
      child: Column(
        children: [
          InfoRow(label: 'Nom', value: bid.recipientName ?? '-'),
          const SizedBox(height: DonySpacing.sm),
          InfoRow(label: 'Téléphone', value: bid.recipientPhone ?? '-'),
        ],
      ),
    );
  }
}
