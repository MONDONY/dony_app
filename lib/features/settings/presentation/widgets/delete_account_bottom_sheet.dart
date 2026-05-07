import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _reasons = [
  "Je n'utilise plus le service",
  'Problème de confidentialité',
  'Trop de notifications',
  'Autre raison',
];

class DeleteAccountBottomSheet extends StatefulWidget {
  const DeleteAccountBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Supprimer le compte ?',
      subtitle: 'Action irréversible — toutes vos données seront effacées',
      child: BlocProvider.value(
        value: context.read<AccountDeletionBloc>(),
        child: const DeleteAccountBottomSheet(),
      ),
    );
  }

  @override
  State<DeleteAccountBottomSheet> createState() =>
      _DeleteAccountBottomSheetState();
}

class _DeleteAccountBottomSheetState extends State<DeleteAccountBottomSheet> {
  String? _reason;

  void _confirm(BuildContext context) {
    final bloc = context.read<AccountDeletionBloc>();
    Navigator.of(context, rootNavigator: true).pop();
    DonyDialog.show(
      context,
      title: 'Dernière confirmation',
      message:
          'Cette action supprimera définitivement votre compte et toutes vos données. Êtes-vous certain ?',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_forever_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(const RequestDeletion());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionRequested) {
          context.read<AuthBloc>().add(const AuthCheckRequested());
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
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Raison (optionnel)', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          DonyRadioGroup<String>(
            value: _reason,
            onChanged: (v) => setState(() => _reason = v),
            options: _reasons
                .map((r) => DonyRadioOption(value: r, label: r))
                .toList(),
          ),
          const SizedBox(height: DonySpacing.xl),
          Row(
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
                child: BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
                  builder: (context, state) => DonyButton(
                    label: 'Supprimer définitivement',
                    variant: DonyButtonVariant.destructive,
                    isLoading: state is AccountDeletionLoading,
                    onPressed: state is AccountDeletionLoading
                        ? null
                        : () => _confirm(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
