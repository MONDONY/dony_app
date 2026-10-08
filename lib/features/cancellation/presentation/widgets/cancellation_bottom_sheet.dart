import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/cancellation_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Motifs envoyés au serveur et comparés tels quels (_finalReason) : valeur de
// donnée, jamais traduite. Seul l'affichage passe par cancellationReasonLabel.
const _reasons = [
  'Vol annulé', // i18n-ignore
  'Urgence personnelle', // i18n-ignore
  'Problème de santé', // i18n-ignore
  "Changement d'itinéraire", // i18n-ignore
  'Autre', // i18n-ignore
];

/// Annulation du trajet par le voyageur : motif, puis confirmation.
///
/// La feuille se ferme avant l'envoi de l'annulation : c'est l'écran du
/// trajet qui écoute le [CancellationBloc] (snackbar et rechargement). Un
/// écouteur posé ici ne recevait jamais le succès, d'où un trajet affiché
/// inchangé après une annulation réussie (FLUTTER-FH).
class CancellationBottomSheet extends StatefulWidget {
  const CancellationBottomSheet({
    super.key,
    required this.announcementId,
    this.handedOverParcels = 0,
    this.onSubmitReady,
  });

  final String announcementId;

  /// Colis déjà remis au voyageur (HANDED_OVER, IN_TRANSIT, ARRIVED) : leur
  /// retour s'ouvre à l'annulation, la feuille et la confirmation le disent.
  final int handedOverParcels;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(
    BuildContext context, {
    required String announcementId,
    int handedOverParcels = 0,
  }) {
    final cancellationBloc = context.read<CancellationBloc>();
    final l = context.l10n;
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: l.cancellationConfirmTitle,
      subtitle: l.cancellationIrreversibleSubtitle,
      wrapper: (child) =>
          BlocProvider.value(value: cancellationBloc, child: child),
      stickyBottom: BlocBuilder<CancellationBloc, CancellationState>(
        builder: (ctx, state) => DonyButton(
          label: l.cancellationConfirmAction,
          variant: DonyButtonVariant.destructive,
          isLoading: state is CancellationLoading,
          onPressed: state is CancellationLoading ? null : () => submit?.call(),
        ),
      ),
      child: CancellationBottomSheet(
        announcementId: announcementId,
        handedOverParcels: handedOverParcels,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<CancellationBottomSheet> createState() =>
      _CancellationBottomSheetState();
}

class _CancellationBottomSheetState extends State<CancellationBottomSheet> {
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_confirm);
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_selectedReason == null) {
      return null;
    }
    if (_selectedReason == 'Autre' && // i18n-ignore
        _otherCtrl.text.trim().isNotEmpty) {
      return _otherCtrl.text.trim();
    }
    if (_selectedReason == 'Autre') {
      return null; // require text when "Autre"
    }
    return _selectedReason;
  }

  void _confirm() {
    final l = context.l10n;
    final reason = _finalReason;
    if (reason == null) {
      DonySnackbar.show(
        context,
        message: _selectedReason == null
            ? l.cancellationSelectReasonError
            : l.cancellationSpecifyReasonError,
        type: DonySnackbarType.error,
      );
      return;
    }
    final bloc = context.read<CancellationBloc>();
    Navigator.of(context, rootNavigator: true).pop();
    DonyDialog.show(
      context,
      title: l.cancellationConfirmAction,
      message: widget.handedOverParcels > 0
          ? l.cancellationConfirmDialogMessageWithReturns(
              widget.handedOverParcels,
            )
          : l.cancellationConfirmDialogMessage,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'triangle-alert',
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(
          CancellationTripRequested(
            announcementId: widget.announcementId,
            reason: reason,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              DonyIcon('triangle-alert', color: cs.error, size: 18),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  l.cancellationAutoRefundNotice,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        if (widget.handedOverParcels > 0) ...[
          const SizedBox(height: DonySpacing.sm),
          Container(
            key: const Key('cancellation-handed-over-notice'),
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('package', color: cs.onSurfaceVariant, size: 18),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.cancellationHandedOverParcelsNotice(
                      widget.handedOverParcels,
                    ),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: DonySpacing.base),

        // Radio group label
        Text(l.cancellationReasonFieldLabel, style: tt.titleSmall),
        const SizedBox(height: DonySpacing.sm),

        // Radio options
        DonyRadioGroup<String>(
          value: _selectedReason,
          onChanged: (v) => setState(() => _selectedReason = v),
          options: _reasons
              .map(
                (r) => DonyRadioOption(
                  value: r,
                  label: cancellationReasonLabel(l, r),
                ),
              )
              .toList(),
        ),

        // "Autre" text field
        if (_selectedReason == 'Autre') ...[
          const SizedBox(height: DonySpacing.md),
          DonyTextField(
            controller: _otherCtrl,
            label: l.cancellationSpecifyLabel,
            hint: l.cancellationSpecifyHint,
          ),
        ],

        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}
