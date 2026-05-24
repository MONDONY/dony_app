# Messages Screen Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigner le `ConversationListScreen` avec un header 3 blocs (titre / recherche pleine largeur / pills de filtre), regroupement temporel, tuiles non lues améliorées, et swipe gauche à deux actions (Archiver + Supprimer).

**Architecture:** Changements BLoC minimaux (2 events, 2 champs sur le state, 2 handlers) sans modifier le backend ni le modèle. Filtrage et regroupement 100 % client-side. La liste plate actuelle devient une liste d'items typés (`_Section | _Conv`) générée localement à partir du state BLoC. Deux actions swipe via `flutter_slidable`.

**Tech Stack:** Flutter · flutter_bloc · flutter_animate · flutter_slidable (nouveau) · DonyColors / DonySpacing design system tokens

---

## Fichiers

| Fichier | Action |
|---------|--------|
| `lib/features/messaging/bloc/conversation_list/conversation_list_state.dart` | Modifier — enum + 2 champs + getter |
| `lib/features/messaging/bloc/conversation_list/conversation_list_event.dart` | Modifier — +2 events |
| `lib/features/messaging/bloc/conversation_list/conversation_list_bloc.dart` | Modifier — +2 handlers, preserve filter dans emits |
| `lib/features/messaging/presentation/conversation_list_screen.dart` | Réécriture complète |
| `pubspec.yaml` | Modifier — ajouter flutter_slidable |
| `test/features/messaging/bloc/conversation_list_bloc_test.dart` | Modifier — +3 tests |
| `test/features/messaging/presentation/conversation_list_screen_test.dart` | Modifier — mettre à jour + ajouter tests |

---

## Task 1 — ConversationFilter enum + state étendu

**Files:**
- Modify: `lib/features/messaging/bloc/conversation_list/conversation_list_state.dart`

- [ ] **Step 1: Remplacer le contenu du fichier state**

```dart
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';

enum ConversationFilter { all, unread, active, done }

abstract class ConversationListState {
  const ConversationListState();
}

class ConversationListInitial extends ConversationListState {
  const ConversationListInitial();
}

class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

class ConversationListLoaded extends ConversationListState {
  final List<ConversationModel> conversations;
  final ConversationFilter filter;
  final String searchQuery;

  const ConversationListLoaded(
    this.conversations, {
    this.filter = ConversationFilter.all,
    this.searchQuery = '',
  });

  /// Liste filtrée + recherche — calculée à chaque build, sans duplication.
  List<ConversationModel> get displayed => conversations.where((c) {
        final matchFilter = switch (filter) {
          ConversationFilter.all    => true,
          ConversationFilter.unread => c.hasUnread,
          ConversationFilter.active => c.bidStatus == 'BID_ACCEPTED',
          ConversationFilter.done   => c.bidStatus == 'DELIVERY_CONFIRMED',
        };
        final q = searchQuery.toLowerCase();
        final matchSearch = q.isEmpty ||
            c.otherParticipant.name.toLowerCase().contains(q) ||
            (c.tripOrigin?.toLowerCase().contains(q) ?? false) ||
            (c.tripDestination?.toLowerCase().contains(q) ?? false);
        return matchFilter && matchSearch;
      }).toList();

  ConversationListLoaded copyWithFilter({
    required ConversationFilter filter,
    required String searchQuery,
  }) =>
      ConversationListLoaded(conversations, filter: filter, searchQuery: searchQuery);
}

class ConversationListError extends ConversationListState {
  final AppException error;
  const ConversationListError(this.error);
}
```

- [ ] **Step 2: Vérifier que les tests existants passent encore**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/messaging/bloc/conversation_list_bloc_test.dart -v
```

Attendu : tous les tests `PASS` (le constructeur `ConversationListLoaded(list)` reste valide grâce aux params optionnels).

- [ ] **Step 3: Commit**

```bash
git add lib/features/messaging/bloc/conversation_list/conversation_list_state.dart
git commit -m "feat(messaging): ConversationFilter enum + displayed getter sur ConversationListLoaded"
```

---

## Task 2 — Nouveaux events BLoC

**Files:**
- Modify: `lib/features/messaging/bloc/conversation_list/conversation_list_event.dart`

- [ ] **Step 1: Ajouter les deux nouveaux events à la fin du fichier**

```dart
abstract class ConversationListEvent {
  const ConversationListEvent();
}

class ConversationsLoadRequested extends ConversationListEvent {
  const ConversationsLoadRequested();
}

class ConversationsUnreadUpdated extends ConversationListEvent {
  final Map<String, int> unreadMap; // firestoreConvId → count
  const ConversationsUnreadUpdated(this.unreadMap);
}

/// Swipe-to-delete from the list: calls the API then removes locally.
class ConversationDeleteRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationDeleteRequested(this.conversationId);
}

/// Silent local removal after the ChatBloc has already called the API.
class ConversationRemovedLocally extends ConversationListEvent {
  final String conversationId;
  const ConversationRemovedLocally(this.conversationId);
}

/// Pill de filtre ou saisie dans le champ de recherche.
class ConversationFilterChanged extends ConversationListEvent {
  final ConversationFilter filter;
  final String searchQuery;
  const ConversationFilterChanged({required this.filter, required this.searchQuery});
}

/// Swipe-to-archive : retire localement sans appel API.
class ConversationArchiveRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationArchiveRequested(this.conversationId);
}
```

Note : `ConversationFilter` est importé via `conversation_list_state.dart` — ajouter l'import en tête de fichier :

```dart
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
```

- [ ] **Step 2: Vérifier que le projet compile**

```bash
flutter analyze lib/features/messaging/bloc/conversation_list/
```

Attendu : aucune erreur.

- [ ] **Step 3: Commit**

```bash
git add lib/features/messaging/bloc/conversation_list/conversation_list_event.dart
git commit -m "feat(messaging): events ConversationFilterChanged + ConversationArchiveRequested"
```

---

## Task 3 — Handlers BLoC + tests

**Files:**
- Modify: `lib/features/messaging/bloc/conversation_list/conversation_list_bloc.dart`
- Modify: `test/features/messaging/bloc/conversation_list_bloc_test.dart`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter ces blocs dans le `group('ConversationListBloc', ...)` existant de `conversation_list_bloc_test.dart` :

```dart
blocTest<ConversationListBloc, ConversationListState>(
  'ConversationFilterChanged met à jour filter et searchQuery dans le state',
  build: () {
    when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
    when(() => firestoreRepo.perConversationUnreadStream(any()))
        .thenAnswer((_) => const Stream.empty());
    return ConversationListBloc(convRepo, firestoreRepo);
  },
  act: (b) async {
    b.add(const ConversationsLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    b.add(const ConversationFilterChanged(
      filter: ConversationFilter.unread,
      searchQuery: 'test',
    ));
  },
  expect: () => [
    isA<ConversationListLoading>(),
    isA<ConversationListLoaded>()
        .having((s) => s.filter, 'filter', ConversationFilter.all)
        .having((s) => s.searchQuery, 'searchQuery', ''),
    isA<ConversationListLoaded>()
        .having((s) => s.filter, 'filter', ConversationFilter.unread)
        .having((s) => s.searchQuery, 'searchQuery', 'test'),
  ],
);

blocTest<ConversationListBloc, ConversationListState>(
  'ConversationArchiveRequested retire la conversation localement',
  build: () {
    when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
    when(() => firestoreRepo.perConversationUnreadStream(any()))
        .thenAnswer((_) => const Stream.empty());
    return ConversationListBloc(convRepo, firestoreRepo);
  },
  act: (b) async {
    b.add(const ConversationsLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    b.add(const ConversationArchiveRequested('conv-1'));
  },
  expect: () => [
    isA<ConversationListLoading>(),
    isA<ConversationListLoaded>().having((s) => s.conversations.length, 'length', 1),
    isA<ConversationListLoaded>().having((s) => s.conversations.length, 'length', 0),
  ],
);

blocTest<ConversationListBloc, ConversationListState>(
  'filter est préservé après ConversationsUnreadUpdated',
  build: () {
    when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
    when(() => firestoreRepo.perConversationUnreadStream(any()))
        .thenAnswer((_) => const Stream.empty());
    return ConversationListBloc(convRepo, firestoreRepo);
  },
  act: (b) async {
    b.add(const ConversationsLoadRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    b.add(const ConversationFilterChanged(
      filter: ConversationFilter.unread,
      searchQuery: '',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    b.add(const ConversationsUnreadUpdated({'conv_bid-1': 2}));
  },
  expect: () => [
    isA<ConversationListLoading>(),
    isA<ConversationListLoaded>(),
    isA<ConversationListLoaded>()
        .having((s) => s.filter, 'filter', ConversationFilter.unread),
    isA<ConversationListLoaded>()
        .having((s) => s.filter, 'filter', ConversationFilter.unread),
  ],
);
```

- [ ] **Step 2: Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/messaging/bloc/conversation_list_bloc_test.dart -v
```

Attendu : les 3 nouveaux tests `FAIL` (handlers non encore implémentés).

- [ ] **Step 3: Mettre à jour le BLoC**

Remplacer le contenu de `conversation_list_bloc.dart` :

```dart
import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  final ConversationRepository _repository;
  final FirestoreChatRepository _firestoreRepo;

  StreamSubscription<Map<String, int>>? _unreadSub;
  List<ConversationModel>? _loaded;

  // Préservés entre les rechargements pour ne pas perdre le filtre actif.
  ConversationFilter _currentFilter = ConversationFilter.all;
  String _currentSearchQuery = '';

  ConversationListBloc(this._repository, this._firestoreRepo)
      : super(const ConversationListInitial()) {
    on<ConversationsLoadRequested>(_onLoad);
    on<ConversationsUnreadUpdated>(_onUnreadUpdated);
    on<ConversationDeleteRequested>(_onDelete);
    on<ConversationRemovedLocally>(_onRemovedLocally);
    on<ConversationFilterChanged>(_onFilterChanged);
    on<ConversationArchiveRequested>(_onArchive);
  }

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(const ConversationListLoading());
    try {
      final conversations = await _repository.getConversations();
      _loaded = conversations;
      emit(ConversationListLoaded(
        conversations,
        filter: _currentFilter,
        searchQuery: _currentSearchQuery,
      ));
    } catch (e) {
      emit(ConversationListError(unwrapDioError(e)));
      return;
    }

    try {
      await _unreadSub?.cancel();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final validIds = _loaded!
            .map((c) => c.firestoreConversationId)
            .where((id) => id.isNotEmpty)
            .toSet();
        unawaited(_firestoreRepo.cleanupOrphanUnreadCounters(
          currentUserUid: uid,
          validFirestoreIds: validIds,
        ));

        _unreadSub = _firestoreRepo
            .perConversationUnreadStream(uid)
            .listen((map) => add(ConversationsUnreadUpdated(map)));
      }
    } catch (_) {
      // Firebase not available (e.g. in tests) — skip stream subscription
    }
  }

  void _onUnreadUpdated(
    ConversationsUnreadUpdated event,
    Emitter<ConversationListState> emit,
  ) {
    final conversations = _loaded;
    if (conversations == null) return;
    final updated = conversations.map((c) {
      final count = event.unreadMap[c.firestoreConversationId] ?? 0;
      return c.copyWith(hasUnread: count > 0, unreadCount: count);
    }).toList();
    _loaded = updated;
    emit(ConversationListLoaded(
      updated,
      filter: _currentFilter,
      searchQuery: _currentSearchQuery,
    ));
  }

  Future<void> _onDelete(
    ConversationDeleteRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    String firestoreConvId = '';
    for (final c in _loaded ?? const <ConversationModel>[]) {
      if (c.id == event.conversationId) {
        firestoreConvId = c.firestoreConversationId;
        break;
      }
    }

    _removeFromLoaded(event.conversationId, emit);

    if (firestoreConvId.isNotEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          await _firestoreRepo.markConversationRead(firestoreConvId, uid);
        }
      } catch (_) {}
    }

    try {
      await _repository.deleteConversation(event.conversationId);
    } catch (_) {
      add(const ConversationsLoadRequested());
    }
  }

  void _onRemovedLocally(
    ConversationRemovedLocally event,
    Emitter<ConversationListState> emit,
  ) {
    _removeFromLoaded(event.conversationId, emit);
  }

  void _onFilterChanged(
    ConversationFilterChanged event,
    Emitter<ConversationListState> emit,
  ) {
    _currentFilter = event.filter;
    _currentSearchQuery = event.searchQuery;
    if (state is ConversationListLoaded) {
      emit((state as ConversationListLoaded)
          .copyWithFilter(filter: event.filter, searchQuery: event.searchQuery));
    }
  }

  void _onArchive(
    ConversationArchiveRequested event,
    Emitter<ConversationListState> emit,
  ) {
    _removeFromLoaded(event.conversationId, emit);
  }

  void _removeFromLoaded(String id, Emitter<ConversationListState> emit) {
    if (_loaded == null) return;
    _loaded = _loaded!.where((c) => c.id != id).toList();
    emit(ConversationListLoaded(
      _loaded!,
      filter: _currentFilter,
      searchQuery: _currentSearchQuery,
    ));
  }

  @override
  Future<void> close() {
    _unreadSub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Lancer les tests BLoC — tous doivent passer**

```bash
flutter test test/features/messaging/bloc/conversation_list_bloc_test.dart -v
```

Attendu : tous `PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/messaging/bloc/conversation_list/conversation_list_bloc.dart \
        lib/features/messaging/bloc/conversation_list/conversation_list_event.dart \
        test/features/messaging/bloc/conversation_list_bloc_test.dart
git commit -m "feat(messaging): handlers ConversationFilterChanged + ConversationArchiveRequested"
```

---

## Task 4 — Ajouter flutter_slidable

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Ajouter la dépendance dans pubspec.yaml**

Dans la section `dependencies:`, ajouter après `flutter_animate: ^4.5.0` :

```yaml
  flutter_slidable: ^3.1.0
```

- [ ] **Step 2: Installer**

```bash
flutter pub get
```

Attendu : `flutter_slidable 3.x.x` dans le résultat, pas d'erreur de résolution.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): ajouter flutter_slidable ^3.1.0"
```

---

## Task 5 — Réécriture de ConversationListScreen

**Files:**
- Modify: `lib/features/messaging/presentation/conversation_list_screen.dart`

- [ ] **Step 1: Remplacer le fichier entièrement**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    context.read<ConversationListBloc>().add(const ConversationsLoadRequested());
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
      body: BlocBuilder<ConversationListBloc, ConversationListState>(
        builder: (context, state) {
          final filter =
              state is ConversationListLoaded ? state.filter : ConversationFilter.all;
          final searchQuery =
              state is ConversationListLoaded ? state.searchQuery : '';

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
        mascotte: DonyMascotteType.assis,
        icon: Icons.wifi_off_rounded,
        title: 'Erreur de chargement',
        description: ErrorPresenter.resolve(state.error).message,
        actionLabel: 'Réessayer',
        onAction: () =>
            context.read<ConversationListBloc>().add(const ConversationsLoadRequested()),
      );
    }

    if (state is ConversationListLoaded) {
      if (state.displayed.isEmpty) {
        return DonyEmptyState(
          mascotte: DonyMascotteType.assis,
          title: state.searchQuery.isNotEmpty
              ? 'Aucun résultat'
              : 'Aucun message',
          description: state.searchQuery.isNotEmpty
              ? 'Aucune conversation ne correspond à « ${state.searchQuery} ».'
              : 'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
        );
      }

      final items = _buildGroupedItems(state.displayed);

      return RefreshIndicator(
        color: cs.primary,
        onRefresh: () async =>
            context.read<ConversationListBloc>().add(const ConversationsLoadRequested()),
        child: ListView.builder(
          padding: EdgeInsets.zero,
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
                  delay: Duration(milliseconds: 40 * index),
                  duration: 260.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideY(
                  begin: 0.03,
                  end: 0,
                  delay: Duration(milliseconds: 40 * index),
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
    final local =
        c.lastMessageAt!.isUtc ? c.lastMessageAt!.toLocal() : c.lastMessageAt!;
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      today.add(c);
    } else if (diff.inDays < 7) {
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
              DonySpacing.lg, DonySpacing.md, DonySpacing.base, 0,
            ),
            child: Row(
              children: [
                Text('Messages', style: tt.headlineLarge),
                const Spacer(),
                TextButton(
                  onPressed: isSearching
                      ? () {
                          searchController.clear();
                          context.read<ConversationListBloc>().add(
                                ConversationFilterChanged(
                                  filter: activeFilter,
                                  searchQuery: '',
                                ),
                              );
                        }
                      : () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                    ),
                  ),
                  child: Text(
                    isSearching ? 'Annuler' : 'Modifier',
                    style: tt.labelMedium?.copyWith(
                      color: isSearching ? cs.onSurfaceVariant : cs.primary,
                    ),
                  ),
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
                    ConversationFilterChanged(
                      filter: activeFilter,
                      searchQuery: q,
                    ),
                  ),
              textInputAction: TextInputAction.search,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation…',
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: cs.onSurfaceVariant),
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
                      DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.sm,
                    ),
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'Tous',
                          isActive: activeFilter == ConversationFilter.all,
                          onTap: () => context.read<ConversationListBloc>().add(
                                ConversationFilterChanged(
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
                                ConversationFilterChanged(
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
                                ConversationFilterChanged(
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
                                ConversationFilterChanged(
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
        DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.xs,
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
            onPressed: (_) => context
                .read<ConversationListBloc>()
                .add(ConversationArchiveRequested(conversation.id)),
            backgroundColor: cs.warning,
            foregroundColor: cs.onPrimary,
            icon: Icons.archive_outlined,
            label: 'Archiver',
          ),
          SlidableAction(
            onPressed: (_) => context
                .read<ConversationListBloc>()
                .add(ConversationDeleteRequested(conversation.id)),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
          ),
        ],
      ),
      child: _ConversationTile(conversation: conversation),
    );
  }
}

// ── Tuile conversation ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final participant = conversation.otherParticipant;
    final unread = conversation.hasUnread;

    return Material(
      color: unread ? const Color(0xFFF4F7FF) : cs.surface,
      child: InkWell(
        onTap: () => context.push(
          '/conversations/${conversation.id}',
          extra: conversation,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DonyAvatar(
                name: participant.name.isNotEmpty ? participant.name : '?',
                imageUrl: participant.avatarUrl,
                size: DonyAvatarSize.md,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + timestamp
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            participant.name.isNotEmpty
                                ? participant.name
                                : 'Utilisateur',
                            style: tt.titleLarge?.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null) ...[
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            _formatTime(conversation.lastMessageAt!),
                            style: tt.labelSmall?.copyWith(
                              color:
                                  unread ? cs.primary : cs.onSurfaceVariant,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Trip label
                    if (conversation.tripLabel != null) ...[
                      const SizedBox(height: 3),
                      _TripLabel(
                          label: conversation.tripLabel!, cs: cs, tt: tt),
                    ],
                    const SizedBox(height: 3),
                    // Preview + badge/check
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _previewText(),
                            style: tt.bodySmall?.copyWith(
                              color: unread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        if (unread && conversation.unreadCount > 0)
                          _UnreadBadge(
                              count: conversation.unreadCount,
                              cs: cs,
                              tt: tt)
                        else if (!unread && conversation.lastMessageAt != null)
                          Text(
                            '✓✓',
                            style: tt.labelSmall
                                ?.copyWith(color: cs.success),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText() {
    final preview = conversation.lastMessagePreview;
    if (preview == null || preview.isEmpty) return 'Conversation démarrée';
    return preview;
  }

  String _formatTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'maintenant';
    final isToday = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (isToday) return DateFormat('HH:mm').format(local);
    if (diff.inDays < 7) return DateFormat('EEE', 'fr').format(local);
    return DateFormat('d MMM', 'fr').format(local);
  }
}

// ── Trip label ─────────────────────────────────────────────────────────────────

class _TripLabel extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  const _TripLabel({required this.label, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flight_rounded, size: 11, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Flexible(
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Badge non lu ───────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  final TextTheme tt;

  const _UnreadBadge({required this.count, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

- [ ] **Step 2: Vérifier la compilation**

```bash
flutter analyze lib/features/messaging/presentation/conversation_list_screen.dart
```

Attendu : aucune erreur (warnings autorisés temporairement).

- [ ] **Step 3: Commit**

```bash
git add lib/features/messaging/presentation/conversation_list_screen.dart pubspec.yaml
git commit -m "feat(messaging): redesign ConversationListScreen — header 3 blocs + filtres + swipe archive"
```

---

## Task 6 — Mettre à jour les tests widget

**Files:**
- Modify: `test/features/messaging/presentation/conversation_list_screen_test.dart`

- [ ] **Step 1: Lancer les tests actuels pour identifier les cassés**

```bash
flutter test test/features/messaging/presentation/conversation_list_screen_test.dart -v
```

Certains tests échoueront car :
- `find.byType(ListView)` → le `RefreshIndicator` wrape maintenant un `ListView.builder` (devrait encore passer)
- `find.byType(Divider)` → il n'y a plus de `Divider` entre les tuiles (section labels à la place)
- `ConversationListLoaded([])` → compile encore (params optionnels), mais `find.text('Aucun message')` doit passer

- [ ] **Step 2: Remplacer le contenu du fichier de tests**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/conversation_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Aïcha Bah');
final _conv = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  lastMessagePreview: 'Bonjour !',
  lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
  hasUnread: true,
  unreadCount: 2,
);
final _convNoUnread = ConversationModel(
  id: 'conv-2',
  bidId: 'bid-2',
  firestoreConversationId: 'conv_bid-2',
  otherParticipant: ParticipantModel(id: 'uid-2', name: 'Mamadou'),
  lastMessagePreview: 'À bientôt',
  lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
  hasUnread: false,
);
final _convNow = ConversationModel(
  id: 'conv-5',
  bidId: 'bid-5',
  firestoreConversationId: 'conv_bid-5',
  otherParticipant: ParticipantModel(id: 'uid-5', name: 'Kadiatou'),
  lastMessagePreview: 'Maintenant',
  lastMessageAt: DateTime.now(),
  hasUnread: false,
);
final _convDaysAgo = ConversationModel(
  id: 'conv-3',
  bidId: 'bid-3',
  firestoreConversationId: 'conv_bid-3',
  otherParticipant: ParticipantModel(id: 'uid-3', name: 'Fatoumata'),
  lastMessagePreview: 'À demain',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 3)),
  hasUnread: false,
);
final _convWeeksAgo = ConversationModel(
  id: 'conv-4',
  bidId: 'bid-4',
  firestoreConversationId: 'conv_bid-4',
  otherParticipant: ParticipantModel(id: 'uid-4', name: 'Oumar'),
  lastMessagePreview: 'Merci',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 10)),
  hasUnread: false,
);

GoRouter _buildRouter(ConversationListBloc bloc) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<ConversationListBloc>.value(
            value: bloc,
            child: const ConversationListScreen(),
          ),
        ),
        GoRoute(
          path: '/conversations/:id',
          builder: (_, __) => const Scaffold(body: Text('Chat')),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, ConversationListBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _buildRouter(bloc),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockConversationListBloc bloc;

  setUp(() {
    bloc = MockConversationListBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => bloc.close());

  group('ConversationListScreen', () {
    testWidgets('affiche le header Messages dans tous les états', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoading());
      await _pump(tester, bloc);

      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows loading indicator when state is Loading', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoading());
      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no conversations', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Aucun message'), findsOneWidget);
    });

    testWidgets('renders conversation tile with participant name', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
      expect(find.text('Bonjour !'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      when(() => bloc.state).thenReturn(
          ConversationListError(NetworkException('Erreur réseau')));
      await _pump(tester, bloc);

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('retry button dispatches ConversationsLoadRequested',
        (tester) async {
      when(() => bloc.state).thenReturn(
          ConversationListError(NetworkException('Erreur réseau')));
      await _pump(tester, bloc);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => bloc.add(const ConversationsLoadRequested()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('affiche section AUJOURD\'HUI pour message récent', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text("AUJOURD'HUI"), findsOneWidget);
    });

    testWidgets('affiche section CETTE SEMAINE pour message de 3 jours',
        (tester) async {
      await initializeDateFormatting('fr');
      when(() => bloc.state)
          .thenReturn(ConversationListLoaded([_convDaysAgo]));
      await _pump(tester, bloc);

      expect(find.text('CETTE SEMAINE'), findsOneWidget);
      expect(find.text('Fatoumata'), findsOneWidget);
    });

    testWidgets('affiche section PLUS ANCIEN pour message de 10 jours',
        (tester) async {
      await initializeDateFormatting('fr');
      when(() => bloc.state)
          .thenReturn(ConversationListLoaded([_convWeeksAgo]));
      await _pump(tester, bloc);

      expect(find.text('PLUS ANCIEN'), findsOneWidget);
      expect(find.text('Oumar'), findsOneWidget);
    });

    testWidgets('affiche pills de filtre quand searchQuery est vide',
        (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Non lus'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Terminés'), findsOneWidget);
    });

    testWidgets('taper dans le champ dispatch ConversationFilterChanged',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      await tester.enterText(find.byType(TextField), 'Dakar');
      await tester.pump();

      verify(() => bloc.add(const ConversationFilterChanged(
            filter: ConversationFilter.all,
            searchQuery: 'Dakar',
          ))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping conversation tile navigates to chat', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.tap(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('_formatTime shows maintenant for sub-1-minute message',
        (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convNow]));
      await _pump(tester, bloc);

      expect(find.text('Kadiatou'), findsOneWidget);
      expect(find.text('maintenant'), findsOneWidget);
    });

    testWidgets('empty state adapté quand searchQuery non vide', (tester) async {
      when(() => bloc.state).thenReturn(
        const ConversationListLoaded([], searchQuery: 'xyz'),
      );
      await _pump(tester, bloc);

      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('pull-to-refresh dispatches ConversationsLoadRequested',
        (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => bloc.add(const ConversationsLoadRequested()))
          .called(greaterThanOrEqualTo(1));
    });
  });
}
```

- [ ] **Step 3: Lancer tous les tests — tous doivent passer**

```bash
flutter test test/features/messaging/ -v
```

Attendu : tous `PASS`.

- [ ] **Step 4: Couverture globale**

```bash
flutter test --coverage
```

Attendu : couverture ≥ 90 % (vérifier `coverage/lcov.info` pour le feature messaging).

- [ ] **Step 5: Commit final**

```bash
git add test/features/messaging/presentation/conversation_list_screen_test.dart
git commit -m "test(messaging): mettre à jour tests widget ConversationListScreen post-redesign"
```

---

## Vérification finale

```bash
flutter analyze && flutter test
```

Attendu : aucune erreur d'analyse, tous les tests `PASS`.
