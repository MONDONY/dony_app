import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementPreviewSheet extends StatelessWidget {
  final AnnouncementFormState formState;
  final VoidCallback onConfirm;
  final bool isSubmitting;
  final TimeOfDay? departureTime;

  const AnnouncementPreviewSheet({
    super.key,
    required this.formState,
    required this.onConfirm,
    this.isSubmitting = false,
    this.departureTime,
  });

  static Future<void> show(
    BuildContext context, {
    required AnnouncementFormState formState,
    required VoidCallback onConfirm,
    bool isSubmitting = false,
    TimeOfDay? departureTime,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Aperçu de votre annonce',
      stickyBottom: DonyButton(
        label: 'Publier l\'annonce',
        onPressed: isSubmitting ? null : onConfirm,
        isLoading: isSubmitting,
      ),
      child: AnnouncementPreviewSheet(
        formState: formState,
        onConfirm: onConfirm,
        isSubmitting: isSubmitting,
        departureTime: departureTime,
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final dateStr = formState.departureDate != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(formState.departureDate!)
        : '—';

    final netEstimate = (formState.pricePerKg != null &&
            formState.availableKg != null)
        ? (formState.pricePerKg! * formState.availableKg! * 0.88)
        : null;

    final prixStr = formState.pricePerKg != null
        ? '${formState.pricePerKg!.toStringAsFixed(0)} €/kg'
            '${netEstimate != null ? ' · estimation ${netEstimate.toStringAsFixed(0)}€ net' : ''}'
        : '—';

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewRow(
            icon: Icons.flight_takeoff,
            label: 'Trajet',
            value:
                '${formState.departureCity ?? '—'} → ${formState.arrivalCity ?? '—'}',
          ),
          _PreviewRow(
            icon: Icons.calendar_today,
            label: 'Date',
            value: dateStr,
          ),
          if (departureTime != null)
            _PreviewRow(
              icon: Icons.schedule_rounded,
              label: 'Départ',
              value: _formatTime(departureTime!),
            ),
          if (formState.pickupAddress != null)
            _PreviewRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Remise',
              value: formState.pickupAddress!.label,
            ),
          if (formState.deliveryAddress != null)
            _PreviewRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Récupération',
              value: formState.deliveryAddress!.label,
            ),
          _PreviewRow(
            icon: Icons.luggage,
            label: 'Capacité',
            value: formState.capacityUnit.label,
          ),
          _PreviewRow(
            icon: Icons.euro,
            label: 'Prix',
            value: prixStr,
          ),
          _PreviewRow(
            icon: Icons.payments_rounded,
            label: 'Paiement',
            value: formState.cashAccepted
                ? 'Carte + Espèces'
                : 'Carte uniquement',
          ),
          if (formState.acceptedTypes.isNotEmpty)
            _PreviewRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Accepte',
              value: formState.acceptedTypes.join(', '),
            ),
          if (formState.rejectedTypes.isNotEmpty)
            _PreviewRow(
              icon: Icons.cancel_outlined,
              label: 'Refuse',
              value: formState.rejectedTypes.join(', '),
            ),
          if (formState.description != null &&
              formState.description!.isNotEmpty)
            _PreviewRow(
              icon: Icons.notes,
              label: 'Note',
              value: formState.description!,
            ),
          if (formState.priceWarning != null)
            Container(
              margin: const EdgeInsets.only(top: DonySpacing.sm),
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: cs.warningLight,
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: cs.warning, size: 16),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      formState.priceWarning == PriceWarning.tooLow
                          ? 'Prix bas — vous pourrez le modifier après publication'
                          : 'Prix élevé — vous pourrez le modifier après publication',
                      style: tt.bodySmall?.copyWith(color: cs.warning),
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

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: tt.bodyMedium),
          ),
        ],
      ),
    );
  }
}
