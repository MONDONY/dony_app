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
    _removeFromLoaded(event.conversationId, emit);
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
