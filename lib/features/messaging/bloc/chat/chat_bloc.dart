import 'dart:async';
import 'dart:math' as math;
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _DeletedByOtherParty extends ChatEvent {
  const _DeletedByOtherParty();
}

/// Lecture à l'unité d'un message cité terminée : [message] `null` s'il est
/// introuvable.
class _QuoteResolved extends ChatEvent {
  final String id;
  final MessageModel? message;
  const _QuoteResolved(this.id, this.message);
}

typedef _InquiryParent = ({
  String? askerId,
  bool quotaLifted,
  bool exists,
  bool fromCache,
});

/// Nouveau compteur de messages du demandeur lu dans Firestore.
class _InquirySentChanged extends ChatEvent {
  final int sent;
  const _InquirySentChanged(this.sent);
}

/// Le document parent ou le compteur a changé : l'état est reconstruit.
class _InquiryChanged extends ChatEvent {
  const _InquiryChanged();
}

/// Plafond de messages du demandeur quand le back ne le sert pas (même valeur
/// que `InquiryPolicy.MESSAGE_LIMIT` du back).
const int kInquiryDefaultMessageLimit = 10;

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final FirestoreChatRepository _firestoreRepo;
  final ConversationRepository _conversationRepo;
  final AnalyticsService _analytics;

  /// Callables de modification / suppression (FLUTTER-MG). `null` hors
  /// injection : la demande échoue alors proprement en « indisponible ».
  final MessageEditRepository? _editRepo;
  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<bool>? _deletedSub;

  // Lecture pendant que le fil est ouvert (FLUTTER-NX, FLUTTER-NY) : la
  // fonction `onNewMessage` incrémente `unread_{conv}` à chaque message reçu,
  // sans savoir que le fil est affiché. Marquer lu à la seule ouverture
  // laissait tous les messages reçus ensuite comptés comme non lus.
  StreamSubscription<Map<String, int>>? _unreadSub;
  Timer? _markReadTimer;
  String _currentUserUid = '';
  int _unreadHere = 0;
  bool _appVisible = true;
  final Duration _markReadDelay;

  // Fil courant, conservé pour reconstruire l'état quand la réponse en
  // cours ou une citation résolue change (FLUTTER-86).
  String _firestoreConversationId = '';
  bool _readOnly = false;
  List<MessageModel> _messages = const [];
  MessageModel? _replyingTo;
  final Map<String, MessageModel?> _quoted = {};
  final Set<String> _pendingQuotes = {};

  // Photos (FLUTTER-B4).
  String _conversationId = '';

  /// Conversation relue après la levée du plafond d'un fil de questions ;
  /// `null` tant que le fil n'a pas basculé en direct.
  ConversationModel? _refreshedConversation;
  bool _refreshedForLift = false;

  /// Une relecture est en cours : une seule `getConversation` par levée, quel
  /// que soit le déclencheur (flux parent ou retour de la fiche du trajet).
  bool _refreshInFlight = false;

  /// Un déclencheur est arrivé pendant la lecture (rien lancé) : à reprendre
  /// si cette lecture ne dit rien d'utile. Borne les reprises.
  bool _refreshMissed = false;

  /// Compté à chaque reverrouillage : une relecture lancée avant est périmée.
  int _lockEpoch = 0;
  bool _mediaAllowed = false;
  List<PendingChatImage> _pendingImages = const [];
  int _localImageSeq = 0;

  // Conversation de questions avant réservation (quota non levé) : seul le
  // texte est écrit dans le fil (règles Firestore), pour les deux parties.
  bool _inquiryLimited = false;

  // L'utilisateur est le demandeur d'une telle conversation : ses messages
  // sont comptés et plafonnés. Le créateur de l'annonce ne l'est jamais.
  bool _inquiryCounting = false;
  int _inquiryLimit = kInquiryDefaultMessageLimit;
  int _inquirySent = 0;
  String _announcementId = '';
  StreamSubscription<int>? _inquirySub;
  StreamSubscription<_InquiryParent>? _inquiryParentSub;

  // Le document parent est suivi tant que le fil a été ouvert limité, même
  // après une levée : le back peut reverrouiller le quota.
  bool _inquiryWatching = false;

  // Complété à la première lecture (serveur) du document parent : demandeur
  // connu. Tout envoi en attend la fin, jamais de chemin ordinaire « par
  // défaut ».
  Completer<void> _inquiryParentKnown = Completer<void>()..complete();

  // Complété à la première valeur du compteur du demandeur.
  Completer<void> _inquirySentKnown = Completer<void>()..complete();
  int _inquiryGeneration = 0;
  bool _closing = false;
  final Duration _inquiryParentTimeout;
  final Duration _inquiryReconcileTimeout;

  // Envois d'une INQUIRY limitée traités l'un après l'autre : deux envois
  // rapprochés liraient sinon le même compteur.
  Future<void> _sendChain = Future<void>.value();

  ChatBloc(
    this._firestoreRepo,
    this._conversationRepo,
    this._analytics, {
    MessageEditRepository? editRepository,
    Duration markReadDelay = const Duration(milliseconds: 500),
    Duration inquiryParentTimeout = const Duration(seconds: 5),
    Duration inquiryReconcileTimeout = const Duration(seconds: 10),
  }) : _editRepo = editRepository,
       _markReadDelay = markReadDelay,
       _inquiryParentTimeout = inquiryParentTimeout,
       _inquiryReconcileTimeout = inquiryReconcileTimeout,
       super(const ChatInitial()) {
    on<ChatSubscribeRequested>(_onSubscribe);
    on<ChatTextSendRequested>(_onSendText);
    on<ChatImageSendRequested>(_onSendImage);
    on<ChatImageRetryRequested>(_onRetryImage);
    on<ChatImageDiscardRequested>(_onDiscardImage);
    on<ChatLocationSendRequested>(_onSendLocation);
    on<ChatConversationDeleteRequested>(_onDeleteConversation);
    on<_DeletedByOtherParty>(_onDeletedByOtherParty);
    on<ChatReplyStarted>(_onReplyStarted);
    on<ChatReplyCancelled>(_onReplyCancelled);
    on<_QuoteResolved>(_onQuoteResolved);
    on<ChatMessageEditRequested>(_onEditMessage);
    on<ChatMessageDeleteRequested>(_onDeleteMessage);
    on<ChatAppVisibilityChanged>(_onAppVisibilityChanged);
    on<_InquirySentChanged>(_onInquirySentChanged);
    on<_InquiryChanged>(_onInquiryChanged);
    on<ChatConversationRefreshRequested>(_onConversationRefresh);
  }

  /// Compteur affichable : demandeur connu et première valeur reçue.
  bool get _inquiryShown => _inquiryCounting && _inquirySentKnown.isCompleted;

  int get _inquiryRemaining =>
      (_inquiryLimit - _inquirySent).clamp(0, _inquiryLimit);

  void _onInquirySentChanged(
    _InquirySentChanged event,
    Emitter<ChatState> emit,
  ) {
    if (!_inquiryCounting) return;
    _inquirySent = event.sent;
    if (!_inquirySentKnown.isCompleted) _inquirySentKnown.complete();
    if (_syncWithThread()) emit(_snapshot());
  }

  void _onInquiryChanged(_InquiryChanged event, Emitter<ChatState> emit) {
    if (_syncWithThread()) emit(_snapshot());
  }

  /// Conversation relue après la levée du plafond : le back rend alors le
  /// `bidId` et le type ordinaire, que l'écran, ouvert sur la photo prise à
  /// l'ouverture, ne connaît pas. Une seule lecture par levée ; un échec laisse
  /// l'ancien modèle (journal) et la prochaine demande réessaie.
  Future<void> _onConversationRefresh(
    ChatConversationRefreshRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (_conversationId.isEmpty || _refreshedForLift) return;
    if (_refreshInFlight) {
      _refreshMissed = true;
      return;
    }
    final generation = _inquiryGeneration;
    final epoch = _lockEpoch;
    var retry = false;
    _refreshMissed = false;
    _refreshInFlight = true;
    try {
      final fresh = await _conversationRepo.getConversation(_conversationId);
      if (isClosed || generation != _inquiryGeneration) return;
      if (epoch != _lockEpoch) {
        // Reverrouillé pendant la lecture : résultat périmé, ignoré.
        retry = true;
        return;
      }
      if (fresh.isInquiry && !fresh.inquiryQuotaLifted) {
        retry = true;
        return;
      }
      _refreshedForLift = true;
      if (_inquiryLimited) _liftInquiry();
      _refreshedConversation = fresh;
      if (_syncWithThread()) emit(_snapshot());
    } catch (e) {
      AppLog.warn(
        'chat.conversation_refresh_failed',
        data: {'reason': _reasonOf(e)},
      );
    } finally {
      _refreshInFlight = false;
      // Un déclencheur arrivé pendant la lecture n'a pas pu en lancer une : il
      // reprend ici si ce résultat n'a rien appris.
      if (retry &&
          _refreshMissed &&
          !isClosed &&
          !_inquiryLimited &&
          !_refreshedForLift) {
        add(const ChatConversationRefreshRequested());
      }
    }
  }

  /// Quota levé : plus de compteur ni de verrou, les envois en attente
  /// repartent en ordinaire. Le document parent reste suivi (reverrouillage).
  void _liftInquiry() {
    if (_inquiryLimited && !_refreshedForLift && !isClosed) {
      add(const ChatConversationRefreshRequested());
    }
    _inquiryLimited = false;
    _inquiryCounting = false;
    _inquirySent = 0;
    _completeInquiryWaiters();
    final sub = _inquirySub;
    _inquirySub = null;
    unawaited(sub?.cancel());
  }

  void _completeInquiryWaiters() {
    if (!_inquiryParentKnown.isCompleted) _inquiryParentKnown.complete();
    if (!_inquirySentKnown.isCompleted) _inquirySentKnown.complete();
  }

  Future<void> _cancelInquirySubs() async {
    await _inquirySub?.cancel();
    _inquirySub = null;
    await _inquiryParentSub?.cancel();
    _inquiryParentSub = null;
  }

  /// Suit le document de conversation : `askerId` dit si l'utilisateur est le
  /// demandeur (compteur suivi, plafond) ou le créateur (jamais limité) ;
  /// `quotaLifted` lève ou rétablit le plafond en direct.
  void _watchInquiryParent(String firestoreConversationId, String uid) {
    final generation = _inquiryGeneration;
    _inquiryParentSub = _firestoreRepo
        .inquiryParentStream(firestoreConversationId)
        .listen(
          (parent) {
            if (isClosed || generation != _inquiryGeneration) return;
            _applyInquiryParent(firestoreConversationId, uid, parent);
          },
          onError: (Object e) {
            AppLog.warn(
              'chat.inquiry_parent_watch_failed',
              data: {'reason': _reasonOf(e)},
            );
            if (generation == _inquiryGeneration) _inquiryParentFailed();
          },
        );
  }

  /// Erreur terminale du flux parent : demandeur inconnu jusqu'à un nouvel
  /// abonnement, fait paresseusement à l'envoi suivant (pas de boucle).
  void _inquiryParentFailed() {
    unawaited(_inquiryParentSub?.cancel());
    _inquiryParentSub = null;
    if (_inquiryParentKnown.isCompleted) {
      _inquiryParentKnown = Completer<void>();
    }
  }

  void _applyInquiryParent(
    String firestoreConversationId,
    String uid,
    _InquiryParent parent,
  ) {
    // Instantané vide du cache, avant la première réponse du serveur : le
    // demandeur n'est pas encore connu.
    if (!parent.exists && parent.fromCache) return;
    if (parent.quotaLifted) {
      if (_inquiryLimited) {
        _liftInquiry();
      } else {
        _completeInquiryWaiters();
      }
      add(const _InquiryChanged());
      return;
    }
    if (!_inquiryLimited) _lockEpoch++;
    _inquiryLimited = true;
    _refreshedConversation = null;
    _refreshedForLift = false;
    final asker = parent.askerId != null && parent.askerId == uid;
    if (asker && !_inquiryCounting) {
      _inquiryCounting = true;
      _inquirySent = 0;
      _inquirySentKnown = Completer<void>();
      _inquirySub = _firestoreRepo
          .inquirySentStream(firestoreConversationId)
          .listen(
            (sent) {
              if (!isClosed) add(_InquirySentChanged(sent));
            },
            onError: (Object e) => AppLog.warn(
              'chat.inquiry_quota_watch_failed',
              data: {'reason': _reasonOf(e)},
            ),
          );
    } else if (!asker && _inquiryCounting) {
      _inquiryCounting = false;
      unawaited(_inquirySub?.cancel());
      _inquirySub = null;
    }
    if (!_inquiryParentKnown.isCompleted) _inquiryParentKnown.complete();
    if (!_inquiryCounting && !_inquirySentKnown.isCompleted) {
      _inquirySentKnown.complete();
    }
    add(const _InquiryChanged());
  }

  ChatState _snapshot() {
    final quoted = Map<String, MessageModel?>.unmodifiable(_quoted);
    return _readOnly
        ? ChatReadOnly(_messages, quotedMessages: quoted)
        : ChatLoaded(
            _messages,
            replyingTo: _replyingTo,
            quotedMessages: quoted,
            pendingImages: List.unmodifiable(_pendingImages),
            mediaAllowed: _mediaAllowed,
            inquiryRemaining: _inquiryShown ? _inquiryRemaining : null,
            inquiryLimitReached: _inquiryShown && _inquiryRemaining == 0,
            conversation: _refreshedConversation,
          );
  }

  /// Recale les champs du BLoC sur l'état courant, seule source de vérité
  /// du fil affiché ; `false` si aucun fil n'est affiché.
  bool _syncWithThread() {
    switch (state) {
      case ChatLoaded(
        :final messages,
        :final replyingTo,
        :final pendingImages,
        :final mediaAllowed,
      ):
        _messages = messages;
        _readOnly = false;
        _replyingTo = replyingTo;
        _pendingImages = pendingImages;
        _mediaAllowed = mediaAllowed;
        return true;
      case ChatReadOnly(:final messages):
        _messages = messages;
        _readOnly = true;
        return true;
      default:
        return false;
    }
  }

  /// Relit les messages cités absents du fil chargé, une seule fois chacun.
  void _resolveMissingQuotes() {
    final loaded = {for (final m in _messages) m.id};
    for (final m in _messages) {
      final id = m.replyToId;
      if (id == null ||
          loaded.contains(id) ||
          _quoted.containsKey(id) ||
          !_pendingQuotes.add(id)) {
        continue;
      }
      unawaited(
        _firestoreRepo
            .getMessage(_firestoreConversationId, id)
            .then<MessageModel?>((found) => found, onError: (_) => null)
            .then((found) {
              if (!isClosed) add(_QuoteResolved(id, found));
            }),
      );
    }
  }

  void _onQuoteResolved(_QuoteResolved event, Emitter<ChatState> emit) {
    _pendingQuotes.remove(event.id);
    _quoted[event.id] = event.message;
    if (_syncWithThread()) emit(_snapshot());
  }

  void _onReplyStarted(ChatReplyStarted event, Emitter<ChatState> emit) {
    final message = event.message;
    if (!_syncWithThread() ||
        _readOnly ||
        message.isDeleted ||
        message.type == MessageType.system) {
      return;
    }
    _replyingTo = message;
    emit(_snapshot());
  }

  void _onReplyCancelled(ChatReplyCancelled event, Emitter<ChatState> emit) {
    if (!_syncWithThread() || _readOnly || _replyingTo == null) return;
    _replyingTo = null;
    emit(_snapshot());
  }

  /// Envoi réussi d'une réponse : la barre « Réponse à … » disparaît, sauf
  /// si l'utilisateur a entre-temps choisi un autre message à citer.
  void _clearReplyAfterSend(String? replyToId, Emitter<ChatState> emit) {
    if (replyToId == null || !_syncWithThread() || _readOnly) return;
    if (_replyingTo?.id != replyToId) return;
    _replyingTo = null;
    emit(_snapshot());
  }

  Future<void> _onSubscribe(
    ChatSubscribeRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    _firestoreConversationId = event.firestoreConversationId;
    _readOnly = event.isReadOnly;
    _messages = const [];
    _replyingTo = null;
    _conversationId = event.conversationId;
    _refreshedConversation = null;
    _refreshedForLift = false;
    _mediaAllowed = event.mediaAllowed;
    _pendingImages = const [];
    _inquiryGeneration++;
    _completeInquiryWaiters();
    await _cancelInquirySubs();
    _inquiryLimited = event.inquiryLimited && !event.isReadOnly;
    _inquiryWatching = _inquiryLimited && event.currentUserUid.isNotEmpty;
    _inquiryParentKnown = Completer<void>();
    _inquirySentKnown = Completer<void>()..complete();
    _inquiryCounting = false;
    _inquirySent = 0;
    _inquiryLimit = event.inquiryMessageLimit ?? kInquiryDefaultMessageLimit;
    _announcementId = event.announcementId;
    await _messageSub?.cancel();
    await _deletedSub?.cancel();

    // Marquer lu aussi en read-only : sinon le compteur unread_* d'une
    // conversation dont l'interlocuteur a supprimé son compte ou sa copie
    // ne redescend jamais et le badge Messages reste bloqué.
    await _unreadSub?.cancel();
    _markReadTimer?.cancel();
    _currentUserUid = event.currentUserUid;
    _unreadHere = 0;
    if (_currentUserUid.isNotEmpty) {
      _markRead();
      _watchUnreadWhileOpen();
    }

    if (_inquiryWatching) {
      _watchInquiryParent(event.firestoreConversationId, _currentUserUid);
    } else {
      // Pas de compte lisible ou fil non limité : rien à attendre.
      _inquiryParentKnown.complete();
    }

    // Only watch deletion stream when NOT already in read-only
    // (if already read-only, the other party already deleted — stream would fire immediately)
    if (!event.isReadOnly) {
      _deletedSub = _firestoreRepo
          .conversationDeletedStream(event.firestoreConversationId)
          .listen(
            (deleted) {
              if (deleted && !isClosed) add(const _DeletedByOtherParty());
            },
            onError: (_) {
              // Session invalidée entre-temps (ex: signOut concurrent) — pas d'état d'erreur bloquant.
            },
          );
    }

    await emit.forEach<List<MessageModel>>(
      _firestoreRepo.messagesStream(event.firestoreConversationId),
      onData: (messages) {
        _messages = messages;
        _dropArrivedImages();
        _resolveMissingQuotes();
        return _snapshot();
      },
      onError: (e, st) => const ChatError(
        NetworkException(
          'Erreur de connexion à la messagerie', // i18n-ignore
          code: 'chat-stream-error',
        ),
      ),
    );
  }

  Future<void> _onSendText(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Seul le demandeur sous quota (ou tant qu'on ne sait pas qui il est) est
    // sérialisé : un envoi ordinaire, dont un commit hors ligne peut durer, ne
    // doit jamais bloquer la file.
    final serialize =
        _inquiryWatching &&
        (_inquiryCounting || !_inquiryParentKnown.isCompleted);
    if (!serialize) return _sendText(event, emit);
    final previous = _sendChain;
    final done = Completer<void>();
    _sendChain = done.future;
    try {
      await previous;
      await _sendText(event, emit);
    } finally {
      done.complete();
    }
  }

  Future<void> _sendText(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (_inquiryWatching && !_closing && _inquiryParentSub == null) {
      _watchInquiryParent(_firestoreConversationId, _currentUserUid);
    }
    if (_inquiryWatching &&
        (!_inquiryParentKnown.isCompleted ||
            (_inquiryCounting && !_inquirySentKnown.isCompleted))) {
      // Demandeur et compteur pas encore connus : jamais d'envoi ordinaire à
      // l'aveugle, ni avec un compteur à 0 par défaut.
      final generation = _inquiryGeneration;
      try {
        await _awaitInquiryReady().timeout(_inquiryParentTimeout);
      } catch (e) {
        if (_closing || generation != _inquiryGeneration) return;
        _reportSendFailure(emit, e, event, event.body);
        return;
      }
      if (_closing || generation != _inquiryGeneration) return;
    }
    final sent = _inquiryCounting
        ? await _sendInquiryText(event, emit)
        : await _rejectable(
            emit,
            () => _writeText(event),
            retry: event,
            text: event.body,
          );
    if (!sent) return;
    _clearReplyAfterSend(event.replyToId, emit);
    final preview = event.body.length > 80
        ? '${event.body.substring(0, 77)}...'
        : event.body;
    await _updateLastMessage(event.conversationId, preview);
    unawaited(_analytics.logEvent(AnalyticsEvents.messageSent));
  }

  Future<void> _awaitInquiryReady() async {
    await _inquiryParentKnown.future;
    if (_inquiryCounting) await _inquirySentKnown.future;
  }

  Future<void> _writeText(
    ChatTextSendRequested event, {
    int? inquirySentBefore,
  }) => _firestoreRepo.sendTextMessage(
    firestoreConversationId: event.firestoreConversationId,
    senderFirebaseUid: event.senderFirebaseUid,
    body: event.body,
    replyToId: event.replyToId,
    inquirySentBefore: inquirySentBefore,
  );

  /// Envoi du demandeur dans une conversation de questions sous quota : le
  /// compteur est écrit avec le message. À 0 restant, refus local sans appel
  /// réseau.
  Future<bool> _sendInquiryText(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (_inquiryRemaining == 0) {
      _rejectInquiryLimit(emit, event.body);
      return false;
    }
    final before = _inquirySent;
    final startedAt = DateTime.now();
    try {
      await _writeText(event, inquirySentBefore: before);
    } on InquiryLimitReachedException {
      return _reconcileAndRetry(event, emit, before, startedAt);
    } on FirebaseException catch (e) {
      // Compteur absent alors que le nôtre dit > 0 : même dérive.
      if (e.code == 'not-found') {
        return _reconcileAndRetry(event, emit, before, startedAt);
      }
      _reportSendFailure(emit, e, event, event.body);
      return false;
    } catch (e) {
      _reportSendFailure(emit, e, event, event.body);
      return false;
    }
    _inquirySent = math.max(_inquirySent, before + 1);
    if (_syncWithThread()) emit(_snapshot());
    return true;
  }

  /// Les règles ont refusé l'envoi alors que le compteur local laissait de la
  /// place : il a dérivé. `openInquiry` fait recaler Firestore par le back (et
  /// dit si le quota est levé), puis un seul nouvel essai part avec le compteur
  /// frais, sauf si l'écriture précédente est déjà dans le fil (commit réussi,
  /// réponse perdue) : aucun doublon, aucun quota brûlé.
  Future<bool> _reconcileAndRetry(
    ChatTextSendRequested event,
    Emitter<ChatState> emit,
    int attempted,
    DateTime startedAt,
  ) async {
    AppLog.warn('chat.inquiry_reconcile', data: {'attempted': attempted});
    try {
      if (_announcementId.isNotEmpty) {
        final fresh = await _conversationRepo
            .openInquiry(_announcementId)
            .timeout(_inquiryReconcileTimeout);
        if (fresh.inquiryQuotaLifted) {
          _liftInquiry();
          if (_syncWithThread()) emit(_snapshot());
          await _writeText(event);
          return true;
        }
      }
      final fresh = await _firestoreRepo
          .inquirySentStream(event.firestoreConversationId)
          .first
          .timeout(_inquiryParentTimeout);
      if (!_inquiryCounting) {
        // Levée arrivée pendant le recalage : envoi ordinaire.
        await _writeText(event);
        return true;
      }
      _inquirySent = fresh;
      if (fresh == attempted + 1 &&
          await _alreadyWritten(event, fresh, startedAt)) {
        if (_syncWithThread()) emit(_snapshot());
        return true;
      }
      if (_inquiryRemaining == 0) {
        _rejectInquiryLimit(emit, event.body);
        return false;
      }
      await _writeText(event, inquirySentBefore: fresh);
      _inquirySent = math.max(_inquirySent, fresh + 1);
      if (_syncWithThread()) emit(_snapshot());
      return true;
    } on InquiryLimitReachedException {
      if (_inquiryRemaining == 0) {
        _rejectInquiryLimit(emit, event.body);
      } else {
        // Refus malgré de la place : autre cause (sourdine, fil fermé…).
        final previous = _syncWithThread() ? _snapshot() : state;
        emit(ChatSendRejected(previous, text: event.body));
        emit(previous);
      }
      return false;
    } catch (e) {
      _reportSendFailure(emit, e, event, event.body);
      return false;
    }
  }

  /// Le message `inq<n>` est déjà dans le fil, écrit par nous avec ce texte.
  /// Il doit avoir été écrit après le début de la tentative (marge 2 s pour
  /// l'écart d'horloge) : un ancien message identique n'est pas un doublon.
  Future<bool> _alreadyWritten(
    ChatTextSendRequested event,
    int n,
    DateTime startedAt,
  ) async {
    try {
      final message = await _firestoreRepo.getMessage(
        event.firestoreConversationId,
        'inq$n',
      );
      return message != null &&
          message.senderId == event.senderFirebaseUid &&
          message.body == event.body &&
          !message.sentAt.isBefore(
            startedAt.subtract(const Duration(seconds: 2)),
          );
    } catch (_) {
      return false;
    }
  }

  void _rejectInquiryLimit(Emitter<ChatState> emit, String text) {
    AppLog.info(
      'chat.inquiry_limit_reached',
      data: {'sent': _inquirySent, 'limit': _inquiryLimit},
    );
    final previous = _syncWithThread() ? _snapshot() : state;
    emit(ChatSendRejected(previous, text: text, inquiryLimit: true));
    emit(previous);
  }

  /// Aperçu « dernier message » de la liste des conversations : opération
  /// secondaire, le message est déjà dans Firestore. Un échec (délai dépassé,
  /// coupure réseau) ne fait ni échouer l'envoi ni sortir le handler en
  /// erreur non rattrapée, remontée en crash fatal (FLUTTER-KW). L'aperçu est
  /// réécrit au prochain envoi ; l'intercepteur HTTP rapporte déjà les
  /// erreurs serveur.
  Future<void> _updateLastMessage(String conversationId, String preview) =>
      _secondary(
        'chat.last_message_update_failed',
        () => _conversationRepo.updateLastMessage(conversationId, preview),
      );

  /// Remet le fil courant à « lu » : compteur `unread_*` et `readAt` des
  /// messages reçus. Écritures secondaires non attendues : leur échec (hors
  /// ligne, Firestore indisponible) est rattrapé, jamais une erreur non gérée.
  void _markRead() {
    final convId = _firestoreConversationId;
    final uid = _currentUserUid;
    if (convId.isEmpty || uid.isEmpty) return;
    _unreadHere = 0;
    unawaited(
      _secondary(
        'chat.mark_conversation_read_failed',
        () => _firestoreRepo.markConversationRead(convId, uid),
      ),
    );
    unawaited(
      _secondary(
        'chat.mark_messages_read_failed',
        () => _firestoreRepo.markMessagesRead(
          firestoreConversationId: convId,
          currentUserUid: uid,
        ),
      ),
    );
  }

  /// Écoute le compteur de non-lus de ce fil tant qu'il est ouvert : dès qu'un
  /// message reçu le fait remonter, l'app au premier plan, le fil est remis à
  /// « lu » après [_markReadDelay] (plusieurs messages rapprochés = une seule
  /// écriture). On réagit au compteur et non à l'arrivée du message : la
  /// fonction l'incrémente une à trois secondes après, une remise à 0 faite à
  /// l'arrivée serait aussitôt annulée (FLUTTER-NX).
  void _watchUnreadWhileOpen() {
    final convId = _firestoreConversationId;
    try {
      _unreadSub = _firestoreRepo
          .perConversationUnreadStream(_currentUserUid)
          .listen(
            (counts) {
              _unreadHere = counts[convId] ?? 0;
              if (_unreadHere > 0 && _appVisible) _scheduleMarkRead();
            },
            onError: (Object e) => AppLog.warn(
              'chat.unread_watch_failed',
              data: {'reason': _reasonOf(e)},
            ),
          );
    } catch (e) {
      AppLog.warn('chat.unread_watch_failed', data: {'reason': _reasonOf(e)});
    }
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(_markReadDelay, () {
      if (isClosed || !_appVisible || _unreadHere <= 0) return;
      _markRead();
    });
  }

  void _onAppVisibilityChanged(
    ChatAppVisibilityChanged event,
    Emitter<ChatState> emit,
  ) {
    _appVisible = event.visible;
    if (!event.visible) {
      _markReadTimer?.cancel();
      return;
    }
    if (_unreadHere > 0) _markRead();
  }

  /// Exécute une opération secondaire sans jamais lever : l'échec devient un
  /// log Sentry (code d'erreur seul, jamais de contenu).
  Future<void> _secondary(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      AppLog.warn(operation, data: {'reason': _reasonOf(e)});
    }
  }

  static String _reasonOf(Object error) => switch (error) {
    FirebaseException(:final code) => code,
    _ => unwrapDioError(error).code ?? error.runtimeType.toString(),
  };

  /// Retire les bulles locales dont le vrai message est arrivé dans le fil.
  void _dropArrivedImages() {
    if (_pendingImages.isEmpty) return;
    final ids = {for (final m in _messages) m.id};
    _pendingImages = [
      for (final p in _pendingImages)
        if (p.messageId == null || !ids.contains(p.messageId)) p,
    ];
  }

  void _replacePending(String localId, PendingChatImage? next) {
    _pendingImages = [
      for (final p in _pendingImages)
        if (p.localId != localId) p else ?next,
    ];
  }

  Future<void> _onSendImage(
    ChatImageSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Les règles n'acceptent que du texte dans une conversation de questions.
    if (_inquiryLimited || !_syncWithThread() || _readOnly) return;
    if (event.conversationId.isNotEmpty) _conversationId = event.conversationId;
    final pending = PendingChatImage(
      localId: 'local-${++_localImageSeq}',
      bytes: event.bytes,
      replyToId: event.replyToId,
    );
    _pendingImages = [pending, ..._pendingImages];
    emit(_snapshot());
    await _upload(pending, emit);
  }

  Future<void> _onRetryImage(
    ChatImageRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (!_syncWithThread() || _readOnly) return;
    final failed = _pendingImages
        .where((p) => p.localId == event.localId && p.isFailed)
        .firstOrNull;
    if (failed == null) return;
    final retry = failed.copyWith(status: PendingChatImageStatus.sending);
    _replacePending(failed.localId, retry);
    emit(_snapshot());
    await _upload(retry, emit);
  }

  void _onDiscardImage(
    ChatImageDiscardRequested event,
    Emitter<ChatState> emit,
  ) {
    if (!_syncWithThread()) return;
    _replacePending(event.localId, null);
    emit(_snapshot());
  }

  /// POST de la photo. Le back écrit le message dans Firestore : la bulle
  /// locale reste jusqu'à son arrivée dans le fil (cf. [_dropArrivedImages]).
  Future<void> _upload(
    PendingChatImage pending,
    Emitter<ChatState> emit,
  ) async {
    try {
      final messageId = await _conversationRepo.sendImage(
        _conversationId,
        pending.bytes,
        replyToId: pending.replyToId,
      );
      final arrived =
          messageId.isEmpty || _messages.any((m) => m.id == messageId);
      _syncWithThread();
      _replacePending(
        pending.localId,
        arrived ? null : pending.copyWith(messageId: messageId),
      );
      emit(_snapshot());
      unawaited(_analytics.logEvent(AnalyticsEvents.chatPhotoSent));
      _clearReplyAfterSend(pending.replyToId, emit);
    } catch (e) {
      final failure = _classify(unwrapDioError(e));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.chatPhotoFailed,
          properties: {'reason': failure.name},
        ),
      );
      _syncWithThread();
      final retryable =
          failure == ChatImageFailure.other ||
          failure == ChatImageFailure.rateLimited;
      _replacePending(
        pending.localId,
        retryable
            ? pending.copyWith(status: PendingChatImageStatus.failed)
            : null,
      );
      if (failure == ChatImageFailure.notAllowed) _mediaAllowed = false;
      emit(ChatImageSendFailed(failure));
      emit(_snapshot());
      if (failure == ChatImageFailure.notAllowed) {
        await _reloadMediaAllowed(emit);
      }
    }
  }

  static ChatImageFailure _classify(AppException error) => switch (error) {
    ForbiddenException(code: 'media-not-allowed') =>
      ChatImageFailure.notAllowed,
    RateLimitException() => ChatImageFailure.rateLimited,
    ValidationException() => ChatImageFailure.invalid,
    _ => ChatImageFailure.other,
  };

  /// Après un refus, la conversation est relue : le back dit si les photos
  /// sont permises (fenêtre close, bid annulé, blocage…). Un échec de lecture
  /// laisse le trombone grisé, repli sûr.
  Future<void> _reloadMediaAllowed(Emitter<ChatState> emit) async {
    if (_conversationId.isEmpty) return;
    try {
      final conversation = await _conversationRepo.getConversation(
        _conversationId,
      );
      if (!_syncWithThread() || _readOnly) return;
      _mediaAllowed = conversation.mediaAllowed;
      emit(_snapshot());
    } catch (_) {
      // Repli : photos refusées jusqu'à la prochaine ouverture.
    }
  }

  Future<void> _onSendLocation(
    ChatLocationSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (_inquiryLimited) return;
    final sent = await _rejectable(
      emit,
      () => _firestoreRepo.sendLocationMessage(
        firestoreConversationId: event.firestoreConversationId,
        senderFirebaseUid: event.senderFirebaseUid,
        latitude: event.latitude,
        longitude: event.longitude,
        replyToId: event.replyToId,
      ),
      retry: event,
    );
    if (!sent) return;
    _clearReplyAfterSend(event.replyToId, emit);
    await _updateLastMessage(event.conversationId, kChatPreviewLocation);
  }

  /// Écrit dans Firestore ; `false` si l'écriture échoue. Aucun échec ne
  /// sort du handler en erreur non rattrapée (crashs fatals FLUTTER-CV,
  /// FLUTTER-KW) :
  /// - refus des règles (`permission-denied` : messagerie coupée par un
  ///   administrateur ou conversation fermée) → [ChatSendRejected], l'écran
  ///   l'explique et rend le texte ;
  /// - tout autre échec → [ChatSendFailed], l'écran rend le texte et propose
  ///   de réessayer avec [retry].
  Future<bool> _rejectable(
    Emitter<ChatState> emit,
    Future<void> Function() write, {
    required ChatEvent retry,
    String? text,
  }) async {
    try {
      await write();
      return true;
    } catch (e) {
      _reportSendFailure(emit, e, retry, text);
      return false;
    }
  }

  void _reportSendFailure(
    Emitter<ChatState> emit,
    Object e,
    ChatEvent retry,
    String? text,
  ) {
    final previous = state;
    if (e is FirebaseException && e.code == 'permission-denied') {
      emit(ChatSendRejected(previous, text: text));
    } else {
      AppLog.warn('chat.send_failed', data: {'reason': _reasonOf(e)});
      emit(ChatSendFailed(previous, retry: retry, text: text));
    }
    emit(previous);
  }

  Future<void> _onEditMessage(
    ChatMessageEditRequested event,
    Emitter<ChatState> emit,
  ) async => _applyEdit(
    emit,
    ChatMessageEditAction.edit,
    (repo) => repo.editMessage(
      firestoreConversationId: _firestoreConversationId,
      messageId: event.messageId,
      text: event.text,
    ),
  );

  Future<void> _onDeleteMessage(
    ChatMessageDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    final deleted = await _applyEdit(
      emit,
      ChatMessageEditAction.delete,
      (repo) => repo.deleteMessage(
        firestoreConversationId: _firestoreConversationId,
        messageId: event.messageId,
      ),
    );
    // Un message supprimé ne se cite plus : la barre « Réponse à … » tombe.
    if (deleted &&
        _syncWithThread() &&
        !_readOnly &&
        _replyingTo?.id == event.messageId) {
      _replyingTo = null;
      emit(_snapshot());
    }
  }

  /// Appelle la callable ; aucun échec ne sort du handler. Le fil n'est pas
  /// touché localement : la bulle change quand Firestore renvoie le message.
  Future<bool> _applyEdit(
    Emitter<ChatState> emit,
    ChatMessageEditAction action,
    Future<void> Function(MessageEditRepository repo) call,
  ) async {
    if (!_syncWithThread() || _readOnly) return false;
    final repo = _editRepo;
    MessageEditFailure? failure;
    if (repo == null) {
      failure = MessageEditFailure.unavailable;
    } else {
      try {
        await call(repo);
      } on MessageEditException catch (e) {
        failure = e.failure;
      } catch (_) {
        failure = MessageEditFailure.other;
      }
    }
    if (failure == null) {
      unawaited(
        _analytics.logEvent(
          action == ChatMessageEditAction.edit
              ? AnalyticsEvents.messageEdited
              : AnalyticsEvents.messageDeleted,
        ),
      );
      return true;
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.messageEditFailed,
        properties: {'action': action.name, 'reason': failure.name},
      ),
    );
    if (failure == MessageEditFailure.other ||
        failure == MessageEditFailure.unavailable) {
      AppLog.warn('chat.message_edit_failed', data: {'reason': failure.name});
    }
    final previous = _syncWithThread() ? _snapshot() : state;
    emit(ChatMessageEditFailed(action, failure));
    emit(previous);
    return false;
  }

  Future<void> _onDeleteConversation(
    ChatConversationDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatDeletingConversation());
    // Cancel deletion stream BEFORE the API call so Firestore echo doesn't
    // trigger _DeletedByOtherParty after we already handle the deletion ourselves.
    await _deletedSub?.cancel();
    _deletedSub = null;

    // Reset the unread counter so the bottom-nav badge clears immediately.
    // Already a no-op when the user opened the chat (subscribe path does it),
    // but read-only chats never call markConversationRead, so do it here too.
    if (event.firestoreConversationId.isNotEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          await _firestoreRepo.markConversationRead(
            event.firestoreConversationId,
            uid,
          );
        }
      } catch (_) {
        // Non-fatal — proceed with the API deletion.
      }
    }

    try {
      await _conversationRepo.deleteConversation(event.conversationId);
      emit(const ChatConversationDeleted());
    } catch (e) {
      emit(ChatError(unwrapDioError(e)));
    }
  }

  void _onDeletedByOtherParty(
    _DeletedByOtherParty event,
    Emitter<ChatState> emit,
  ) {
    // The other party deleted — transition to read-only (keep showing messages)
    final current = state;
    _messages = current is ChatLoaded ? current.messages : <MessageModel>[];
    _readOnly = true;
    _replyingTo = null;
    emit(_snapshot());
  }

  @override
  Future<void> close() async {
    await _messageSub?.cancel();
    await _deletedSub?.cancel();
    await _unreadSub?.cancel();
    _closing = true;
    _inquiryGeneration++;
    _completeInquiryWaiters();
    await _cancelInquirySubs();
    _markReadTimer?.cancel();
    // Sortie du fil : dernière remise à « lu » pour un message arrivé pendant
    // le délai anti-rebond, sinon il resterait compté à l'arrivée sur la liste.
    if (_appVisible && _unreadHere > 0) _markRead();
    return super.close();
  }
}
