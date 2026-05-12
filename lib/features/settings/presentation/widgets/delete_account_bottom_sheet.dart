// dony_app/lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
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

  static Future<void> show(BuildContext context) {
    final deletionBloc = context.read<AccountDeletionBloc>();
    final modeNotifier = ValueNotifier<DeleteMode?>(null);
    VoidCallback? submit;

    return DonyBottomSheet.show(
      context,
      title: 'Supprimer mon compte',
      wrapper: (child) =>
          BlocProvider.value(value: deletionBloc, child: child),
      stickyBottom: ValueListenableBuilder<DeleteMode?>(
        valueListenable: modeNotifier,
        builder: (_, mode, __) =>
            BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
          builder: (ctx, state) => Row(
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
                  label: mode == DeleteMode.hard
                      ? 'Continuer →'
                      : 'Confirmer la pause',
                  variant: mode == DeleteMode.hard
                      ? DonyButtonVariant.destructive
                      : DonyButtonVariant.primary,
                  isLoading: state is AccountDeletionLoading,
                  onPressed:
                      mode == null || state is AccountDeletionLoading
                          ? null
                          : () => submit?.call(),
                ),
              ),
            ],
          ),
        ),
      ),
      child: DeleteAccountBottomSheet(
        modeNotifier: modeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(modeNotifier.dispose);
  }

  @override
  State<DeleteAccountBottomSheet> createState() =>
      _DeleteAccountBottomSheetState();
}

class _DeleteAccountBottomSheetState
    extends State<DeleteAccountBottomSheet> {
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
        variant: DonyDialogVariant.info,
        icon: Icons.hourglass_empty_rounded,
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
          showDialog(
            context: context,
            builder: (_) => const EscrowBlockDialog(),
          );
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
            icon: Icons.hourglass_empty_rounded,
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
            icon: Icons.delete_forever_rounded,
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
              DonyRadioOption(value: "Je n'utilise plus le service", label: "Je n'utilise plus le service"),
              DonyRadioOption(value: 'Problème de confidentialité', label: 'Problème de confidentialité'),
              DonyRadioOption(value: 'Trop de notifications', label: 'Trop de notifications'),
              DonyRadioOption(value: 'Autre raison', label: 'Autre raison'),
            ],
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final DeleteMode mode;
  final ValueNotifier<DeleteMode?> modeNotifier;
  final IconData icon;
  final String title;
  final String badge;
  final bool isDestructive;
  final String description;

  const _ModeCard({
    required this.mode,
    required this.modeNotifier,
    required this.icon,
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
      builder: (_, selected, __) {
        final isSelected = selected == mode;
        final borderColor =
            isSelected ? badgeColor : cs.outline;
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
                    Icon(icon, size: 20, color: badgeColor),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(title,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.xl),
                      ),
                      child: Text(
                        badge,
                        style: tt.labelSmall?.copyWith(
                            color: badgeColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(description,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}
