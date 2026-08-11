import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementPreviewSheet extends StatelessWidget {
  final AnnouncementFormState formState;
  final VoidCallback onConfirm;
  final bool isSubmitting;
  final TimeOfDay? departureTime;
  final SupportedCurrency? currency;

  const AnnouncementPreviewSheet({
    super.key,
    required this.formState,
    required this.onConfirm,
    this.isSubmitting = false,
    this.departureTime,
    this.currency,
  });

  static Future<void> show(
    BuildContext context, {
    required AnnouncementFormState formState,
    required VoidCallback onConfirm,
    VoidCallback? onSaveDraft,
    bool isSubmitting = false,
    TimeOfDay? departureTime,
    SupportedCurrency? currency,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Aperçu de votre annonce',
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Publier l\'annonce',
            onPressed: isSubmitting ? null : onConfirm,
            isLoading: isSubmitting,
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: 'Enregistrer comme brouillon',
              variant: DonyButtonVariant.secondary,
              onPressed: isSubmitting ? null : onSaveDraft,
            ),
          ],
        ],
      ),
      child: AnnouncementPreviewSheet(
        formState: formState,
        onConfirm: onConfirm,
        isSubmitting: isSubmitting,
        departureTime: departureTime,
        currency: currency,
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
        : '-';

    // Le voyageur touche le prix net qu'il fixe ; la commission Yadony est en sus
    // (payée par l'expéditeur). Pas de décote ×0,88 sur ce qu'il reçoit.
    final netEstimate = (formState.pricePerKg != null &&
            formState.availableKg != null)
        ? (formState.pricePerKg! * formState.availableKg!)
        : null;

    final prixStr = formState.pricePerKg != null
        ? '${CurrencyFormatter.formatOrPlain(formState.pricePerKg!, currency)}/kg'
            '${netEstimate != null ? ' · estimation ${CurrencyFormatter.formatOrPlain(netEstimate, currency)} net' : ''}'
        : '-';

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewRow(
            iconAsset: 'plane-takeoff',
            label: 'Trajet',
            value:
                '${formState.departureCity ?? '-'} → ${formState.arrivalCity ?? '-'}',
          ),
          _PreviewRow(
            iconAsset: 'calendar',
            label: 'Date',
            value: dateStr,
          ),
          if (departureTime != null)
            _PreviewRow(
              iconAsset: 'clock',
              label: 'Départ',
              value: _formatTime(departureTime!),
            ),
          if (formState.pickupAddress != null)
            _PreviewRow(
              iconAsset: 'arrow-left-right',
              label: 'Remise',
              value: formState.pickupAddress!.label,
            ),
          if (formState.deliveryAddress != null)
            _PreviewRow(
              iconAsset: 'arrow-left-right',
              label: 'Récupération',
              value: formState.deliveryAddress!.label,
            ),
          _PreviewRow(
            iconAsset: 'luggage',
            label: 'Capacité',
            value: formState.capacityUnit.label,
          ),
          _PreviewRow(
            iconAsset: 'banknote',
            label: 'Prix',
            value: prixStr,
          ),
          _PreviewRow(
            iconAsset: 'banknote',
            label: 'Paiement',
            value: formState.cashAccepted
                ? 'Carte + Espèces'
                : 'Carte uniquement',
          ),
          if (formState.acceptedTypes.isNotEmpty)
            _PreviewRow(
              iconAsset: 'circle-check',
              label: 'Accepte',
              value: formState.acceptedTypes.join(', '),
            ),
          if (formState.rejectedTypes.isNotEmpty)
            _PreviewRow(
              iconAsset: 'circle-x',
              label: 'Refuse',
              value: formState.rejectedTypes.join(', '),
            ),
          if (formState.description != null &&
              formState.description!.isNotEmpty)
            _PreviewRow(
              iconAsset: 'file-text',
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
                  DonyIcon('triangle-alert',
                      color: cs.warning, size: 16),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      formState.priceWarning == PriceWarning.tooLow
                          ? 'Prix bas. Vous pourrez le modifier après publication.'
                          : 'Prix élevé. Vous pourrez le modifier après publication.',
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
  final String iconAsset;
  final String label;
  final String value;

  const _PreviewRow({
    required this.iconAsset,
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
          DonyIcon(iconAsset, size: 18, color: cs.primary),
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
