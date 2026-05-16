import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opens a confirmation bottom sheet asking the sender for a refusal reason.
/// Calls [onConfirm] with the (optional) reason when confirmed.
class _RefuseTripConfirmSheet extends StatefulWidget {
  const _RefuseTripConfirmSheet({
    required this.onConfirm,
    required this.reasonNotifier,
  });
  final void Function(String? reason) onConfirm;
  final ValueNotifier<String> reasonNotifier;

  static Future<void> show(
    BuildContext context, {
    required void Function(String? reason) onConfirm,
  }) {
    final reasonNotifier = ValueNotifier<String>('');
    return DonyBottomSheet.show(
      context,
      title: 'Refuser ce trajet',
      stickyBottom: ValueListenableBuilder<String>(
        valueListenable: reasonNotifier,
        builder: (_, reason, _) => DonyButton(
          label: 'Confirmer le refus',
          variant: DonyButtonVariant.destructive,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            onConfirm(reason.trim().isEmpty ? null : reason.trim());
          },
        ),
      ),
      child: _RefuseTripConfirmSheet(
        onConfirm: onConfirm,
        reasonNotifier: reasonNotifier,
      ),
    ).whenComplete(reasonNotifier.dispose);
  }

  @override
  State<_RefuseTripConfirmSheet> createState() =>
      _RefuseTripConfirmSheetState();
}

class _RefuseTripConfirmSheetState extends State<_RefuseTripConfirmSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: kError.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            border: Border.all(color: kError.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: kError, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  'Le voyageur devra proposer un autre trajet. Cette action est irréversible.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: kError,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Raison du refus (optionnel)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextSecondary,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        TextField(
          controller: _controller,
          onChanged: (v) => widget.reasonNotifier.value = v,
          maxLength: 280,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ex : date incorrecte, trajet annulé…',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: kTextHint,
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(DonySpacing.md),
            counterStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: kTextHint,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet affichant les détails complets du trajet lié à une négociation.
///
/// - Si [isSender] est `true`, un bouton destructif "Refuser ce trajet" est
///   affiché en [stickyBottom] ; il ouvre une confirmation avant d'appeler [onRefuse].
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
  final void Function(String? reason)? onRefuse;

  static void show(
    BuildContext context, {
    required LinkedTripSummary trip,
    required bool isSender,
    void Function(String? reason)? onRefuse,
  }) {
    DonyBottomSheet.show(
      context,
      title: 'Trajet lié',
      stickyBottom: isSender
          ? DonyButton(
              label: 'Refuser ce trajet',
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                // Close details sheet first, then open confirmation.
                Navigator.of(context, rootNavigator: true).pop();
                _RefuseTripConfirmSheet.show(
                  context,
                  onConfirm: (reason) => onRefuse?.call(reason),
                );
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
