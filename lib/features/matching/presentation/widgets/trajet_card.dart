import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte affichant les détails du trajet (date de départ, heure, tarif/kg).
///
/// Correspond à l'ancienne classe privée `_TripDetailsCard` de
/// `bid_detail_screen.dart`.
///
/// NOTE sur le format de date : [DateFormat] avec locale 'fr' nécessite que
/// les données de locale soient initialisées
/// ([intl.initializeDateFormatting]). Si elles ne le sont pas (ex : tests
/// unitaires isolés), le widget retombe sur un format numérique
/// non-localisé ("d/M") qui ne lève aucune exception.
class TrajetCard extends StatelessWidget {
  final BidModel bid;

  const TrajetCard({super.key, required this.bid});

  String _formatDate(DateTime? d) {
    if (d == null) {
      return '—';
    }
    try {
      return DateFormat('EEE dd MMM yyyy', 'fr').format(d);
    } catch (_) {
      // Locale data not initialized — use numeric fallback.
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) {
      return '—';
    }
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Détails du trajet',
      child: Column(
        children: [
          InfoRow(
            label: 'Date de départ',
            value: _formatDate(bid.departureDate),
          ),
          if (bid.departureTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Heure de départ',
              value: _formatTime(bid.departureTime),
            ),
          ],
          if (bid.arrivalTime != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Heure d\'arrivée',
              value: _formatTime(bid.arrivalTime),
            ),
          ],
          if (bid.pricePerKg != null && bid.pricePerKg! > 0) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              // Carte visible uniquement par l'expéditeur (bid_detail_screen) :
              // on affiche le prix au kilo commission incluse (net × 1,12).
              label: 'Tarif par kg',
              value: '${formatKgPrice(netToSenderPrice(bid.pricePerKg!))} €',
            ),
          ],
        ],
      ),
    );
  }
}
