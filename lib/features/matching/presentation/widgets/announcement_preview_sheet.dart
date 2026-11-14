import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementPreviewSheet extends StatelessWidget {
  final AnnouncementFormState formState;
  final VoidCallback onConfirm;
  final bool isSubmitting;
  final TimeOfDay? departureTime;
  final SupportedCurrency? currency;

  /// Moyens de paiement tels qu'envoyés au submit (`STRIPE`, `CASH`,
  /// `MOBILE_MONEY`). Null : repli sur `formState.cashAccepted`.
  final List<String>? paymentMethods;

  /// « Modifier » de la ligne Devise (FLUTTER-NN) : ramène au sélecteur de
  /// devise du formulaire. Null : ligne sans lien (devise figée).
  final VoidCallback? onChangeCurrency;

  /// Bateau : arrivée estimée au plus tôt et au plus tard (jours sans heure).
  /// Null hors bateau ou tant qu'elle n'est pas saisie : pas de ligne.
  final DateTime? arrivalMin;
  final DateTime? arrivalMax;

  /// Date limite de dépôt telle qu'elle partira au serveur. Null : non
  /// saisie, pas de ligne.
  final DateTime? handoverDeadline;

  const AnnouncementPreviewSheet({
    super.key,
    required this.formState,
    required this.onConfirm,
    this.isSubmitting = false,
    this.departureTime,
    this.currency,
    this.paymentMethods,
    this.onChangeCurrency,
    this.arrivalMin,
    this.arrivalMax,
    this.handoverDeadline,
  });

  static Future<void> show(
    BuildContext context, {
    required AnnouncementFormState formState,
    required VoidCallback onConfirm,
    VoidCallback? onSaveDraft,
    bool isSubmitting = false,
    TimeOfDay? departureTime,
    SupportedCurrency? currency,
    List<String>? paymentMethods,
    VoidCallback? onChangeCurrency,
    DateTime? arrivalMin,
    DateTime? arrivalMax,
    DateTime? handoverDeadline,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<void>(
      context,
      title: l.listingPreviewTitle,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: l.listingPublishButton,
            onPressed: isSubmitting ? null : onConfirm,
            isLoading: isSubmitting,
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: l.listingSaveDraftButton,
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
        paymentMethods: paymentMethods,
        onChangeCurrency: onChangeCurrency,
        arrivalMin: arrivalMin,
        arrivalMax: arrivalMax,
        handoverDeadline: handoverDeadline,
      ),
    );
  }

  /// Arrivée estimée du bateau (« 28 nov. au 15 déc. », ou un seul jour).
  static String arrivalLabel(
    AppLocalizations l,
    DateTime from,
    DateTime? to, {
    DateTime? now,
  }) {
    final days = arrivalRangeDays(l, from, to, now: now);
    final end = days.to;
    return end == null ? days.from : l.ticketArrivalRangeValue(days.from, end);
  }

  /// Date limite de dépôt, jour et heure (« 16 nov. à 20:00 »).
  static String deadlineLabel(AppLocalizations l, DateTime deadline) =>
      l.commonDateAtTime(
        DateFormat.MMMd(l.localeName).format(deadline),
        DateFormat.jm(l.localeName).format(deadline),
      );

  /// Libellé « Paiement » de l'aperçu (FLUTTER-GJ) : calculé depuis la liste
  /// réellement envoyée, donc juste en XOF (pas de carte), carte décochée ou
  /// mobile money activé.
  static String paymentLabel(AppLocalizations l, List<String> methods) {
    return [
      if (methods.contains('STRIPE')) l.paymentMethodCard,
      if (methods.contains('CASH')) l.paymentMethodCash,
      if (methods.contains('MOBILE_MONEY')) l.paymentMethodMobileMoney,
    ].join(' + ');
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
    final l = context.l10n;

    // fr : garde le zéro de tête du motif d'origine (« 06 oct. 2026 ») ;
    // le squelette yMMMd le retire (« 6 oct. 2026 »). en : squelette yMMMd.
    final dateStr = formState.departureDate != null
        ? (l.localeName == 'fr'
              ? DateFormat('dd MMM yyyy', 'fr').format(formState.departureDate!)
              : DateFormat.yMMMd(l.localeName).format(formState.departureDate!))
        : '-';

    // Le voyageur touche le prix net qu'il fixe ; la commission Yadony est en sus
    // (payée par l'expéditeur). Pas de décote ×0,88 sur ce qu'il reçoit.
    final netEstimate =
        (formState.pricePerKg != null && formState.availableKg != null)
        ? (formState.pricePerKg! * formState.availableKg!)
        : null;

    final kgPrixStr = formState.pricePerKg != null
        ? '${CurrencyFormatter.formatOrPlain(formState.pricePerKg!, currency)}/kg'
              '${netEstimate != null ? l.listingPriceEstimateSuffix(CurrencyFormatter.formatOrPlain(netEstimate, currency)) : ''}'
        : '-';
    // Bateau au m³ : ni kilos ni prix au kilo, le volume et le prix au m³.
    final perM3 = formState.isPricedPerM3;
    final volume = formState.volumeCapacityM3;
    final pricePerM3 = formState.pricePerM3;
    final prixStr = !perM3
        ? kgPrixStr
        : pricePerM3 == null
        ? '-'
        : l.tripPublishPerM3Value(
            CurrencyFormatter.formatOrPlain(pricePerM3, currency),
          );
    // Capacité personnalisée : les kilos saisis (« 1 500 kg »), jamais le nom
    // de l'unité « Personnalisé », qui ne dit rien à l'expéditeur.
    final customKg = formState.capacityUnit == CapacityUnit.custom
        ? formState.availableKg
        : null;
    final capacityStr = !perM3
        ? (customKg != null
              ? formatWeightKg(l, customKg)
              : formState.capacityUnit.label(l))
        : volume == null
        ? '-'
        : formatVolumeM3(l, volume);

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Devise en tête du récapitulatif (FLUTTER-NN, après FLUTTER-GK) :
          // découverte trop tard, elle se vérifie avant tout le reste.
          if (currency case final c?) ...[
            _CurrencyRecap(currency: c, onChange: onChangeCurrency),
            const SizedBox(height: DonySpacing.sm),
          ],
          _PreviewRow(
            iconAsset: transportModeOrPlane(formState.transportMode).iconAsset,
            label: l.listingHeroTripLabel,
            value:
                '${formState.departureCity ?? '-'} → ${formState.arrivalCity ?? '-'}',
          ),
          _PreviewRow(
            iconAsset: 'calendar',
            label: l.listingRowLabelDate,
            value: dateStr,
          ),
          if (departureTime != null)
            _PreviewRow(
              iconAsset: 'clock',
              label: l.listingPreviewDepartureLabel,
              value: _formatTime(departureTime!),
            ),
          if (arrivalMin case final from?)
            _PreviewRow(
              key: const Key('preview-arrival-range'),
              iconAsset: 'calendar',
              label: l.ticketEstimatedArrivalLabel,
              value: arrivalLabel(l, from, arrivalMax),
            ),
          if (handoverDeadline case final deadline?)
            _PreviewRow(
              key: const Key('preview-handover-deadline'),
              iconAsset: 'clock',
              label: l.tripPublishHandoverDeadlineLabel,
              value: deadlineLabel(l, deadline),
            ),
          if (formState.pickupAddress != null)
            _PreviewRow(
              iconAsset: 'arrow-left-right',
              label: l.listingRowLabelPickup,
              value: formState.pickupAddress!.label,
            ),
          if (formState.deliveryAddress != null)
            _PreviewRow(
              iconAsset: 'arrow-left-right',
              label: l.listingDeliveryPickupTitle,
              value: formState.deliveryAddress!.label,
            ),
          _PreviewRow(
            // Pas de valise hors avion : le colis.
            iconAsset: transportModeOrPlane(formState.transportMode).isHeavy
                ? 'package'
                : 'luggage',
            label: l.listingRowLabelCapacity,
            value: capacityStr,
          ),
          _PreviewRow(
            iconAsset: 'banknote',
            label: l.listingRowLabelPrice,
            value: prixStr,
          ),
          _PreviewRow(
            iconAsset: 'banknote',
            label: l.listingRowLabelPayment,
            value: paymentMethods != null && paymentMethods!.isNotEmpty
                ? paymentLabel(l, paymentMethods!)
                : formState.cashAccepted
                ? l.listingPaymentCardCash
                : l.listingPaymentCardOnly,
          ),
          if (formState.acceptedTypes.isNotEmpty)
            _PreviewRow(
              iconAsset: 'circle-check',
              label: l.listingRowLabelAccept,
              value: formState.acceptedTypes
                  .map((t) => contentCategoryDisplayName(l, t))
                  .join(', '),
            ),
          if (formState.rejectedTypes.isNotEmpty)
            _PreviewRow(
              iconAsset: 'circle-x',
              label: l.listingRowLabelRefuse,
              value: formState.rejectedTypes
                  .map((t) => contentCategoryDisplayName(l, t))
                  .join(', '),
            ),
          if (formState.description != null &&
              formState.description!.isNotEmpty)
            _PreviewRow(
              iconAsset: 'file-text',
              label: l.listingRowLabelNote,
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
                  DonyIcon('triangle-alert', color: cs.warning, size: 16),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      formState.priceWarning == PriceWarning.tooLow
                          ? l.listingPriceTooLowWarning
                          : l.listingPriceTooHighWarning,
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

/// Ligne « Devise : Franc CFA Ouest (XOF) » mise en avant, avec « Modifier »
/// quand la devise peut encore changer (création d'un trajet).
class _CurrencyRecap extends StatelessWidget {
  const _CurrencyRecap({required this.currency, this.onChange});

  final SupportedCurrency currency;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      key: const Key('preview-currency-row'),
      padding: const EdgeInsets.only(
        left: DonySpacing.md,
        top: DonySpacing.xs,
        bottom: DonySpacing.xs,
        right: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.infoLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.info.withValues(alpha: 0.35)),
      ),
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          DonyIcon('wallet', size: 18, color: cs.info),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.listingPreviewCurrencyValue(currency.name(l), currency.code),
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onChange != null)
            TextButton(
              key: const Key('preview-currency-change'),
              onPressed: onChange,
              child: Text(l.commonEdit),
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
    super.key,
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
          Expanded(child: Text(value, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}
