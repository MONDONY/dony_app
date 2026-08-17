import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sheet d'aperçu de l'étape 3 du wizard de demande d'envoi — miroir de
/// `AnnouncementPreviewSheet`. Deux sorties : publication immédiate ou
/// enregistrement en brouillon (proposé seulement si [onSaveDraft] est fourni).
abstract final class PackageRequestPreviewSheet {
  static Future<void> show(
    BuildContext context, {
    required PackageRequestFormState formState,
    required VoidCallback onConfirm,
    VoidCallback? onSaveDraft,
    SupportedCurrency? currency,
    // Compté par l'appelant : la sheet s'ouvre sur le navigator racine et n'a
    // donc pas accès aux providers du wizard.
    int photoCount = 0,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Aperçu de votre demande',
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('preview-publish'),
            label: 'Publier ma demande',
            onPressed: onConfirm,
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('preview-save-draft'),
              label: 'Enregistrer en brouillon',
              variant: DonyButtonVariant.secondary,
              onPressed: onSaveDraft,
            ),
          ],
        ],
      ),
      child: _PreviewBody(
        formState: formState,
        currency: currency,
        photoCount: photoCount,
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.formState,
    required this.currency,
    required this.photoCount,
  });

  final PackageRequestFormState formState;
  final SupportedCurrency? currency;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = formState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.departureCity} → ${s.arrivalCity}',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DonySpacing.xs),
        if (s.desiredDate != null)
          Text(
            _dateLine(s),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: DonySpacing.base),

        // L'aperçu s'arrêtait au corridor, à la date et au prix : l'expéditeur
        // validait sans voir le contenu, les photos, le lieu de remise ni les
        // modes de paiement, c'est-à-dire l'essentiel de ce que lit le voyageur.
        if (s.categories.isNotEmpty)
          _Row(label: 'Contenu', value: s.categories.join(', ')),
        if (s.weightKg != null) _Row(label: 'Poids', value: _weightLabel(s)),
        if (photoCount > 0)
          _Row(
            label: 'Photos',
            value: photoCount == 1 ? '1 photo' : '$photoCount photos',
          ),
        if (s.pickupNeighborhood != null &&
            s.pickupNeighborhood!.trim().isNotEmpty)
          _Row(label: 'Remise', value: s.pickupNeighborhood!.trim()),
        if (s.description != null && s.description!.trim().isNotEmpty)
          _Row(label: 'Description', value: s.description!.trim()),
        _Row(label: 'Paiement', value: _paymentLabel(s)),

        const SizedBox(height: DonySpacing.base),
        Text(
          _priceLine(s),
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  /// Poids au dixième près. `toStringAsFixed(0)` affichait « 2 kg » pour
  /// 2,5 kg, en désaccord avec le récap de l'étape 3 juste au-dessus.
  String _weightLabel(PackageRequestFormState s) {
    final w = s.weightKg!;
    return '${w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)} kg';
  }

  String _dateLine(PackageRequestFormState s) {
    final date = DateFormat('d MMMM y', 'fr_FR').format(s.desiredDate!);
    final tol = s.dateToleranceDays ?? 0;
    return tol == 0 ? date : '$date ±${tol}j';
  }

  String _paymentLabel(PackageRequestFormState s) => s.acceptedPaymentMethods
      .map((m) => m.displayLabel)
      .join(', ');

  String _priceLine(PackageRequestFormState s) {
    final amount = s.totalBudgetEur;
    if (s.negotiable) {
      return amount == null
          ? 'Ouvert aux offres'
          : 'Budget indicatif : '
                '${CurrencyFormatter.formatOrPlain(amount, currency)}';
    }
    return amount == null
        ? 'Prix ferme'
        : 'Prix ferme : ${CurrencyFormatter.formatOrPlain(amount, currency)}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
