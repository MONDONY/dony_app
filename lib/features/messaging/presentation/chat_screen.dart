import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/calls/bloc/call_lock_screen_cubit.dart';
import 'package:dony/features/calls/presentation/call_screen.dart';
import 'package:dony/features/calls/presentation/widgets/call_lock_screen_prompt.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/data/chat_draft_store.dart';
import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  /// Détourne la navigation en test. En production, laisser `null` :
  /// `_navigate` retombe alors sur `context.push`, conformément à la règle
  /// GoRouter du projet.
  @visibleForTesting
  final void Function(String path, Object? extra)? onNavigate;

  const ChatScreen({super.key, required this.conversation, this.onNavigate});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _validator = ChatMessageValidator();

  /// Envois récents de l'utilisateur — débit (5/15 s) + anti-doublon (30 s).
  final List<SentRecord> _recentSends = [];
  bool _isSending = false;

  StreamSubscription<BlockChange>? _blockSub;

  // Réponse à un message (FLUTTER-86) : focus de la saisie au début d'une
  // réponse, clé de chaque bulle pour défiler jusqu'au message cité, et
  // bulle brièvement surlignée à l'arrivée.
  final _inputFocus = FocusNode();
  final Map<String, GlobalKey> _messageKeys = {};
  final _highlighted = ValueNotifier<String?>(null);
  Timer? _highlightTimer;

  /// Brouillon par conversation (FLUTTER-CY) : restauré à l'ouverture,
  /// enregistré à la sortie et au passage en arrière-plan, effacé à l'envoi.
  /// `null` hors injection (tests d'écran sans stockage).
  late final ChatDraftStore? _drafts = _draftStore();
  late final AppLifecycleListener _lifecycle;

  /// Un fil en lecture seule n'a pas de champ de saisie : rien à garder.
  bool get _keepsDraft => !widget.conversation.readOnly;

  String get _myUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(
      ChatSubscribeRequested(
        widget.conversation.firestoreConversationId,
        currentUserUid: _myUid,
        isReadOnly: widget.conversation.readOnly,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.conversationOpened,
          properties: {'context': 'conversation'},
        ),
      );
      // Appel Yadony possible ici : prévenir, une fois, si le téléphone
      // masquerait un appel entrant écran verrouillé (FLUTTER-92).
      if (widget.conversation.callAvailable &&
          !widget.conversation.readOnly &&
          getIt.isRegistered<CallLockScreenCubit>()) {
        unawaited(CallLockScreenPrompt.maybeShow(context));
      }
    });
    // Coupure de messagerie connue : le profil est relu, car une levée par
    // l'admin n'envoie aucune push et le bandeau resterait affiché.
    final auth = _MessagingMuteGate.maybeAuthBloc(context);
    if (auth != null &&
        !auth.isClosed &&
        (auth.state.currentUser?.isMessagingMuted() ?? false)) {
      auth.add(const AuthProfileRefreshRequested());
    }
    // Abonnement côté widget (et non dans ChatBloc) : ce qu'il déclenche est une
    // navigation, qui n'appartient pas au BLoC.
    _blockSub = _blockEvents()?.changes.listen(_onBlockChange);
    if (_keepsDraft) {
      final draft = _drafts?.read(widget.conversation.id) ?? '';
      if (draft.isNotEmpty) {
        _controller.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
      }
    }
    // Une app tuée en arrière-plan ne passe jamais par `dispose` : le
    // brouillon est aussi écrit dès que l'écran est masqué.
    _lifecycle = AppLifecycleListener(onHide: _persistDraft);
  }

  ChatDraftStore? _draftStore() {
    try {
      return getIt.isRegistered<ChatDraftStore>()
          ? getIt<ChatDraftStore>()
          : null;
    } catch (_) {
      return null;
    }
  }

  void _persistDraft() {
    if (!_keepsDraft) return;
    unawaited(_drafts?.save(widget.conversation.id, _controller.text));
  }

  BlockEventsService? _blockEvents() {
    try {
      return getIt.isRegistered<BlockEventsService>()
          ? getIt<BlockEventsService>()
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Le serveur refuse désormais tout message vers cet interlocuteur : rester
  /// sur un fil qui n'accepte plus rien n'aurait aucun sens, on revient à la
  /// liste. Un déblocage, lui, ne change rien à l'écran ouvert.
  void _onBlockChange(BlockChange change) {
    if (!change.blocked) return;
    if (change.userId != widget.conversation.otherParticipant.id) return;
    // Navigation immédiate, sans passer par un post-frame : rien ne garantit
    // qu'une frame soit produite ensuite, et l'écran resterait ouvert. Le
    // dialog de confirmation éventuellement au-dessus se referme de lui-même.
    if (!mounted) return;
    _leaveToConversationList();
  }

  void _leaveToConversationList() {
    final override = widget.onNavigate;
    if (override != null) {
      override('/messages', null);
      return;
    }
    context.go('/messages');
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    _highlightTimer?.cancel();
    _highlighted.dispose();
    _inputFocus.dispose();
    _lifecycle.dispose();
    // Avant de disposer le contrôleur : son texte est le brouillon.
    _persistDraft();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigate(String path, Object? extra) {
    final override = widget.onNavigate;
    if (override != null) {
      override(path, extra);
      return;
    }
    context.push(path, extra: extra);
  }

  void _confirmAndDelete() {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.chatDeleteConversationTitle),
        content: Text(l.chatDeleteConversationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ChatBloc>().add(
                ChatConversationDeleteRequested(
                  conversationId: widget.conversation.id,
                  firestoreConversationId:
                      widget.conversation.firestoreConversationId,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
  }

  /// Seul l'appel Yadony est possible : un tap le lance. Les deux : choix
  /// dans une feuille.
  Future<void> _onCallTapped(
    ParticipantModel participant,
    bool canCallByPhone,
  ) async {
    if (!canCallByPhone) {
      _startInAppCall(participant);
      return;
    }
    final l = context.l10n;
    final choice = await DonyBottomSheet.show<String>(
      context,
      title: l.chatCallChooserTitle(participant.name),
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wifi_calling_3_rounded),
              title: Text(l.chatCallInApp),
              subtitle: Text(l.chatCallInAppSubtitle),
              onTap: () => Navigator.of(sheetContext).pop('yadony'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: Text(l.chatCallByPhone),
              subtitle: Text(l.chatCallByPhoneSubtitle),
              onTap: () => Navigator.of(sheetContext).pop('phone'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.callModeChosen,
        properties: {'mode': choice},
      ),
    );
    if (choice == 'yadony') {
      _startInAppCall(participant);
    } else {
      _requestCall();
    }
  }

  void _startInAppCall(ParticipantModel participant) {
    _navigate(
      '/calls/pending',
      CallScreenArgs(
        remoteName: participant.name,
        remoteAvatarUrl: participant.avatarUrl,
        conversationId: widget.conversation.id,
      ),
    );
  }

  void _requestCall() {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.conversationCallInitiated,
      ),
    );
    // Le numéro n'est plus dans la conversation : on le demande au serveur, qui
    // vérifie que le deal est actif et journalise la révélation.
    context.read<ContactRevealBloc>().add(
      ContactRevealRequested(widget.conversation.bidId),
    );
  }

  Future<void> _sendText() async {
    if (_isSending) return;
    final raw = _controller.text;
    final now = DateTime.now();

    // Règles de contenu (cf. ChatMessageValidator) — bloque + avertit.
    final result = _validator.validate(raw, recent: _recentSends, now: now);
    if (result is ChatValidationBlocked) {
      final message = chatBlockedMessage(
        context.l10n,
        result.reason,
        term: result.term,
      );
      if (message.isNotEmpty) {
        DonySnackbar.show(
          context,
          message: message,
          type: DonySnackbarType.warning,
        );
        unawaited(
          getIt<AnalyticsService>().logEvent(
            AnalyticsEvents.messageBlocked,
            // Jamais `result.term` : c'est du contenu utilisateur.
            properties: {'reason': result.reason},
          ),
        );
      }
      return;
    }
    final text = (result as ChatValidationOk).text;

    setState(() => _isSending = true);
    _controller.clear();
    // Envoyé : le brouillon n'a plus lieu d'être. Un refus Firestore rend le
    // texte au champ (`_onSendRejected`), et la sortie le réenregistre.
    unawaited(_drafts?.clear(widget.conversation.id));
    _recentSends.add(SentRecord(now, text));
    // Borne la liste (fenêtre la plus longue = anti-doublon 30 s).
    _recentSends.removeWhere(
      (r) => now.difference(r.at) > const Duration(seconds: 30),
    );

    final bloc = context.read<ChatBloc>();
    final current = bloc.state;
    bloc.add(
      ChatTextSendRequested(
        firestoreConversationId: widget.conversation.firestoreConversationId,
        conversationId: widget.conversation.id,
        senderFirebaseUid: _myUid,
        body: text,
        replyToId: current is ChatLoaded ? current.replyingTo?.id : null,
      ),
    );
    setState(() => _isSending = false);
  }

  /// Appui long « Répondre » ou balayage d'une bulle (FLUTTER-86).
  void _startReply(MessageModel message) {
    unawaited(HapticFeedback.selectionClick());
    context.read<ChatBloc>().add(ChatReplyStarted(message));
    _inputFocus.requestFocus();
  }

  GlobalKey _keyFor(String messageId) =>
      _messageKeys.putIfAbsent(messageId, GlobalKey.new);

  /// Auteur affiché d'une citation : « Vous » ou l'interlocuteur.
  String _authorOf(MessageModel message, String otherName) =>
      message.senderId == _myUid ? context.l10n.chatQuoteYou : otherName;

  /// Citation d'un message, reconstituée à partir de son seul `replyToId` :
  /// cherchée dans le fil chargé, sinon dans les messages relus à l'unité.
  _QuoteData? _quoteFor(
    MessageModel message,
    Map<String, MessageModel> loaded,
    Map<String, MessageModel?> quotedMessages,
    String otherName,
  ) {
    final id = message.replyToId;
    if (id == null) return null;
    final inThread = loaded[id];
    if (inThread != null) {
      return _QuoteData(
        message: inThread,
        author: _authorOf(inThread, otherName),
        inThread: true,
      );
    }
    if (!quotedMessages.containsKey(id)) return const _QuoteData.pending();
    final fetched = quotedMessages[id];
    return _QuoteData(
      message: fetched,
      author: fetched == null ? null : _authorOf(fetched, otherName),
    );
  }

  /// Défile jusqu'au message cité, présent dans le fil chargé. La liste est
  /// inversée et ses hauteurs variables : tant que la bulle n'est pas
  /// construite, on remonte d'un écran (le message cité est toujours plus
  /// ancien que la réponse, donc plus haut), puis on la centre.
  Future<void> _scrollToMessage(String messageId) async {
    for (var step = 0; step < 40; step++) {
      if (!mounted) return;
      final target = _messageKeys[messageId]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        _flash(messageId);
        return;
      }
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent) return;
      await _scrollController.animateTo(
        math.min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
    }
  }

  void _flash(String messageId) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    _highlighted.value = messageId;
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _highlighted.value = null;
    });
  }

  /// Firestore a refusé l'envoi : le texte revient dans le champ, le profil
  /// est relu pour faire apparaître une coupure de messagerie posée entre-temps.
  void _onSendRejected(ChatSendRejected state) {
    final text = state.text;
    if (text != null && _controller.text.isEmpty) {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
    }
    final auth = _MessagingMuteGate.maybeAuthBloc(context);
    if (auth != null && !auth.isClosed) {
      auth.add(const AuthProfileRefreshRequested());
    }
    DonySnackbar.show(
      context,
      message: context.l10n.chatSendRejected,
      type: DonySnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final conversation = widget.conversation;
    final participant = conversation.otherParticipant;
    // Repli partagé par le titre de l'écran et le menu ⋯ (Signaler/Bloquer/
    // dialogue de confirmation) : un participant sans nom ne doit jamais
    // afficher un menu à moitié vide.
    final displayName = participant.name.isNotEmpty
        ? participant.name
        : l.chatUnknownConversationLabel;
    // Le canal SMS OTP coupé n'empêche pas d'appeler (fonctionnalité
    // indépendante), mais tant qu'il l'est le concept même de "numéro" reste
    // masqué partout dans l'app — bouton retiré pour rester cohérent.
    // Conversation voyageur ↔ destinataire (lot 3C) : le numéro n'y est
    // jamais révélé, même si un back le laissait passer.
    // Appel Yadony (audio dans l'app) : décidé par le back (`callAvailable`).
    // Le téléphone n'est jamais proposé seul : seulement en second choix,
    // quand l'appel Yadony existe et que le numéro est partageable.
    final canCallInApp = conversation.callAvailable;
    final canCallByPhone =
        canCallInApp &&
        participant.phoneAvailable &&
        smsAuthEnabledListenable.value &&
        !conversation.isRecipientConversation;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: const DonyAppBarBackButton(),
        // Avatar + nom : ouvrent le profil public du correspondant (Sentry
        // FLUTTER-5E). Inactif si son compte est supprimé (readOnly) : le
        // profil n'existe plus.
        title: _ParticipantHeader(
          enabled: participant.id.isNotEmpty && !conversation.readOnly,
          semanticsLabel: l.chatOpenParticipantProfileSemantics(displayName),
          onTap: () => _navigate(
            '/profile/public',
            ProfilePublicArgs(userId: participant.id),
          ),
          child: Row(
            children: [
              DonyAvatar(
                name: participant.name.isNotEmpty ? participant.name : '?',
                imageUrl: participant.avatarUrl,
                size: DonyAvatarSize.sm,
                verified: participant.kycVerified,
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: tt.titleLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (participant.role != null &&
                        participant.role!.isNotEmpty)
                      Text(
                        participant.role!,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (canCallInApp)
            BlocConsumer<ContactRevealBloc, ContactRevealState>(
              listener: (context, state) {
                if (state is ContactRevealSuccess) {
                  unawaited(dialPhoneNumber(context, state.phoneNumber));
                } else if (state is ContactRevealError) {
                  ErrorPresenter.show(context, state.error);
                }
              },
              builder: (context, state) {
                final isRevealing = state is ContactRevealLoading;
                return IconButton(
                  tooltip: l.chatCallTooltip,
                  onPressed: isRevealing
                      ? null
                      : () => _onCallTapped(participant, canCallByPhone),
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                    ),
                    child: isRevealing
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : DonyIcon('phone', size: 18, color: cs.primary),
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _navigate('/settings/report-incident', {
                    'targetType': IncidentTargetType.user,
                    'targetId': participant.id,
                  });
                case 'block':
                  // showBlockMenu ouvre le menu ⋯ à une seule entrée — déjà
                  // le cas ici (PopupMenuItem « Bloquer $name »). L'appeler
                  // depuis ce menu produirait un menu dans un menu, le même
                  // libellé affiché deux fois de suite. showBlockConfirmDialog
                  // va directement au dialogue de confirmation.
                  showBlockConfirmDialog(
                    context,
                    userId: participant.id,
                    displayName: displayName,
                  );
                case 'delete':
                  _confirmAndDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    DonyIcon('flag', size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.chatReportUser(displayName),
                        style: tt.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    DonyIcon('ban', size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.chatBlockUser(displayName),
                        style: tt.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    DonyIcon('trash-2', size: 20, color: cs.error),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        l.chatDeleteConversationTitle,
                        style: tt.bodyMedium?.copyWith(color: cs.error),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DonyFeedbackButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listenWhen: (_, current) =>
            current is ChatConversationDeleted ||
            current is ChatError ||
            current is ChatSendRejected,
        // Signal ponctuel aussitôt remplacé par l'état précédent : jamais
        // dessiné, la liste des messages reste à l'écran.
        buildWhen: (_, current) => current is! ChatSendRejected,
        listener: (context, state) {
          if (state is ChatSendRejected) {
            _onSendRejected(state);
          } else if (state is ChatConversationDeleted) {
            getIt<ConversationListBloc>().add(
              ConversationRemovedLocally(widget.conversation.id),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              DonySnackbar.show(
                context,
                message: l.chatConversationDeletedSnackbar,
              );
              if (context.canPop()) context.pop();
            });
          } else if (state is ChatError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        builder: (context, state) {
          final isReadOnly = state is ChatReadOnly;
          return Column(
            children: [
              if (conversation.tripLabel != null)
                _TripBanner(
                  conversation: conversation,
                  cs: cs,
                  tt: tt,
                  disabled: isReadOnly,
                  // Le destinataire n'a pas accès au détail du bid : son
                  // bandeau mène à l'écran du colis qu'il va recevoir.
                  onTap: () => _navigate(
                    conversation.viewerIsRecipient
                        ? '/receptions/${conversation.bidId}'
                        : '/bids/${conversation.bidId}',
                    null,
                  ),
                ),
              if (isReadOnly) _ReadOnlyBanner(cs: cs, tt: tt),
              if (conversation.bidStatus != null)
                _BidStatusBanner(
                  status: conversation.bidStatus!,
                  cs: cs,
                  tt: tt,
                ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state is ChatLoading || state is ChatInitial) {
                      return const DonyChatSkeleton();
                    }
                    if (state is ChatError) {
                      return DonyEmptyState(
                        type: DonyEmptyStateType.error,
                        mascotte: DonyMascotteType.erreurLegere,
                        iconAsset: 'wifi-off',
                        title: l.chatConnectionLostTitle,
                        description: ErrorPresenter.resolve(
                          state.error,
                          l10n: context.l10n,
                        ).message,
                        actionLabel: l.commonRetry,
                        onAction: () => context.read<ChatBloc>().add(
                          ChatSubscribeRequested(
                            widget.conversation.firestoreConversationId,
                          ),
                        ),
                      );
                    }

                    final messages = switch (state) {
                      ChatLoaded(:final messages) => messages,
                      ChatReadOnly(:final messages) => messages,
                      _ => null,
                    };
                    final quotedMessages = switch (state) {
                      ChatLoaded(:final quotedMessages) => quotedMessages,
                      ChatReadOnly(:final quotedMessages) => quotedMessages,
                      _ => const <String, MessageModel?>{},
                    };
                    final loaded = {
                      for (final m in messages ?? const <MessageModel>[])
                        m.id: m,
                    };
                    _messageKeys.removeWhere(
                      (id, _) => !loaded.containsKey(id),
                    );

                    if (messages != null) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DonyIcon(
                                'message-circle',
                                size: 48,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              const SizedBox(height: DonySpacing.md),
                              Text(
                                l.chatEmptyStateTitle,
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.sm,
                          DonySpacing.lg,
                          DonySpacing.md,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == _myUid;
                          final quote = _quoteFor(
                            message,
                            loaded,
                            quotedMessages,
                            displayName,
                          );
                          final canReply =
                              !isReadOnly &&
                              !message.isDeleted &&
                              message.type != MessageType.system;
                          final quotedId = message.replyToId;
                          final showSep = _showDateSeparator(messages, index);
                          // Dernier d'un groupe (visuellement en bas du groupe) :
                          // le message plus récent (index-1) a un autre expéditeur,
                          // ou c'est le plus récent, ou un séparateur les coupe.
                          final isLastOfGroup =
                              index == 0 ||
                              messages[index - 1].senderId !=
                                  message.senderId ||
                              _showDateSeparator(messages, index - 1);
                          return Column(
                            children: [
                              if (showSep)
                                _DateSeparator(
                                  date: message.sentAt,
                                  cs: cs,
                                  tt: tt,
                                ),
                              KeyedSubtree(
                                key: _keyFor(message.id),
                                child: ValueListenableBuilder<String?>(
                                  valueListenable: _highlighted,
                                  builder: (context, highlighted, child) =>
                                      _HighlightFlash(
                                        active: highlighted == message.id,
                                        child: child!,
                                      ),
                                  child:
                                      _MessageBubble(
                                            message: message,
                                            isMe: isMe,
                                            isLastOfGroup: isLastOfGroup,
                                            quote: quote,
                                            onReply: canReply
                                                ? () => _startReply(message)
                                                : null,
                                            onQuoteTap:
                                                quote != null &&
                                                    quote.inThread &&
                                                    quotedId != null
                                                ? () => unawaited(
                                                    _scrollToMessage(quotedId),
                                                  )
                                                : null,
                                          )
                                          .animate()
                                          .fadeIn(
                                            duration: 180.ms,
                                            curve: Curves.easeOutCubic,
                                          )
                                          .slideY(
                                            begin: 0.06,
                                            end: 0,
                                            duration: 180.ms,
                                            curve: Curves.easeOutCubic,
                                          ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              _MessagingMuteGate(
                builder: (mutedUntil) => mutedUntil != null
                    ? _MutedBanner(until: mutedUntil)
                    : _ComposeArea(
                        replyingTo: state is ChatLoaded
                            ? state.replyingTo
                            : null,
                        replyAuthorIsMe: state is ChatLoaded
                            ? state.replyingTo?.senderId == _myUid
                            : false,
                        otherName: displayName,
                        onCancelReply: () => context.read<ChatBloc>().add(
                          const ChatReplyCancelled(),
                        ),
                        input: _InputBar(
                          controller: _controller,
                          focusNode: _inputFocus,
                          showTopBorder:
                              state is! ChatLoaded || state.replyingTo == null,
                          isSending: _isSending,
                          disabled: isReadOnly,
                          onSendText: _sendText,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _showDateSeparator(List<MessageModel> messages, int index) {
    if (index < 0 || index >= messages.length) return false;
    if (index == messages.length - 1) return true;
    final current = messages[index].sentAt;
    final next = messages[index + 1].sentAt;
    return current.year != next.year ||
        current.month != next.month ||
        current.day != next.day;
  }
}

// ── Read-only info banner ──────────────────────────────────────────────────────

class _ParticipantHeader extends StatelessWidget {
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;
  const _ParticipantHeader({
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: InkWell(
        key: const Key('chat-participant-header'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
          child: child,
        ),
      ),
    );
  }
}

/// Fin de la coupure de messagerie du compte connecté, `null` sans coupure.
/// Sans `AuthBloc` au-dessus (tests d'écran isolés), la saisie reste ouverte :
/// Firestore reste le seul point d'application de la coupure.
class _MessagingMuteGate extends StatelessWidget {
  const _MessagingMuteGate({required this.builder});

  final Widget Function(DateTime? mutedUntil) builder;

  static AuthBloc? maybeAuthBloc(BuildContext context) {
    try {
      return BlocProvider.of<AuthBloc>(context);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _mutedUntil(AuthState state) {
    final user = state.currentUser;
    return (user?.isMessagingMuted() ?? false)
        ? user!.messagingMutedUntil
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = maybeAuthBloc(context);
    if (auth == null) return builder(null);
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: auth,
      buildWhen: (a, b) => _mutedUntil(a) != _mutedUntil(b),
      builder: (context, state) => builder(_mutedUntil(state)),
    );
  }
}

/// Remplace la saisie quand un administrateur a coupé la messagerie du
/// compte : l'utilisateur sait pourquoi il ne peut plus écrire, et jusqu'à
/// quand. Le motif de la coupure n'est jamais affiché.
class _MutedBanner extends StatelessWidget {
  const _MutedBanner({required this.until});

  final DateTime until;

  /// Au-delà, la coupure est « jusqu'à nouvel ordre » (le back pose 100 ans).
  static const _indefinite = Duration(days: 365 * 10);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final indefinite = until.difference(DateTime.now()) > _indefinite;
    final local = until.toLocal();
    final description = indefinite
        ? l.chatMessagingMutedIndefinite
        : l.chatMessagingMutedUntil(
            DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).add_Hm().format(local),
          );
    return Container(
      key: const Key('chat-messaging-muted'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon('lock', size: 18, color: cs.error),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  l.chatMessagingMutedTitle,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            description,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => unawaited(context.push<void>('/support')),
              child: Text(l.chatMessagingMutedContactSupport),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  const _ReadOnlyBanner({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        children: [
          DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Text(
              context.l10n.chatReadOnlyBannerMessage,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip banner ────────────────────────────────────────────────────────────────

class _TripBanner extends StatelessWidget {
  final ConversationModel conversation;
  final ColorScheme cs;
  final TextTheme tt;
  final bool disabled;
  final VoidCallback onTap;

  const _TripBanner({
    required this.conversation,
    required this.cs,
    required this.tt,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled ? cs.surfaceContainerLowest : cs.surface,
      child: InkWell(
        key: const Key('chat-trip-banner'),
        onTap: disabled ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                10,
                DonySpacing.sm,
                10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: DonyIcon('plane', size: 16, color: cs.primary),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          conversation.viewerIsRecipient
                              ? context.l10n.chatLinkedParcelLabel
                              : context.l10n.chatLinkedTripLabel,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          conversation.tripLabel!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DonyIcon(
                    'chevron-right',
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ── Bid status banner ──────────────────────────────────────────────────────────

class _BidStatusBanner extends StatelessWidget {
  final String status;
  final ColorScheme cs;
  final TextTheme tt;

  const _BidStatusBanner({
    required this.status,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (String, Color, String?)? config = switch (status) {
      'BID_ACCEPTED' => (l.chatBidStatusAccepted, cs.success, 'circle-check'),
      'DELIVERY_CONFIRMED' => (
        l.chatBidStatusDeliveryConfirmed,
        cs.success,
        'package',
      ),
      'TRIP_CANCELLED' => (l.chatBidStatusTripCancelled, cs.error, 'circle-x'),
      _ => null,
    };
    if (config == null) return const SizedBox.shrink();

    final (label, color, iconAsset) = config;
    return Container(
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          if (iconAsset == 'package')
            const DonyEmoji.parcel(size: 14)
          else if (iconAsset != null)
            DonyIcon(iconAsset, size: 14, color: color),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  final ColorScheme cs;
  final TextTheme tt;

  const _DateSeparator({
    required this.date,
    required this.cs,
    required this.tt,
  });

  String _label(AppLocalizations l) {
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final isYesterday = now.difference(date).inDays == 1;
    if (isToday) return l.commonDateToday;
    if (isYesterday) return l.commonDateYesterday;
    return DateFormat.yMMMMd(l.localeName).format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Text(
            _label(context.l10n),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isLastOfGroup;

  /// Citation affichée au-dessus du contenu, `null` hors réponse.
  final _QuoteData? quote;

  /// Cite ce message dans la saisie ; `null` quand on ne peut pas y répondre
  /// (fil en lecture seule, message supprimé ou système).
  final VoidCallback? onReply;

  /// Défile jusqu'au message cité ; `null` s'il n'est pas dans le fil chargé.
  final VoidCallback? onQuoteTap;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isLastOfGroup = true,
    this.quote,
    this.onReply,
    this.onQuoteTap,
  });

  /// Photo ou position : pas de texte sélectionnable, l'appui long ouvre un
  /// menu « Répondre » à l'endroit du doigt. Le texte, lui, l'ajoute à son
  /// menu de sélection natif (cf. [_TextContent]).
  Future<void> _showReplyMenu(BuildContext context, Offset at) async {
    final onReply = this.onReply;
    if (onReply == null) return;
    unawaited(HapticFeedback.mediumImpact());
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final chosen = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.sm),
              Text(l.chatReplyAction),
            ],
          ),
        ),
      ],
    );
    if (chosen == true) onReply();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              message.isDeleted ? l.chatMessageDeleted : (message.body ?? ''),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Coin « queue » uniquement sur le dernier d'un groupe.
    final tail = Radius.circular(
      isLastOfGroup ? DonyRadius.xs : DonyRadius.card,
    );
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(DonyRadius.card),
      topRight: const Radius.circular(DonyRadius.card),
      bottomLeft: isMe ? const Radius.circular(DonyRadius.card) : tail,
      bottomRight: isMe ? tail : const Radius.circular(DonyRadius.card),
    );

    final replyLabel = l.chatReplyAction;
    final onReply = this.onReply;
    final longPressable =
        onReply != null &&
        (message.type == MessageType.image ||
            message.type == MessageType.location);
    Widget bubble = Padding(
      padding: EdgeInsets.only(bottom: isLastOfGroup ? DonySpacing.sm : 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isMe ? cs.primary : cs.surface,
                      borderRadius: radius,
                      // Bulle reçue : ombre douce, SANS bordure (principe
                      // « ombres > bordures »). Bulle envoyée : aplat coloré.
                      boxShadow: isMe
                          ? null
                          : [
                              const BoxShadow(
                                color: DonyColors.shadow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _withQuote(
                      message.isDeleted
                          ? _DeletedContent(isMe: isMe, cs: cs, tt: tt)
                          : message.type == MessageType.image
                          ? _ImageContent(imageUrl: message.imageUrl)
                          : message.type == MessageType.location
                          ? _LocationContent(
                              latitude: message.latitude ?? 0,
                              longitude: message.longitude ?? 0,
                              isMe: isMe,
                              cs: cs,
                              tt: tt,
                            )
                          : _TextContent(
                              body: message.body ?? '',
                              isMe: isMe,
                              cs: cs,
                              tt: tt,
                              onReply: onReply,
                            ),
                    ),
                  ),
                  // Horodatage + accusé : seulement sur le dernier du groupe.
                  if (isLastOfGroup) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.jm(
                            l.localeName,
                          ).format(message.sentAt.toLocal()),
                          style: tt.bodySmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          DonyIcon(
                            message.readAt != null ? 'check-check' : 'check',
                            size: 12,
                            color: message.readAt != null
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onReply == null) return bubble;
    if (longPressable) {
      bubble = GestureDetector(
        onLongPressStart: (details) =>
            unawaited(_showReplyMenu(context, details.globalPosition)),
        child: bubble,
      );
    }
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: replyLabel): onReply,
      },
      child: _SwipeToReply(onReply: onReply, child: bubble),
    );
  }

  Widget _withQuote(Widget content) {
    final quote = this.quote;
    if (quote == null) return content;
    // La citation prend la largeur du contenu (ou la sienne si plus large) :
    // IntrinsicWidth aligne les deux blocs sans étirer une bulle courte.
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuoteBlock(quote: quote, isMe: isMe, onTap: onQuoteTap),
          content,
        ],
      ),
    );
  }
}

// ── Réponse à un message (FLUTTER-86) ─────────────────────────────────────────

/// Citation reconstituée à l'affichage : [message] `null` et [pending] faux
/// pour un message introuvable ; [inThread] quand il est dans le fil chargé
/// (un tap y fait défiler).
class _QuoteData {
  final MessageModel? message;
  final String? author;
  final bool inThread;
  final bool pending;
  const _QuoteData({this.message, this.author, this.inThread = false})
    : pending = false;
  const _QuoteData.pending()
    : message = null,
      author = null,
      inThread = false,
      pending = true;
}

/// Une ligne d'aperçu d'un message cité : icône éventuelle + libellé.
/// `italic` pour les états (supprimé, introuvable, chargement).
(String? icon, String text, bool italic) _quoteSnippet(
  AppLocalizations l,
  MessageModel? message, {
  bool pending = false,
}) {
  if (pending) return (null, l.chatQuoteLoading, true);
  if (message == null) return (null, l.chatQuoteUnavailable, true);
  if (message.isDeleted) return (null, l.chatMessageDeleted, true);
  return switch (message.type) {
    MessageType.image => ('image', l.chatQuotePhoto, false),
    MessageType.location => ('map-pin', l.chatQuoteLocation, false),
    _ => (null, message.body ?? '', false),
  };
}

class _QuoteBlock extends StatelessWidget {
  final _QuoteData quote;
  final bool isMe;
  final VoidCallback? onTap;
  const _QuoteBlock({required this.quote, required this.isMe, this.onTap});

  // Retrait de la citation dans la bulle : rayon intérieur concentrique
  // (rayon de la bulle − retrait).
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final (icon, text, italic) = _quoteSnippet(
      l,
      quote.message,
      pending: quote.pending,
    );
    final accent = isMe ? cs.onPrimary : cs.primary;
    final muted = isMe
        ? cs.onPrimary.withValues(alpha: 0.78)
        : cs.onSurfaceVariant;
    final author = quote.author;
    final radius = BorderRadius.circular(DonyRadius.card - _inset);

    final body = Container(
      decoration: BoxDecoration(
        color: isMe
            ? cs.onPrimary.withValues(alpha: 0.16)
            : cs.primary.withValues(alpha: 0.07),
        borderRadius: radius,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.sm,
        DonySpacing.xs + 2,
        DonySpacing.sm,
        DonySpacing.xs + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author != null)
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                DonyIcon(icon, size: 13, color: muted),
                const SizedBox(width: DonySpacing.xs),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: muted,
                    fontStyle: italic ? FontStyle.italic : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final onTap = this.onTap;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, 0),
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              hint: l.chatQuoteShowSemantics,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const Key('chat-quote-tap'),
                  borderRadius: radius,
                  onTap: onTap,
                  child: body,
                ),
              ),
            ),
    );
  }
}

/// Balayage vers la droite sur une bulle pour y répondre. Le geste ne
/// démarre que sur la bulle, jamais au bord gauche de l'écran : le retour
/// iOS par le bord garde la priorité. Au-delà du seuil, retour haptique ;
/// relâché au-delà, la réponse démarre. La bulle revient toujours en place.
///
/// Suivi par pointeur brut ([Listener]) et non par un recognizer : le texte
/// sélectionnable de la bulle gagnerait l'arène des glissements horizontaux
/// et le balayage ne partirait jamais. Le geste ne s'engage que nettement
/// horizontal, le défilement vertical du fil n'est donc pas gêné.
class _SwipeToReply extends StatefulWidget {
  final VoidCallback onReply;
  final Widget child;
  const _SwipeToReply({required this.onReply, required this.child});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _threshold = 56.0;
  static const _maxOffset = 72.0;

  /// Zone du bord gauche réservée au retour iOS (20 pt côté Cupertino).
  static const _edgeGuard = 28.0;

  late final AnimationController _offset = AnimationController(
    vsync: this,
    upperBound: _maxOffset,
  );
  int? _pointer;
  Offset _start = Offset.zero;
  bool _engaged = false;
  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    final edge = _edgeGuard + MediaQuery.paddingOf(context).left;
    if (event.position.dx <= edge) return;
    _pointer = event.pointer;
    _start = event.position;
    _engaged = false;
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (!_engaged) {
      final moved = event.position - _start;
      if (moved.dx > kTouchSlop && moved.dx > moved.dy.abs() * 2) {
        _engaged = true;
      } else if (moved.distance > kTouchSlop) {
        // Défilement ou glissement vers la gauche : on s'efface.
        _pointer = null;
      }
      return;
    }
    // Résistance croissante : la bulle suit le doigt puis freine.
    final resistance = 1 - (_offset.value / _maxOffset) * 0.6;
    _offset.value = (_offset.value + event.delta.dx * resistance).clamp(
      0.0,
      _maxOffset,
    );
    final armed = _offset.value >= _threshold;
    if (armed && !_armed) unawaited(HapticFeedback.selectionClick());
    _armed = armed;
  }

  void _onRelease(PointerEvent event, {required bool cancelled}) {
    if (event.pointer != _pointer) return;
    if (_armed && !cancelled) widget.onReply();
    _pointer = null;
    _engaged = false;
    _armed = false;
    unawaited(
      _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (e) => _onRelease(e, cancelled: false),
      onPointerCancel: (e) => _onRelease(e, cancelled: true),
      child: AnimatedBuilder(
        animation: _offset,
        child: widget.child,
        builder: (context, child) {
          final progress = (_offset.value / _threshold).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.25 + 0.75 * progress,
                      child: Icon(
                        Icons.reply_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(_offset.value, 0),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Surlignage bref de la bulle atteinte depuis une citation.
class _HighlightFlash extends StatelessWidget {
  final bool active;
  final Widget child;
  const _HighlightFlash({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: active ? 0.10 : 0),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: child,
    );
  }
}

/// Barre « Réponse à … ✕ » au-dessus de la saisie, puis la saisie. La barre
/// entre et sort en glissant (taille + fondu), sans pousser la saisie d'un
/// coup.
class _ComposeArea extends StatelessWidget {
  final MessageModel? replyingTo;
  final bool replyAuthorIsMe;
  final String otherName;
  final VoidCallback onCancelReply;
  final Widget input;
  const _ComposeArea({
    required this.replyingTo,
    required this.replyAuthorIsMe,
    required this.otherName,
    required this.onCancelReply,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    final replyingTo = this.replyingTo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.bottomCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: replyingTo == null
              ? const SizedBox(width: double.infinity)
              : _ReplyBar(
                  key: ValueKey(replyingTo.id),
                  message: replyingTo,
                  title: replyAuthorIsMe
                      ? context.l10n.chatReplyingToSelf
                      : context.l10n.chatReplyingTo(otherName),
                  onCancel: onCancelReply,
                ),
        ),
        input,
      ],
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final MessageModel message;
  final String title;
  final VoidCallback onCancel;
  const _ReplyBar({
    super.key,
    required this.message,
    required this.title,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final (icon, text, italic) = _quoteSnippet(l, message);
    return Container(
      key: const Key('chat-reply-bar'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.xs,
        0,
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 20, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          Container(width: 3, height: 34, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    if (icon != null) ...[
                      DonyIcon(icon, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: DonySpacing.xs),
                    ],
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: italic ? FontStyle.italic : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('chat-reply-cancel'),
            tooltip: l.chatReplyCancelSemantics,
            onPressed: onCancel,
            icon: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Bubble content widgets ─────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final String body;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;

  /// Ajoute « Répondre » en tête du menu de sélection (FLUTTER-86).
  final VoidCallback? onReply;
  const _TextContent({
    required this.body,
    required this.isMe,
    required this.cs,
    required this.tt,
    this.onReply,
  });

  // « Copier le message » recopie la bulle entière : une adresse ou un
  // numéro reçu se recolle ailleurs (Sentry FLUTTER-5F).
  Future<void> _copy(BuildContext context) async {
    final message = context.l10n.chatMessageCopied;
    unawaited(HapticFeedback.mediumImpact());
    await Clipboard.setData(ClipboardData(text: body));
    if (!context.mounted) return;
    DonySnackbar.show(
      context,
      message: message,
      type: DonySnackbarType.success,
    );
  }

  // Texte sélectionnable : l'appui long sélectionne un mot (un code, un
  // numéro) et ouvre le menu natif (Copier, Tout sélectionner…), auquel on
  // ajoute « Copier le message » pour la bulle entière (Sentry FLUTTER-7H :
  // l'ancien appui long copiait toujours tout, impossible de n'en prendre
  // qu'un mot). Le lecteur d'écran garde la copie de la bulle entière par
  // une action dédiée.
  @override
  Widget build(BuildContext context) {
    final copyLabel = context.l10n.chatCopyMessageAction;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: copyLabel): () => _copy(context),
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        child: isMe
            ? Theme(
                data: Theme.of(
                  context,
                ).copyWith(textSelectionTheme: ownBubbleSelectionTheme(cs)),
                child: _selectable(context, copyLabel),
              )
            : _selectable(context, copyLabel),
      ),
    );
  }

  Widget _selectable(BuildContext context, String copyLabel) {
    return SelectableText(
      body,
      style: tt.bodyMedium?.copyWith(color: isMe ? cs.onPrimary : cs.onSurface),
      contextMenuBuilder: (menuContext, editableTextState) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: [
              if (onReply case final reply?)
                ContextMenuButtonItem(
                  label: context.l10n.chatReplyAction,
                  onPressed: () {
                    editableTextState.hideToolbar();
                    reply();
                  },
                ),
              ...editableTextState.contextMenuButtonItems,
              ContextMenuButtonItem(
                label: copyLabel,
                onPressed: () {
                  editableTextState.hideToolbar();
                  _copy(context);
                },
              ),
            ],
          ),
    );
  }
}

/// Sélection dans sa propre bulle (fond `primary`, texte `onPrimary`) : le
/// surlignage par défaut est lui aussi `primary`, le texte sélectionné
/// disparaissait (Sentry FLUTTER-8E). Voile sombre sous le texte blanc, et
/// poignées foncées, lisibles sur la bulle comme sur le fond clair du fil.
@visibleForTesting
TextSelectionThemeData ownBubbleSelectionTheme(ColorScheme cs) {
  return TextSelectionThemeData(
    selectionColor: Colors.black.withValues(alpha: 0.32),
    selectionHandleColor: cs.onSurface,
    cursorColor: cs.onPrimary,
  );
}

class _ImageContent extends StatelessWidget {
  final String? imageUrl;
  const _ImageContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card - 1),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        cacheKey: DonyImage.stableCacheKey(imageUrl!),
        width: 220,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (_, _) => Builder(
          builder: (context) => Container(
            width: 220,
            height: 180,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Builder(
          builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Container(
              width: 220,
              height: 180,
              color: cs.surfaceContainerHighest,
              child: DonyIcon('image-off', color: cs.onSurfaceVariant),
            );
          },
        ),
      ),
    );
  }
}

class _LocationContent extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;

  const _LocationContent({
    required this.latitude,
    required this.longitude,
    required this.isMe,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('map-pin', size: 20, color: isMe ? cs.onPrimary : cs.error),
          const SizedBox(width: DonySpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.chatLocationMessageLabel,
                style: tt.bodySmall?.copyWith(
                  color: isMe ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                style: tt.labelSmall?.copyWith(
                  color: isMe
                      ? cs.onPrimary.withValues(alpha: 0.65)
                      : cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeletedContent extends StatelessWidget {
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;
  const _DeletedContent({
    required this.isMe,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(
            'ban',
            size: 14,
            color: isMe
                ? cs.onPrimary.withValues(alpha: 0.6)
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.xs),
          Text(
            context.l10n.chatMessageDeleted,
            style: tt.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: isMe
                  ? cs.onPrimary.withValues(alpha: 0.6)
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar (F1 — texte uniquement) ──────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isSending;
  final bool disabled;

  /// Faux sous la barre de réponse, qui porte alors le filet supérieur.
  final bool showTopBorder;
  final VoidCallback onSendText;

  const _InputBar({
    required this.controller,
    this.focusNode,
    required this.isSending,
    this.disabled = false,
    this.showTopBorder = true,
    required this.onSendText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    if (disabled) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Text(
              l.chatSendingDisabled,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: 160.ms,
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: showTopBorder
              ? Border(top: BorderSide(color: cs.outlineVariant))
              : null,
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        // F1 : une seule pill — champ + bouton envoi à l'intérieur.
        child: Container(
          constraints: const BoxConstraints(maxHeight: 132),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.only(left: DonySpacing.base, right: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: null,
                  minLines: 1,
                  maxLength: ChatMessageRules.maxLength,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: l.chatMessageHint,
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return AnimatedScale(
                      scale: hasText ? 1.0 : 0.85,
                      duration: 150.ms,
                      curve: Curves.easeOutCubic,
                      child: Material(
                        color: hasText ? cs.primary : cs.outlineVariant,
                        shape: const CircleBorder(),
                        // Bouton à icône seule, et seul moyen d'envoyer un
                        // message depuis que le chat est le canal de contact
                        // unique. Sans nom accessible il était annoncé
                        // « bouton », sans plus.
                        child: Semantics(
                          button: true,
                          enabled: hasText && !isSending,
                          label: l.chatSendMessageSemantics,
                          container: true,
                          excludeSemantics: true,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: hasText && !isSending ? onSendText : null,
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: DonyIcon(
                                'send',
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
