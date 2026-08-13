// dony_app/lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/presentation/widgets/delete_confirmation_sheet.dart';
import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteAccountBottomSheet extends StatefulWidget {
  final ValueNotifier<DeleteMode?> modeNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  const DeleteAccountBottomSheet({
    super.key,
    required this.modeNotifier,
    this.onSubmitReady,
  });

  static Future<void> show(
    BuildContext context, {
    DeletionEligibilityCubit? eligibilityCubit,
  }) {
    final deletionBloc = context.read<AccountDeletionBloc>();
    final cubit =
        eligibilityCubit ??
        DeletionEligibilityCubit(getIt<AccountDeletionRepository>());
    cubit.check();
    final modeNotifier = ValueNotifier<DeleteMode?>(null);
    VoidCallback? submit;

    return DonyBottomSheet.show(
      context,
      title: 'Supprimer mon compte',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: deletionBloc),
          BlocProvider.value(value: cubit),
        ],
        child: child,
      ),
      stickyBottom: _DeleteActions(
        modeNotifier: modeNotifier,
        onSubmit: () => submit?.call(),
      ),
      child: DeleteAccountBottomSheet(
        modeNotifier: modeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(() {
      modeNotifier.dispose();
      // Ne ferme que le cubit créé ici — un cubit injecté (tests) reste géré
      // par son propriétaire.
      if (eligibilityCubit == null) {
        cubit.close();
      }
    });
  }

  @override
  State<DeleteAccountBottomSheet> createState() =>
      _DeleteAccountBottomSheetState();
}

class _DeleteAccountBottomSheetState extends State<DeleteAccountBottomSheet> {
  String? _reason;

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_confirm);
  }

  void _confirm() {
    final bloc = context.read<AccountDeletionBloc>();
    final mode = widget.modeNotifier.value;

    if (mode == DeleteMode.soft) {
      // Dialog shown while sheet is still mounted so context stays valid.
      // BlocListener catches AccountDeletionRequested (below) to close the sheet
      // and show the snackbar while still in the tree.
      DonyDialog.show(
        context,
        title: 'Confirmer la pause',
        message:
            'Votre compte sera suspendu pendant 30 jours. Vous pourrez le réactiver depuis votre profil.',
        iconAsset: 'hourglass',
      ).then((confirmed) {
        if (confirmed == true && mounted) bloc.add(const RequestDeletion());
      });
    } else if (mode == DeleteMode.hard) {
      final hardBloc = bloc;
      Navigator.of(context, rootNavigator: true).pop();
      DeleteConfirmationSheet.show(context, hardBloc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionRequested) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message:
                'Votre compte sera supprimé dans 30 jours. Vous pouvez annuler depuis votre profil.',
          );
        } else if (state is AccountDeletionError && state.isEscrowBlocked) {
          EscrowBlockDialog.show(context);
        } else if (state is AccountDeletionError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModeCard(
            mode: DeleteMode.soft,
            modeNotifier: widget.modeNotifier,
            iconAsset: 'hourglass',
            title: 'Pause 30 jours',
            badge: 'RÉVERSIBLE',
            isDestructive: false,
            description:
                'Votre compte est suspendu. Vous pouvez revenir à tout moment dans les 30 jours. Après ce délai, vos données personnelles sont pseudonymisées (RGPD).',
          ),
          const SizedBox(height: DonySpacing.md),
          _ModeCard(
            mode: DeleteMode.hard,
            modeNotifier: widget.modeNotifier,
            iconAsset: 'trash',
            title: 'Supprimer définitivement',
            badge: 'IRRÉVERSIBLE',
            isDestructive: true,
            description:
                'Toutes vos données personnelles sont effacées immédiatement. Cette action est définitive et ne peut pas être annulée.',
          ),
          const SizedBox(height: DonySpacing.lg),
          Text('Raison (optionnel)', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          DonyRadioGroup<String>(
            value: _reason,
            onChanged: (v) => setState(() => _reason = v),
            options: const [
              DonyRadioOption(
                value: "Je n'utilise plus le service",
                label: "Je n'utilise plus le service",
              ),
              DonyRadioOption(
                value: 'Problème de confidentialité',
                label: 'Problème de confidentialité',
              ),
              DonyRadioOption(
                value: 'Trop de notifications',
                label: 'Trop de notifications',
              ),
              DonyRadioOption(value: 'Autre raison', label: 'Autre raison'),
            ],
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}

/// Barre d'actions collée en bas de la sheet : motif de blocage éventuel +
/// boutons Annuler / valider.
class _DeleteActions extends StatelessWidget {
  final ValueNotifier<DeleteMode?> modeNotifier;
  final VoidCallback onSubmit;

  const _DeleteActions({required this.modeNotifier, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final eligibility = context.watch<DeletionEligibilityCubit>().state;
    final isSubmitting =
        context.watch<AccountDeletionBloc>().state is AccountDeletionLoading;
    final blockedReason = eligibility.blockedReasonMessage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bloqué par le backend (escrow actif, solde wallet...) : on l'explique
        // ICI, à côté du bouton, plutôt que de laisser l'utilisateur tenter
        // puis échouer.
        if (blockedReason != null) ...[
          DonyStatusBanner(
            type: DonyStatusBannerType.error,
            iconAsset: 'lock',
            message: blockedReason,
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        ValueListenableBuilder<DeleteMode?>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) {
            final isHard = mode == DeleteMode.hard;
            return Row(
              children: [
                Expanded(
                  child: DonyButton(
                    label: 'Annuler',
                    variant: DonyButtonVariant.ghost,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  flex: 2,
                  child: DonyButton(
                    label: isHard ? 'Continuer →' : 'Confirmer la pause',
                    variant: isHard
                        ? DonyButtonVariant.destructive
                        : DonyButtonVariant.primary,
                    isLoading: isSubmitting,
                    onPressed:
                        mode == null ||
                            isSubmitting ||
                            eligibility.isLoading ||
                            !eligibility.canDelete
                        ? null
                        : onSubmit,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final DeleteMode mode;
  final ValueNotifier<DeleteMode?> modeNotifier;
  final String iconAsset;
  final String title;
  final String badge;
  final bool isDestructive;
  final String description;

  const _ModeCard({
    required this.mode,
    required this.modeNotifier,
    required this.iconAsset,
    required this.title,
    required this.badge,
    required this.isDestructive,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final badgeColor = isDestructive ? cs.error : cs.success;

    return ValueListenableBuilder<DeleteMode?>(
      valueListenable: modeNotifier,
      builder: (_, selected, _) {
        final isSelected = selected == mode;
        final borderColor = isSelected ? badgeColor : cs.outline;
        final bgColor = isSelected
            ? badgeColor.withValues(alpha: 0.06)
            : Colors.transparent;

        return GestureDetector(
          onTap: () => modeNotifier.value = mode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DonyIcon(iconAsset, size: 20, color: badgeColor),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.xl),
                      ),
                      child: Text(
                        badge,
                        style: tt.labelSmall?.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  description,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
