import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

// ── Items de liste typés pour le regroupement temporel ─────────────────────────

sealed class _ListItem {}

class _SectionItem extends _ListItem {
  final String label;
  _SectionItem(this.label);
}

class _ConvItem extends _ListItem {
  final ConversationModel conv;
  _ConvItem(this.conv);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ConversationListBloc>();
    if (bloc.state is ConversationListLoaded) {
      _searchController.text =
          (bloc.state as ConversationListLoaded).searchQuery;
    }
    bloc.add(const ConversationsLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ConversationListBloc, ConversationListState>(
          builder: (context, state) {
            final filter = state is ConversationListLoaded
                ? state.filter
                : ConversationFilter.all;
            final searchQuery = state is ConversationListLoaded
                ? state.searchQuery
                : '';

            return Column(
              children: [
                _MessagesHeader(
                  searchController: _searchController,
                  activeFilter: filter,
                  searchQuery: searchQuery,
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConversationListState state) {
    final cs = Theme.of(context).colorScheme;

    if (state is ConversationListLoading || state is ConversationListInitial) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (state is ConversationListError) {
      return DonyEmptyState(
        type: DonyEmptyStateType.error,
        mascotte: DonyMascotteType.erreurLegere,
        iconAsset: 'wifi-off',
        title: 'Erreur de chargement',
        description: ErrorPresenter.resolve(state.error).message,
        actionLabel: 'Réessayer',
        onAction: () => context.read<ConversationListBloc>().add(
          const ConversationsLoadRequested(),
        ),
      );
    }

    if (state is ConversationListLoaded) {
      if (state.displayed.isEmpty) {
        return LayoutBuilder(
          builder: (ctx, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: state.searchQuery.isNotEmpty
                    ? 'Aucun résultat'
                    : 'Aucun message',
                description: state.searchQuery.isNotEmpty
                    ? 'Aucune conversation ne correspond à « ${state.searchQuery} ».'
                    : 'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
              ),
            ),
          ),
        );
      }

      final items = _buildGroupedItems(state.displayed);

      return RefreshIndicator(
        color: cs.primary,
        onRefresh: () async => context.read<ConversationListBloc>().add(
          const ConversationsLoadRequested(),
        ),
        child: ListView.builder(
          // Padding bas = hauteur de la nav flottante (~100) + safe area,
          // pour que les derniers éléments scrollent au-dessus de l'île de
          // nav (même pattern que announcement_list_screen).
          padding: EdgeInsets.only(
            bottom: 100 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            if (item is _SectionItem) {
              return _SectionLabel(label: item.label);
            }

            final conv = (item as _ConvItem).conv;
            return _SlidableTile(conversation: conv)
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                  duration: 260.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideY(
                  begin: 0.03,
                  end: 0,
                  delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                  duration: 260.ms,
                  curve: Curves.easeOutCubic,
                );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Regroupement temporel ──────────────────────────────────────────────────────

List<_ListItem> _buildGroupedItems(List<ConversationModel> convs) {
  final now = DateTime.now();
  final today = <ConversationModel>[];
  final thisWeek = <ConversationModel>[];
  final older = <ConversationModel>[];

  for (final c in convs) {
    if (c.lastMessageAt == null) {
      older.add(c);
      continue;
    }
    final local = c.lastMessageAt!.isUtc
        ? c.lastMessageAt!.toLocal()
        : c.lastMessageAt!;
    final todayDate = DateTime(now.year, now.month, now.day);
    final localDate = DateTime(local.year, local.month, local.day);
    final dayDiff = todayDate.difference(localDate).inDays;
    if (dayDiff == 0) {
      today.add(c);
    } else if (dayDiff < 7) {
      thisWeek.add(c);
    } else {
      older.add(c);
    }
  }

  final items = <_ListItem>[];
  if (today.isNotEmpty) {
    items.add(_SectionItem("AUJOURD'HUI"));
    items.addAll(today.map(_ConvItem.new));
  }
  if (thisWeek.isNotEmpty) {
    items.add(_SectionItem('CETTE SEMAINE'));
    items.addAll(thisWeek.map(_ConvItem.new));
  }
  if (older.isNotEmpty) {
    items.add(_SectionItem('PLUS ANCIEN'));
    items.addAll(older.map(_ConvItem.new));
  }
  return items;
}

// ── Header : titre + recherche + pills ────────────────────────────────────────

class _MessagesHeader extends StatelessWidget {
  final TextEditingController searchController;
  final ConversationFilter activeFilter;
  final String searchQuery;

  const _MessagesHeader({
    required this.searchController,
    required this.activeFilter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSearching = searchQuery.isNotEmpty;

    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bloc 1 — Titre
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.base,
              0,
            ),
            child: Row(
              children: [
                Text('Messages', style: tt.headlineLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Voir les conversations archivées',
                  onPressed: () => context.push('/messages/archives'),
                  icon: DonyIcon('archive', color: cs.onSurfaceVariant),
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // Bloc 2 — Barre de recherche pleine largeur
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: DonySpacing.sm,
            ),
            child: TextField(
              controller: searchController,
              onChanged: (q) => context.read<ConversationListBloc>().add(
                ConversationFilterChanged(filter: activeFilter, searchQuery: q),
              ),
              textInputAction: TextInputAction.search,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation…',
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                prefixIcon: DonyIcon(
                  'search',
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: DonyIcon(
                          'x',
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () {
                          searchController.clear();
                          context.read<ConversationListBloc>().add(
                            ConversationFilterChanged(
                              filter: activeFilter,
                              searchQuery: '',
                            ),
                          );
                        },
                        tooltip: 'Effacer',
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: 10,
                ),
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
              ),
            ),
          ),

          // Bloc 3 — Pills de filtre (masquées pendant la recherche)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            child: isSearching
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      0,
                      DonySpacing.lg,
                      DonySpacing.sm,
                    ),
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'Tous',
                          isActive: activeFilter == ConversationFilter.all,
                          onTap: () => context.read<ConversationListBloc>().add(
                            const ConversationFilterChanged(
                              filter: ConversationFilter.all,
                              searchQuery: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        _FilterPill(
                          label: 'Non lus',
                          isActive: activeFilter == ConversationFilter.unread,
                          onTap: () => context.read<ConversationListBloc>().add(
                            const ConversationFilterChanged(
                              filter: ConversationFilter.unread,
                              searchQuery: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        _FilterPill(
                          label: 'En cours',
                          isActive: activeFilter == ConversationFilter.active,
                          onTap: () => context.read<ConversationListBloc>().add(
                            const ConversationFilterChanged(
                              filter: ConversationFilter.active,
                              searchQuery: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        _FilterPill(
                          label: 'Terminés',
                          isActive: activeFilter == ConversationFilter.done,
                          onTap: () => context.read<ConversationListBloc>().add(
                            const ConversationFilterChanged(
                              filter: ConversationFilter.done,
                              searchQuery: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          Divider(height: 1, color: cs.outlineVariant),
        ],
      ),
    );
  }
}

// ── Pill de filtre ─────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.xs,
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Tuile avec swipe Archiver / Supprimer ──────────────────────────────────────

class _SlidableTile extends StatelessWidget {
  final ConversationModel conversation;
  const _SlidableTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey(conversation.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (ctx) {
              ctx.read<ConversationListBloc>().add(
                ConversationArchiveRequested(conversation.id),
              );
              DonySnackbar.show(
                ctx,
                message: 'Conversation archivée',
                actionLabel: 'Annuler',
                onAction: () => ctx.read<ConversationListBloc>().add(
                  ConversationUnarchiveRequested(conversation.id),
                ),
              );
            },
            backgroundColor: cs.warning,
            foregroundColor: cs.onPrimary,
            icon: Icons.archive_outlined,
            label: 'Archiver',
          ),
          SlidableAction(
            onPressed: (ctx) {
              // Capturer le bloc avant le dialog : le volet Slidable se
              // referme au tap (autoClose) et démonte ctx pendant que le
              // dialog est ouvert — un ctx.read dans le .then échouerait.
              final bloc = ctx.read<ConversationListBloc>();
              showDialog<bool>(
                context: ctx,
                // Le dialog vit sur le root navigator alors que la tuile est
                // dans le Navigator imbriqué du StatefulShellBranch : les pop
                // doivent utiliser le contexte du dialog, sinon ils dépilent
                // la branche et la Future ne se résout jamais.
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Supprimer la conversation ?'),
                  content: const Text('Cette action est irréversible.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ).then((confirmed) {
                if (confirmed == true) {
                  bloc.add(ConversationDeleteRequested(conversation.id));
                }
              });
            },
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
          ),
        ],
      ),
      child: ConversationTile(conversation: conversation),
    );
  }
}
