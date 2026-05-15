import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:flutter/material.dart';

/// Bottom sheet affichant les détails complets du trajet lié à une négociation.
///
/// - Si [isSender] est `true`, un bouton destructif "Refuser ce trajet" est
///   affiché en [stickyBottom] et [onRefuse] est appelé après fermeture.
/// - Sinon, la sheet est en lecture seule (voyageur consulte ses propres infos).
class TripDetailBottomSheet extends StatelessWidget {
  const TripDetailBottomSheet({
    required this.trip,
    required this.isSender,
    this.onRefuse,
    super.key,
  });

  final LinkedTripSummary trip;
  final bool isSender;
  final VoidCallback? onRefuse;

  static void show(
    BuildContext context, {
    required LinkedTripSummary trip,
    required bool isSender,
    VoidCallback? onRefuse,
  }) {
    DonyBottomSheet.show(
      context,
      title: 'Trajet lié',
      stickyBottom: isSender
          ? DonyButton(
              label: 'Refuser ce trajet',
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                onRefuse?.call();
              },
            )
          : null,
      child: TripDetailBottomSheet(
        trip: trip,
        isSender: isSender,
        onRefuse: onRefuse,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoRow(
          icon: _iconForMode(trip.transportMode),
          label: 'Itinéraire',
          value: '${trip.departureCity} → ${trip.arrivalCity}',
        ),
        if (trip.departureDate != null)
          _InfoRow(
            icon: '📅',
            label: 'Date de départ',
            value: _formatDate(trip.departureDate!),
          ),
        if (trip.departureTime != null)
          _InfoRow(
            icon: '🕐',
            label: 'Heure de départ',
            value: trip.departureTime!,
          ),
        _InfoRow(
          icon: '⚖️',
          label: 'Poids disponible',
          value: '${trip.availableKg} kg',
        ),
        if (trip.pickupAddressLabel != null)
          _InfoRow(
            icon: '📍',
            label: 'Adresse de remise',
            value: trip.pickupAddressLabel!,
          ),
        if (trip.deliveryAddressLabel != null)
          _InfoRow(
            icon: '🏠',
            label: 'Adresse de livraison',
            value: trip.deliveryAddressLabel!,
          ),
        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Note du voyageur',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            trip.description!,
            style: tt.bodyMedium,
          ),
        ],
      ],
    );
  }

  String _iconForMode(String? mode) {
    switch (mode) {
      case 'PLANE':
        return '✈️';
      case 'TRAIN':
        return '🚄';
      case 'CAR':
        return '🚗';
      default:
        return '📦';
    }
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        '', 'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
        'juil', 'août', 'sep', 'oct', 'nov', 'déc',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
