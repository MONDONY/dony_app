import 'dart:async';

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

  ConversationListBloc(this._repository, this._firestoreRepo)
      : super(const ConversationListInitial()) {
    on<ConversationsLoadRequested>(_onLoad);
    on<ConversationsUnreadUpdated>(_onUnreadUpdated);
    on<ConversationDeleteRequested>(_onDelete);
    on<ConversationRemovedLocally>(_onRemovedLocally);
  }

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(const ConversationListLoading());
    try {
      final conversations = await _repository.getConversations();
      _loaded = conversations;
      emit(ConversationListLoaded(conversations));
    } catch (_) {
      emit(const ConversationListError(
          'Impossible de charger les conversations'));
      return;
    }

    try {
      await _unreadSub?.cancel();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        // One-shot self-healing: clear unread_* counters for conversations
        // that no longer exist in the user's list (orphans left by previous
        // deletions before the cleanup logic existed).
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
    emit(ConversationListLoaded(updated));
  }

  Future<void> _onDelete(
    ConversationDeleteRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    // Capture the firestoreConversationId BEFORE removing — the unread
    // counter cleanup needs it.
    String firestoreConvId = '';
    for (final c in _loaded ?? const <ConversationModel>[]) {
      if (c.id == event.conversationId) {
        firestoreConvId = c.firestoreConversationId;
        break;
      }
    }

    // Remove from the list synchronously, BEFORE any await. This is required
    // by the Dismissible contract: once a tile is dismissed, the underlying
    // model must disappear in the same frame, otherwise Flutter throws
    // "A dismissed Dismissible widget is still part of the tree."
    _removeFromLoaded(event.conversationId, emit);

    // Reset the unread counter so userMeta.totalUnreadMessages stops
    // reflecting the now-deleted conversation. Done after the synchronous
    // emit so the UI stays consistent.
    if (firestoreConvId.isNotEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          await _firestoreRepo.markConversationRead(firestoreConvId, uid);
        }
      } catch (_) {
        // Non-fatal: deletion can still proceed even if Firestore is offline
        // or Firebase is not available (e.g. tests).
      }
    }

    try {
      await _repository.deleteConversation(event.conversationId);
    } catch (_) {
      // Reload on failure to restore the removed item
      add(const ConversationsLoadRequested());
    }
  }

  void _onRemovedLocally(
    ConversationRemovedLocally event,
    Emitter<ConversationListState> emit,
  ) {
    _removeFromLoaded(event.conversationId, emit);
  }

  void _removeFromLoaded(String id, Emitter<ConversationListState> emit) {
    if (_loaded == null) return;
    _loaded = _loaded!.where((c) => c.id != id).toList();
    emit(ConversationListLoaded(_loaded!));
  }

  @override
  Future<void> close() {
    _unreadSub?.cancel();
    return super.close();
  }
}
