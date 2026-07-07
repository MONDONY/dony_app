import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/recipient_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RecipientsScreen extends StatefulWidget {
  const RecipientsScreen({super.key});

  @override
  State<RecipientsScreen> createState() => _RecipientsScreenState();
}

class _RecipientsScreenState extends State<RecipientsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addRecipient(BuildContext context) async {
    final changed = await context.push<bool>('/profile/recipients/new');
    if ((changed ?? false) && context.mounted) {
      context.read<RecipientBloc>().add(const RecipientLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyPageScaffold(
      title: 'Mes destinataires',
      scrollable: false,
      // Zéro horizontal ici : chaque ligne gère déjà son propre inset
      // (DonySpacing.lg) via _RecipientTile / _SearchField, comme
      // CorridorAlertListScreen. Un padding horizontal ici s'ajouterait au
      // leur et doublerait la marge gauche/droite.
      padding: const EdgeInsets.fromLTRB(0, DonySpacing.xl, 0, DonySpacing.lg),
      floatingActionButton: Builder(
        builder: (fabCtx) => FloatingActionButton.extended(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter'),
          onPressed: () => _addRecipient(fabCtx),
        ),
      ),
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
              onAction: () => _addRecipient(context),
            );
          }

          final showSearch = state.recipients.length > 3;
          final filtered = showSearch
              ? filterRecipients(state.recipients, _searchCtrl.text)
              : state.recipients;

          return Column(
            children: [
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.md,
                    DonySpacing.lg,
                    0,
                  ),
                  child: _SearchField(controller: _searchCtrl),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? const DonyEmptyState(
                        mascotte: DonyMascotteType.assis,
                        title: 'Aucun résultat',
                        description:
                            'Aucun destinataire ne correspond à ta recherche.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          top: DonySpacing.sm,
                          bottom: DonySpacing.huge,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          indent: DonySpacing.lg + 44 + DonySpacing.md,
                          color: cs.outline.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, i) =>
                            _RecipientTile(recipient: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un destinataire…',
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
              left: DonySpacing.md, right: DonySpacing.sm),
          child: DonyIcon('search', size: 18, color: cs.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const DonyIcon('x', size: 16),
                onPressed: () => controller.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      ),
    );
  }
}

/// Ligne plate (style liste sans carte) d'un destinataire : avatar, nom,
/// téléphone, localisation et menu ⋮. Pas de bordure ni de fond teinté —
/// séparateurs fins gérés par la liste parente (même style que
/// [CorridorAlertTile]).
class _RecipientTile extends StatelessWidget {
  const _RecipientTile({required this.recipient});

  final Recipient recipient;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final locationParts = [
      if (recipient.street != null) recipient.street!,
      if (recipient.city != null) recipient.city!,
      _countryLabel(recipient.country),
    ];

    return InkWell(
      onTap: () async {
        final changed =
            await context.push<bool>('/profile/recipients/${recipient.id}');
        if ((changed ?? false) && context.mounted) {
          context.read<RecipientBloc>().add(const RecipientLoaded());
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyAvatar(name: recipient.fullName, size: DonyAvatarSize.md),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipient.fullName,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recipient.isDefault) ...[
                        const SizedBox(width: DonySpacing.xs),
                        DonyBadge(
                          label: 'Par défaut',
                          type: DonyBadgeType.success,
                        ),
                      ],
                    ],
                  ),
                  if (recipient.relationship != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      recipient.relationship!,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    recipient.phoneE164,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (locationParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _LocationChip(label: locationParts.join(', ')),
                  ],
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            _KebabMenu(recipient: recipient),
          ],
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

/// Petit chip « 📍 lieu » — même style que le chip zone des alertes corridor.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.xs + 2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('map-pin', size: 11, color: cs.onPrimaryContainer),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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
          case _RecipientAction.setDefault:
            context
                .read<RecipientBloc>()
                .add(RecipientDefaultSet(recipient.id));
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
        if (!recipient.isDefault)
          const PopupMenuItem(
            value: _RecipientAction.setDefault,
            child: Row(
              children: [
                DonyIcon('star', size: 18),
                SizedBox(width: DonySpacing.sm),
                Text('Définir par défaut'),
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

enum _RecipientAction { edit, setDefault, delete }
