import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/parcel_refusal/parcel_refusal_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_photo_picker.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Issue de la feuille « Refuser le colis ».
enum ParcelRefusalResult {
  /// Le serveur a passé le colis en PARCEL_REFUSED.
  refused,

  /// 409 : le trajet est parti entre-temps (erreur déjà affichée).
  conflict,
}

/// Libellé d'un motif, aussi envoyé au serveur en tête du motif de refus.
String parcelRefusalReasonLabel(
  AppLocalizations l,
  ParcelRefusalReason reason,
) => switch (reason) {
  ParcelRefusalReason.contentMismatch => l.parcelRefusalReasonContentMismatch,
  ParcelRefusalReason.overweight => l.parcelRefusalReasonOverweight,
  ParcelRefusalReason.prohibited => l.parcelRefusalReasonProhibited,
  ParcelRefusalReason.other => l.parcelRefusalReasonOther,
};

/// Ouvre la feuille « Refuser le colis » puis, si le refus aboutit ou se
/// heurte au départ du trajet, recharge le détail d'envoi ([BidBloc] de
/// l'écran, s'il est là). Un refus confirmé est annoncé d'une snackbar.
Future<void> openParcelRefusalSheet(BuildContext context, BidModel bid) async {
  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }
  final result = await ParcelRefusalSheet.show(context, bid: bid);
  if (result == null || !context.mounted) return;
  bidBloc?.add(BidDetailRequested(bid.id));
  if (result == ParcelRefusalResult.refused) {
    final l = context.l10n;
    DonySnackbar.show(
      context,
      message: bid.paymentMethod == BidPaymentMethod.cash
          ? l.parcelRefusalSuccessCash
          : l.parcelRefusalSuccess,
      type: DonySnackbarType.success,
    );
  }
}

/// Contenu de la feuille : rappel de la déclaration, motif, précisions,
/// photo obligatoire et conséquences du refus. Le formulaire vit dans
/// [ParcelRefusalCubit] ; le bouton « Refuser le colis » du `stickyBottom`
/// lit sa validité et soumet. Seul le contrôleur du champ texte vit ici.
class ParcelRefusalSheet extends StatefulWidget {
  const ParcelRefusalSheet({super.key, required this.bid});

  final BidModel bid;

  static Future<ParcelRefusalResult?> show(
    BuildContext context, {
    required BidModel bid,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<ParcelRefusalResult>(
      context,
      analyticsName: 'bid/refuse-parcel',
      title: l.parcelRefusalTitle,
      isDanger: true,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<ParcelRefusalCubit>(),
        child: child,
      ),
      stickyBottom: BlocBuilder<ParcelRefusalCubit, ParcelRefusalState>(
        builder: (ctx, state) => DonyButton(
          label: ctx.l10n.parcelRefusalSubmit,
          variant: DonyButtonVariant.destructive,
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit
              ? () => ctx.read<ParcelRefusalCubit>().submit(
                  bid,
                  reasonLabel: parcelRefusalReasonLabel(
                    ctx.l10n,
                    state.reason!,
                  ),
                )
              : null,
        ),
      ),
      child: ParcelRefusalSheet(bid: bid),
    );
  }

  @override
  State<ParcelRefusalSheet> createState() => _ParcelRefusalSheetState();
}

class _ParcelRefusalSheetState extends State<ParcelRefusalSheet> {
  final TextEditingController _detailsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detailsCtrl.addListener(_onDetailsChanged);
  }

  @override
  void dispose() {
    _detailsCtrl.removeListener(_onDetailsChanged);
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _onDetailsChanged() =>
      context.read<ParcelRefusalCubit>().detailsChanged(_detailsCtrl.text);

  void _onStateChanged(BuildContext context, ParcelRefusalState state) {
    switch (state.status) {
      case ParcelRefusalStatus.success:
        Navigator.of(context).pop(ParcelRefusalResult.refused);
      case ParcelRefusalStatus.conflict:
        ErrorPresenter.show(context, state.error);
        Navigator.of(context).pop(ParcelRefusalResult.conflict);
      case ParcelRefusalStatus.failure:
        ErrorPresenter.show(context, state.error);
      case ParcelRefusalStatus.photoFailed:
        DonySnackbar.show(
          context,
          message: context.l10n.parcelRefusalPhotoFailed,
          type: DonySnackbarType.error,
        );
      case ParcelRefusalStatus.editing || ParcelRefusalStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bid = widget.bid;
    final isCash = bid.paymentMethod == BidPaymentMethod.cash;

    return BlocListener<ParcelRefusalCubit, ParcelRefusalState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _onStateChanged,
      child: BlocBuilder<ParcelRefusalCubit, ParcelRefusalState>(
        builder: (context, state) {
          final cubit = context.read<ParcelRefusalCubit>();
          final otherReason = state.reason == ParcelRefusalReason.other;
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.parcelRefusalIntro,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.base),
                _DeclaredCard(bid: bid),
                const SizedBox(height: DonySpacing.lg),
                DonyRadioGroup<ParcelRefusalReason>(
                  label: l.parcelRefusalReasonLabel,
                  value: state.reason,
                  onChanged: (reason) {
                    if (reason != null) cubit.selectReason(reason);
                  },
                  options: [
                    DonyRadioOption(
                      value: ParcelRefusalReason.contentMismatch,
                      label: l.parcelRefusalReasonContentMismatch,
                      subtitle: l.parcelRefusalReasonContentMismatchHint,
                    ),
                    DonyRadioOption(
                      value: ParcelRefusalReason.overweight,
                      label: l.parcelRefusalReasonOverweight,
                    ),
                    DonyRadioOption(
                      value: ParcelRefusalReason.prohibited,
                      label: l.parcelRefusalReasonProhibited,
                      subtitle: l.parcelRefusalReasonProhibitedHint,
                    ),
                    DonyRadioOption(
                      value: ParcelRefusalReason.other,
                      label: l.parcelRefusalReasonOther,
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.base),
                DonyTextField(
                  controller: _detailsCtrl,
                  label: l.parcelRefusalDetailsLabel,
                  hint: otherReason
                      ? l.parcelRefusalDetailsRequiredHint
                      : l.parcelRefusalDetailsHint,
                  requiredLabel: otherReason,
                  maxLines: 3,
                  minLines: 2,
                  enabled: !state.isSubmitting,
                ),
                const SizedBox(height: DonySpacing.lg),
                ParcelPhotoPicker(
                  title: l.parcelRefusalPhotoLabel,
                  help: l.parcelRefusalPhotoHelp,
                  photoPath: state.photoPath,
                  busy: state.isSubmitting,
                  onTake: cubit.takePhoto,
                  onRemove: cubit.removePhoto,
                ),
                const SizedBox(height: DonySpacing.lg),
                if (bid.status == 'HANDED_OVER') ...[
                  DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    message: l.parcelRefusalHandedOverNotice,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
                DonyStatusBanner(
                  type: isCash
                      ? DonyStatusBannerType.warning
                      : DonyStatusBannerType.info,
                  message: isCash
                      ? l.parcelRefusalCashNotice
                      : l.parcelRefusalConsequences,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Rappel de ce que l'expéditeur a déclaré : poids, catégorie, description.
class _DeclaredCard extends StatelessWidget {
  const _DeclaredCard({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final weight = bid.weightKg;
    final category = bid.contentCategory?.trim();
    final description = bid.description?.trim();
    final lines = [
      if (weight != null && weight > 0)
        l.parcelRefusalDeclaredWeight(_formatKg(weight)),
      if (category != null && category.isNotEmpty) category,
    ];
    if (lines.isEmpty && (description == null || description.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.parcelRefusalDeclaredTitle,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xs),
          if (lines.isNotEmpty)
            Text(
              lines.join(' · '),
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatKg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}
