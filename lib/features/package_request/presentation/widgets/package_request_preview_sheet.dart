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
    bool isSubmitting = false,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Aperçu de ta demande',
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('preview-publish'),
            label: 'Publier ma demande',
            onPressed: isSubmitting ? null : onConfirm,
            isLoading: isSubmitting,
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('preview-save-draft'),
              label: 'Enregistrer en brouillon',
              variant: DonyButtonVariant.secondary,
              onPressed: isSubmitting ? null : onSaveDraft,
            ),
          ],
        ],
      ),
      child: _PreviewBody(formState: formState),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.formState});
  final PackageRequestFormState formState;

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
            '${DateFormat('d MMMM', 'fr').format(s.desiredDate!)} '
            '±${s.dateToleranceDays ?? 0}j · ${s.weightKg?.toStringAsFixed(0) ?? '?'} kg',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        if (s.categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            s.categories.join(', '),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DonySpacing.base),
        Text(
          s.negotiable
              ? (s.totalBudgetEur != null
                  ? 'Budget indicatif : ${s.totalBudgetEur!.toStringAsFixed(0)} €'
                  : 'Ouvert aux offres')
              : 'Prix ferme : ${s.totalBudgetEur?.toStringAsFixed(0) ?? '?'} €',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
