import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';

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
    final pickup = s.pickupNeighborhood?.trim() ?? '';
    final description = s.description?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.departureCity} → ${s.arrivalCity}',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (s.desiredDate != null) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            formatDesiredDate(s.desiredDate, s.dateToleranceDays, long: true),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DonySpacing.base),

        // L'aperçu s'arrêtait au corridor, à la date et au prix : l'expéditeur
        // validait sans voir le contenu, les photos, le lieu de remise ni les
        // modes de paiement, c'est-à-dire l'essentiel de ce que lit le voyageur.
        if (s.categories.isNotEmpty)
          DonyInfoRow(label: 'Contenu', value: s.categories.join(', ')),
        if (s.weightKg != null)
          DonyInfoRow(label: 'Poids', value: formatWeightKg(s.weightKg!)),
        if (photoCount > 0)
          DonyInfoRow(
            label: 'Photos',
            value: photoCount == 1 ? '1 photo' : '$photoCount photos',
          ),
        if (pickup.isNotEmpty) DonyInfoRow(label: 'Remise', value: pickup),
        if (description.isNotEmpty)
          DonyInfoRow(
            label: 'Description',
            value: description,
            // Une description tient rarement sur une ligne, et la valeur d'une
            // DonyInfoRow est tronquée par défaut.
            valueWidget: Text(
              description,
              textAlign: TextAlign.end,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
        DonyInfoRow(label: 'Paiement', value: _paymentLabel(s)),

        const SizedBox(height: DonySpacing.base),
        Text(
          _priceLine(s),
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  /// Ordre canonique (carte, espèces, mobile money), et non l'ordre de cochage
  /// du `Set` : l'aperçu annonçait « Espèces, Carte » là où les chips de
  /// l'étape 3 et la fiche lue par le voyageur affichent « Carte, Espèces ».
  String _paymentLabel(PackageRequestFormState s) => PaymentMethod
      .canonicalOrder
      .where(s.acceptedPaymentMethods.contains)
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
