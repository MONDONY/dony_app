import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/recipient_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

          final showSearch = state.recipients.length > 3;
          final filtered = showSearch
              ? filterRecipients(state.recipients, _searchCtrl.text)
              : state.recipients;

          return Column(
            children: [
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.sm,
                    DonySpacing.md,
                    DonySpacing.sm,
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
                    : showSearch
                        ? ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              DonySpacing.sm,
                              DonySpacing.xl,
                              DonySpacing.sm,
                              MediaQuery.paddingOf(context).bottom + 100,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: DonySpacing.sm),
                            itemBuilder: (context, i) {
                              final recipient = filtered[i];
                              return _RecipientCard(recipient: recipient)
                                  .animate()
                                  .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                                  .slideY(
                                      begin: 0.03, curve: Curves.easeOutCubic);
                            },
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final bottomInset =
                                  MediaQuery.paddingOf(context).bottom;
                              return SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  DonySpacing.sm,
                                  DonySpacing.xl,
                                  DonySpacing.sm,
                                  bottomInset + 24,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight -
                                        DonySpacing.xl -
                                        bottomInset -
                                        24,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      for (var i = 0;
                                          i < filtered.length;
                                          i++) ...[
                                        if (i > 0)
                                          const SizedBox(
                                              height: DonySpacing.sm),
                                        _RecipientCard(
                                                recipient: filtered[i])
                                            .animate()
                                            .fadeIn(
                                                delay: (i * 60).ms,
                                                duration: 280.ms)
                                            .slideY(
                                                begin: 0.03,
                                                curve: Curves.easeOutCubic),
                                      ],
                                      const SizedBox(height: DonySpacing.lg),
                                      _AddRecipientTile()
                                          .animate()
                                          .fadeIn(
                                              delay: (filtered.length * 60 +
                                                      100)
                                                  .ms,
                                              duration: 280.ms)
                                          .slideY(
                                              begin: 0.03,
                                              curve: Curves.easeOutCubic),
                                    ],
                                  ),
                                ),
                              );
                            },
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

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.recipient});

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

    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DonyRadius.card),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipient.fullName,
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (recipient.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Par défaut',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

class _AddRecipientTile extends StatelessWidget {
  const _AddRecipientTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () async {
          final changed = await context.push<bool>('/profile/recipients/new');
          if ((changed ?? false) && context.mounted) {
            context.read<RecipientBloc>().add(const RecipientLoaded());
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.lg,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: cs.primary, size: 24),
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Ajouter un destinataire',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
