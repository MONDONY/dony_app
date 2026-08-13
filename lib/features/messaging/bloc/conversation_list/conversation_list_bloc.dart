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
  StreamSubscription<User?>? _authSub;
  List<ConversationModel>? _loaded;
  List<ConversationModel> _archived = [];

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
    on<ConversationUnarchiveRequested>(_onUnarchive);

    // Ce Bloc est un singleton GetIt (jamais fermé via BlocProvider.value) :
    // sans ce listener, _unreadSub survit à un signOut() et Firestore renvoie
    // permission-denied dès qu'il tente de lire userMeta/{ancien-uid}.
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) {
          unawaited(_unreadSub?.cancel());
          _unreadSub = null;
        }
      });
    } catch (_) {
      // Firebase not available (e.g. in tests) — skip auth-state subscription
    }
  }

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(const ConversationListLoading());
    try {
      final conversations = await _repository.getConversations();
      List<ConversationModel> archived = [];
      try {
        archived = await _repository.getArchivedConversations();
      } catch (_) {
        // Archives non critiques — échec silencieux
      }
      _loaded = conversations;
      _archived = archived;
      emit(
        ConversationListLoaded(
          conversations,
          archivedConversations: archived,
          filter: _currentFilter,
          searchQuery: _currentSearchQuery,
        ),
      );
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
        unawaited(
          _firestoreRepo.cleanupOrphanUnreadCounters(
            currentUserUid: uid,
            validFirestoreIds: validIds,
          ),
        );

        _unreadSub = _firestoreRepo
            .perConversationUnreadStream(uid)
            .listen(
              (map) => add(ConversationsUnreadUpdated(map)),
              onError: (_) {
                // Session invalidée entre-temps (ex: signOut concurrent) — pas d'état d'erreur bloquant.
              },
            );
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
    if (conversations == null) {
      return;
    }
    final updated = conversations.map((c) {
      final count = event.unreadMap[c.firestoreConversationId] ?? 0;
      return c.copyWith(hasUnread: count > 0, unreadCount: count);
    }).toList();
    _loaded = updated;
    emit(
      ConversationListLoaded(
        updated,
        archivedConversations: _archived,
        filter: _currentFilter,
        searchQuery: _currentSearchQuery,
      ),
    );
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
    // Fields already updated — _onLoad will emit with the new values when ready.
    if (state is ConversationListLoaded) {
      emit(
        (state as ConversationListLoaded).copyWithFilter(
          filter: event.filter,
          searchQuery: event.searchQuery,
        ),
      );
    }
  }

  Future<void> _onArchive(
    ConversationArchiveRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    if (_loaded == null) {
      return;
    }
    final conv = _loaded!
        .where((c) => c.id == event.conversationId)
        .firstOrNull;
    if (conv != null) {
      _archived = [..._archived, conv];
    }
    _removeFromLoaded(event.conversationId, emit);
    try {
      await _repository.archiveConversation(event.conversationId);
    } catch (_) {
      add(const ConversationsLoadRequested());
    }
  }

  Future<void> _onUnarchive(
    ConversationUnarchiveRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    final conv = _archived
        .where((c) => c.id == event.conversationId)
        .firstOrNull;
    if (conv == null) {
      return;
    }
    _archived = _archived.where((c) => c.id != event.conversationId).toList();
    _loaded = [conv, ...(_loaded ?? [])];
    emit(
      ConversationListLoaded(
        _loaded!,
        archivedConversations: _archived,
        filter: _currentFilter,
        searchQuery: _currentSearchQuery,
      ),
    );
    try {
      await _repository.unarchiveConversation(event.conversationId);
    } catch (_) {
      add(const ConversationsLoadRequested());
    }
  }

  void _removeFromLoaded(String id, Emitter<ConversationListState> emit) {
    if (_loaded == null) {
      return;
    }
    _loaded = _loaded!.where((c) => c.id != id).toList();
    emit(
      ConversationListLoaded(
        _loaded!,
        archivedConversations: _archived,
        filter: _currentFilter,
        searchQuery: _currentSearchQuery,
      ),
    );
  }

  @override
  Future<void> close() {
    _unreadSub?.cancel();
    _authSub?.cancel();
    return super.close();
  }
}
