import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:dony/features/messaging/presentation/widgets/negotiations_shortcut_tile.dart';
import 'package:dony/features/support/bloc/support_summary_cubit.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/presentation/widgets/support_conversation_tile.dart';
import 'package:dony/l10n/l10n.dart';
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
    // Rafraîchir le compteur support à chaque ouverture de l'onglet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<SupportUnreadCubit>().refresh();
    });
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
        child: BlocConsumer<ConversationListBloc, ConversationListState>(
          listenWhen: (previous, current) =>
              current is ConversationListLoaded && current.muteFeedback != null,
          listener: (context, state) =>
              _showMuteFeedback(context, state as ConversationListLoaded),
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

  /// Retour d'une bascule de sourdine faite depuis le volet glissant.
  void _showMuteFeedback(BuildContext context, ConversationListLoaded state) {
    final feedback = state.muteFeedback!;
    if (feedback.error != null) {
      ErrorPresenter.show(context, feedback.error);
      return;
    }
    final l = context.l10n;
    DonySnackbar.show(
      context,
      message: feedback.muted
          ? l.chatNotificationsMutedSnackbar
          : l.chatNotificationsUnmutedSnackbar,
    );
  }

  /// Clé globale : les lignes épinglées changent de parent entre le
  /// chargement, la liste vide et la liste chargée. Sans elle, chaque passage
  /// recréerait le raccourci, qui relance ses deux chargements en initState.
  final _pinnedRowsKey = GlobalKey(debugLabel: 'messages-pinned-rows');

  /// Lignes épinglées en tête de liste : Support Yadony puis le raccourci
  /// Discussions de prix. Toujours au-dessus des conversations, non
  /// filtrables, mais elles défilent avec la liste au lieu de rester figées
  /// sous l'en-tête, où elles mangeaient l'écran (FLUTTER-A8).
  Widget _pinnedRows() {
    return Column(
      key: _pinnedRowsKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Aperçu et compteur viennent du même `/support/summary`
        // (SupportUnreadCubit.refresh alimente les deux).
        BlocBuilder<SupportSummaryCubit, SupportSummaryState>(
          bloc: getIt<SupportSummaryCubit>(),
          builder: (context, summaryState) {
            final summary = summaryState.summary;
            return BlocBuilder<SupportUnreadCubit, int>(
              bloc: getIt<SupportUnreadCubit>(),
              builder: (context, supportUnread) {
                return SupportConversationTile(
                  unreadCount: supportUnread,
                  latestTicket: summary?.latestTicket,
                  onReturned: () => getIt<SupportUnreadCubit>().refresh(),
                );
              },
            );
          },
        ),
        // Raccourci vers Activités › Discussions de prix : les négociations
        // ne sont pas des conversations, mais c'est ici qu'on les cherche
        // (FLUTTER-44). Masqué sans négociation ouverte.
        const NegotiationsShortcutSection(),
      ],
    );
  }

  /// Ligne « Archivées (n) » en tête de liste, comme WhatsApp (FLUTTER-FR).
  /// Absente sans archive, et pendant une recherche, qui ne porte que sur les
  /// conversations courantes.
  Widget _archivedRow(BuildContext context, ConversationListLoaded state) {
    final count = state.archivedConversations.length;
    if (count == 0 || state.searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return DonyArchivedRow(
      key: const Key('messages-archived-row'),
      label: l.archivedRowLabel,
      semanticLabel: l.archivedRowSemantics(count),
      count: count,
      onTap: () => context.push('/messages/archives'),
    );
  }

  Widget _errorState(BuildContext context, ConversationListError state) {
    final l = context.l10n;
    return DonyEmptyState(
      type: DonyEmptyStateType.error,
      mascotte: DonyMascotteType.erreurLegere,
      iconAsset: 'wifi-off',
      title: l.commonLoadError,
      description: ErrorPresenter.resolve(state.error, l10n: l).message,
      actionLabel: l.commonRetry,
      onAction: () => context.read<ConversationListBloc>().add(
        const ConversationsLoadRequested(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConversationListState state) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    if (state is ConversationListLoading || state is ConversationListInitial) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _pinnedRows()),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: 100 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.builder(
              itemCount: 6,
              itemBuilder: (_, _) => const DonyConversationTileSkeleton(),
            ),
          ),
        ],
      );
    }

    if (state is ConversationListError) {
      return Column(
        children: [
          _pinnedRows(),
          Expanded(child: _errorState(context, state)),
        ],
      );
    }

    if (state is ConversationListLoaded) {
      if (state.displayed.isEmpty) {
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _archivedRow(context, state)),
            SliverToBoxAdapter(child: _pinnedRows()),
            SliverFillRemaining(
              hasScrollBody: false,
              child: DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: state.searchQuery.isNotEmpty
                    ? l.conversationListEmptyResultsTitle
                    : l.conversationListEmptyTitle,
                description: state.searchQuery.isNotEmpty
                    ? l.conversationListEmptySearchDescription(
                        state.searchQuery,
                      )
                    : l.conversationListEmptyDescription,
              ),
            ),
          ],
        );
      }

      final items = _buildGroupedItems(l, state.displayed);

      return RefreshIndicator(
        color: cs.primary,
        onRefresh: () async => context.read<ConversationListBloc>().add(
          const ConversationsLoadRequested(),
        ),
        // SliverToBoxAdapter garde les lignes épinglées montées quand elles
        // sortent de l'écran : un ListView les détruirait au défilement.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _archivedRow(context, state)),
            SliverToBoxAdapter(child: _pinnedRows()),
            SliverPadding(
              // Padding bas = hauteur de la nav flottante (~100) + safe area,
              // pour que les derniers éléments scrollent au-dessus de l'île de
              // nav (même pattern que announcement_list_screen).
              padding: EdgeInsets.only(
                bottom: 100 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.builder(
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
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Regroupement temporel ──────────────────────────────────────────────────────

List<_ListItem> _buildGroupedItems(
  AppLocalizations l,
  List<ConversationModel> convs,
) {
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
    items.add(_SectionItem(l.conversationSectionToday));
    items.addAll(today.map(_ConvItem.new));
  }
  if (thisWeek.isNotEmpty) {
    items.add(_SectionItem(l.conversationSectionThisWeek));
    items.addAll(thisWeek.map(_ConvItem.new));
  }
  if (older.isNotEmpty) {
    items.add(_SectionItem(l.conversationSectionOlder));
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
    final l = context.l10n;
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
                Text(l.conversationListTitle, style: tt.headlineLarge),
                const Spacer(),
                // L'accès aux archives est la ligne « Archivées » en tête de
                // liste (FLUTTER-FR), plus une icône d'en-tête.
                const DonyFeedbackButton(),
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
                hintText: l.conversationListSearchHint,
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
                        tooltip: l.commonClear,
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
                          label: l.conversationFilterAll,
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
                          label: l.conversationFilterUnread,
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
                          label: l.conversationFilterActive,
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
                          label: l.conversationFilterDone,
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
    final l = context.l10n;

    final muted = conversation.notificationsMuted;
    return Slidable(
      key: ValueKey(conversation.id),
      // Sourdine (FLUTTER-CM) : balayage vers la droite, à part d'Archiver et
      // Supprimer. La snackbar part à la réponse du serveur (listener de
      // l'écran), pas au tap : un échec annule la bascule.
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          DonySwipeAction(
            key: const Key('conversation-swipe-notifications'),
            onPressed: (ctx) => ctx.read<ConversationListBloc>().add(
              ConversationNotificationsMuteToggled(conversation.id),
            ),
            backgroundColor: cs.surfaceContainerHighest,
            foregroundColor: cs.onSurface,
            icon: muted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            label: muted
                ? l.conversationUnmuteAction
                : l.conversationMuteAction,
          ),
        ],
      ),
      // Largeur prévue pour « Archiver » et « Supprimer » en entier, en
      // français comme en anglais (FLUTTER-FR : 0.45 les tronquait).
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.6,
        children: [
          DonySwipeAction(
            key: const Key('conversation-swipe-archive'),
            onPressed: (ctx) {
              // Capturer le bloc avant l'archivage (FLUTTER-GN) : la
              // conversation quitte la liste et démonte la tuile, donc ctx,
              // avant que le testeur ne tape « Annuler » — un ctx.read dans
              // onAction plantait dans Provider._inheritedElementOf.
              final bloc = ctx.read<ConversationListBloc>()
                ..add(ConversationArchiveRequested(conversation.id));
              DonySnackbar.show(
                ctx,
                message: l.conversationArchivedSnackbar,
                actionLabel: l.commonCancel,
                onAction: () =>
                    bloc.add(ConversationUnarchiveRequested(conversation.id)),
              );
            },
            backgroundColor: cs.warning,
            foregroundColor: cs.onPrimary,
            icon: Icons.archive_outlined,
            label: l.conversationArchiveAction,
          ),
          DonySwipeAction(
            key: const Key('conversation-swipe-delete'),
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
                  title: Text(l.conversationDeleteConfirmTitle),
                  content: Text(l.conversationDeleteConfirmMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: Text(l.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: Text(
                        l.commonDelete,
                        style: const TextStyle(color: Colors.red),
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
            label: l.commonDelete,
          ),
        ],
      ),
      child: ConversationTile(conversation: conversation),
    );
  }
}
