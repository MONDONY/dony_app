import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RecipientsScreen extends StatelessWidget {
  const RecipientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyPageScaffold(
      title: 'Mes destinataires',
      scrollable: false,
      appBarActions: [
        IconButton(
          icon: DonyIcon('plus', color: cs.primary),
          tooltip: 'Ajouter un destinataire',
          onPressed: () async {
            final changed = await context.push<bool>('/profile/recipients/new');
            if ((changed ?? false) && context.mounted) {
              context.read<RecipientBloc>().add(const RecipientLoaded());
            }
          },
        ),
      ],
      body: BlocBuilder<RecipientBloc, RecipientState>(
        builder: (context, state) {
          if (state.status == RecipientStatus.loading &&
              state.recipients.isEmpty) {
            return const DonyEmptyState(
              type: DonyEmptyStateType.loading,
              title: '',
            );
          }
          if (state.status == RecipientStatus.error &&
              state.recipients.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () =>
                  context.read<RecipientBloc>().add(const RecipientLoaded()),
            );
          }
          if (state.recipients.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun destinataire enregistré',
              description:
                  'Ajoute tes proches en Afrique pour envoyer en 1 tap.',
              actionLabel: 'Ajouter mon premier destinataire',
              onAction: () async {
                final changed = await context.push<bool>('/profile/recipients/new');
                if ((changed ?? false) && context.mounted) {
                  context.read<RecipientBloc>().add(const RecipientLoaded());
                }
              },
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.paddingOf(context).bottom + 100,
            ),
            itemCount: state.recipients.length,
            separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm),
            itemBuilder: (context, i) {
              final recipient = state.recipients[i];
              return _RecipientCard(recipient: recipient)
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                  .slideY(begin: 0.03, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.recipient});

  final Recipient recipient;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final locationParts = [
      if (recipient.street != null) recipient.street!,
      recipient.city,
      _countryLabel(recipient.country),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: InkWell(
        onTap: () async {
          final changed = await context.push<bool>('/profile/recipients/${recipient.id}');
          if ((changed ?? false) && context.mounted) {
            context.read<RecipientBloc>().add(const RecipientLoaded());
          }
        },
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyAvatar(name: recipient.fullName, size: DonyAvatarSize.md),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.fullName,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (recipient.relationship != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        recipient.relationship!,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: DonySpacing.xs),
                    Row(
                      children: [
                        DonyIcon('phone', size: 14, color: cs.primary),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          recipient.phoneE164,
                          style: tt.bodySmall?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        DonyIcon('map-pin',
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: DonySpacing.xs),
                        Expanded(
                          child: Text(
                            locationParts.join(', '),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _KebabMenu(recipient: recipient),
            ],
          ),
        ),
      ),
    );
  }

  static String _countryLabel(String code) {
    const labels = {
      'SN': 'Sénégal',
      'CI': "Côte d'Ivoire",
      'ML': 'Mali',
      'CM': 'Cameroun',
    };
    return labels[code] ?? code;
  }
}

class _KebabMenu extends StatelessWidget {
  const _KebabMenu({required this.recipient});

  final Recipient recipient;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<_RecipientAction>(
      icon: DonyIcon('ellipsis-vertical', color: cs.onSurfaceVariant, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      onSelected: (action) async {
        switch (action) {
          case _RecipientAction.edit:
            final changed = await context.push<bool>('/profile/recipients/${recipient.id}');
            if ((changed ?? false) && context.mounted) {
              context.read<RecipientBloc>().add(const RecipientLoaded());
            }
          case _RecipientAction.delete:
            final confirmed = await DonyDialog.show(
              context,
              title: 'Supprimer le destinataire',
              message:
                  'Es-tu sûr de vouloir supprimer "${recipient.fullName}" ? Cette action est irréversible.',
              iconAsset: 'trash-2',
              confirmLabel: 'Supprimer',
              variant: DonyDialogVariant.destructive,
              cancelLabel: 'Annuler',
            );
            if ((confirmed ?? false) && context.mounted) {
              context
                  .read<RecipientBloc>()
                  .add(RecipientDeleted(recipient.id));
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _RecipientAction.edit,
          child: Row(
            children: [
              DonyIcon('square-pen', size: 18),
              SizedBox(width: DonySpacing.sm),
              Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _RecipientAction.delete,
          child: Row(
            children: [
              DonyIcon('trash-2',
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Supprimer',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _RecipientAction { edit, delete }
