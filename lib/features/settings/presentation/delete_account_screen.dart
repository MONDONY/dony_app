import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionRequested) {
          context.read<AuthBloc>().add(const AuthCheckRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Votre compte sera supprimé dans 30 jours. Vous pouvez annuler depuis votre profil.'),
              backgroundColor: cs.error,
            ),
          );
          assert(context.canPop(), 'DeleteAccountScreen must always be pushed onto the stack');
          context.pop();
        } else if (state is AccountDeletionError && state.isEscrowBlocked) {
          showDialog(
            context: context,
            builder: (_) => const EscrowBlockDialog(),
          );
        }
      },
      child: Scaffold(
        appBar: DonyAppBar(title: 'Supprimer mon compte'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(DonySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: DonyColors.errorLight,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(
                      color: DonyColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: DonyColors.error, size: 20),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        'Cette action entraîne la suppression de votre compte.',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DonyColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.xl),
              Text('Ce qui se passe',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: DonySpacing.md),
              const _InfoRow(
                icon: Icons.hourglass_empty_rounded,
                text:
                    'Période de grâce de 30 jours — vous pouvez revenir sur votre décision.',
              ),
              const SizedBox(height: DonySpacing.md),
              const _InfoRow(
                icon: Icons.archive_outlined,
                text:
                    'Vos annonces et bids actifs sont archivés immédiatement.',
              ),
              const SizedBox(height: DonySpacing.md),
              const _InfoRow(
                icon: Icons.delete_forever_outlined,
                text:
                    'Après la période de grâce, vos données personnelles sont pseudonymisées (RGPD).',
              ),
              const SizedBox(height: DonySpacing.xxl),
              BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
                builder: (context, state) {
                  final isLoading = state is AccountDeletionLoading;
                  return DonyButton(
                    label: 'Confirmer la suppression',
                    onPressed: isLoading
                        ? null
                        : () => context
                            .read<AccountDeletionBloc>()
                            .add(const RequestDeletion()),
                    variant: DonyButtonVariant.destructive,
                  );
                },
              ),
              BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
                builder: (context, state) {
                  if (state is AccountDeletionError && !state.isEscrowBlocked) {
                    return Padding(
                      padding: const EdgeInsets.only(top: DonySpacing.md),
                      child: Text(
                        state.message,
                        style: tt.bodySmall?.copyWith(color: DonyColors.error),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(text,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}
