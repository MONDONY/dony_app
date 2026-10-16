import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_composer.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_escalation_card.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_message_bubble.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_route_check.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran `/assistant` : conversation avec l'assistant IA de l'app.
///
/// À fournir avec `BlocProvider.value(value: getIt<AssistantBloc>())` : le BLoC
/// est un singleton qui garde l'historique, un `create` le fermerait à la
/// sortie de l'écran.
///
/// Pas de `setState` : le contrôleur de saisie, le défilement et l'ensemble
/// des actions déjà signalées vivent dans le `State`, l'affichage suit le BLoC
/// et le `ValueListenableBuilder` du composeur.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.source = 'bubble'});

  /// D'où l'écran est ouvert : `bubble` ou `messages_header` (analytics).
  final String source;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _sources = {'bubble', 'messages_header'};

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Incrémenté à chaque geste de l'utilisateur sur la liste : un défilement
  /// vers la réponse lancé avant ce geste ne le ramène plus au bas.
  int _userDragGeneration = 0;

  /// Actions inconnues déjà signalées (`<id du message>|<route>`) : une fois
  /// par message, pas à chaque reconstruction.
  final Set<String> _reportedUnmatched = {};

  /// Dernier identifiant présent à l'ouverture : seuls les messages arrivés
  /// ensuite jouent l'animation d'entrée.
  int? _baselineId;

  /// Identifiants dont l'entrée est terminée. La liste détruit les éléments
  /// qui sortent de la zone visible : sans cette mémoire, une bulle déjà
  /// animée rejouerait son fondu en y revenant.
  final Set<int> _entered = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AssistantBloc>().add(
        AssistantOpened(
          _sources.contains(widget.source) ? widget.source : 'bubble',
        ),
      );
      _scrollToEnd(animated: false);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _locale => context.l10n.localeName.startsWith('en') ? 'en' : 'fr';

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final generation = _userDragGeneration;
      final end = _scroll.position.maxScrollExtent;
      if (animated && !MediaQuery.disableAnimationsOf(context)) {
        // L'étendue du bas n'est qu'estimée tant que ses éléments ne sont pas
        // construits : l'animation peut s'arrêter avant le vrai bas.
        _scroll
            .animateTo(end, duration: DonyDuration.base, curve: DonyCurve.enter)
            .whenComplete(() => _settleAtEnd(generation));
      } else {
        _scroll.jumpTo(end);
        _settleAtEnd(generation);
      }
    });
  }

  /// Recolle au bas réel du contenu, en 3 passes au plus : chaque saut
  /// construit des éléments et affine l'étendue. Abandonne dès que
  /// l'utilisateur a touché la liste depuis le lancement ([generation]) : il
  /// remonte lire, on ne le ramène pas au bas.
  void _settleAtEnd(int generation, [int attemptsLeft = 2]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (generation != _userDragGeneration) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent - 1) return;
      _scroll.jumpTo(position.maxScrollExtent);
      if (attemptsLeft > 0) _settleAtEnd(generation, attemptsLeft - 1);
    });
  }

  void _send(String text, {bool fromSuggestion = false}) {
    context.read<AssistantBloc>().add(
      AssistantQuestionSubmitted(
        text,
        locale: _locale,
        fromSuggestion: fromSuggestion,
      ),
    );
  }

  void _onEscalationChanged(BuildContext context, AssistantState state) {
    final bloc = context.read<AssistantBloc>();
    switch (state.escalationStatus) {
      case AssistantEscalationStatus.success:
        final ticketId = state.escalatedTicketId;
        bloc.add(const AssistantEscalationHandled());
        if (ticketId != null) _navigate(context, '/support/tickets/$ticketId');
      case AssistantEscalationStatus.failure:
        bloc.add(const AssistantEscalationHandled());
        DonySnackbar.show(
          context,
          message: context.l10n.assistantEscalationFailed,
          type: DonySnackbarType.error,
        );
      case AssistantEscalationStatus.idle || AssistantEscalationStatus.sending:
        break;
    }
  }

  /// Actions dont la route existe dans l'app. Les autres sont masquées et
  /// signalées (`assistant_action_unmatched`) une fois par message.
  List<AssistantAction> _visibleActions(
    BuildContext context,
    AssistantMessage message,
    List<String> toReport,
  ) {
    final router = GoRouter.of(context);
    final visible = <AssistantAction>[];
    for (final action in message.actions) {
      if (assistantRouteExists(router, action.route)) {
        visible.add(action);
      } else if (_reportedUnmatched.add('${message.id}|${action.route}')) {
        toReport.add(action.route);
      }
    }
    return visible;
  }

  void _openAction(AssistantAction action) {
    context.read<AssistantBloc>().add(
      AssistantActionTapped(action.route, matched: true),
    );
    _navigate(context, action.route);
  }

  /// `go` pour une route du shell d'onglets (un `push` depuis `/assistant`,
  /// hors shell, dupliquerait le shell) ou qui porte une redirection (elle
  /// peut mener à un onglet), `push` sinon : le retour ramène à la
  /// conversation.
  void _navigate(BuildContext context, String route) {
    if (assistantRouteNeedsGo(GoRouter.of(context), route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _AssistantAppBar(
        onReset: () =>
            context.read<AssistantBloc>().add(const AssistantResetRequested()),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AssistantBloc, AssistantState>(
            listenWhen: (p, c) => p.escalationStatus != c.escalationStatus,
            listener: _onEscalationChanged,
          ),
          BlocListener<AssistantBloc, AssistantState>(
            listenWhen: (p, c) =>
                p.messages.length != c.messages.length ||
                p.isSending != c.isSending ||
                p.quotaExceeded != c.quotaExceeded,
            listener: (_, _) => _scrollToEnd(),
          ),
        ],
        child: BlocBuilder<AssistantBloc, AssistantState>(
          builder: (context, state) {
            if (state.messages.isEmpty) _reportedUnmatched.clear();
            _baselineId ??= state.messages.isEmpty
                ? -1
                : state.messages.last.id;
            if (state.disabled) return _unavailable(context, state);
            return Column(
              children: [
                Expanded(child: _conversation(context, state, cs)),
                AssistantComposer(
                  controller: _input,
                  busy: state.isSending,
                  onSend: _send,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _unavailable(BuildContext context, AssistantState state) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      children: [
        const SizedBox(height: DonySpacing.xl),
        Icon(Icons.auto_awesome_rounded, size: 40, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.base),
        Text(
          context.l10n.assistantUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge!.copyWith(color: cs.onSurface, height: 1.45),
        ),
        const SizedBox(height: DonySpacing.xl),
        AssistantEscalationCard(
          status: state.escalationStatus,
          onEscalate: _escalate,
        ),
      ],
    );
  }

  void _escalate() =>
      context.read<AssistantBloc>().add(const AssistantEscalationRequested());

  Widget _conversation(
    BuildContext context,
    AssistantState state,
    ColorScheme cs,
  ) {
    final l = context.l10n;
    final toReport = <String>[];
    final lastMessage = state.messages.isEmpty ? null : state.messages.last;
    final showEscalation =
        state.quotaExceeded ||
        (lastMessage != null &&
            lastMessage.author == AssistantAuthor.assistant &&
            !lastMessage.isError &&
            !lastMessage.answered);
    final children = <Widget>[
      const AssistantWelcomeBubble(),
      if (state.isEmpty) ...[
        const SizedBox(height: DonySpacing.base),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            l.assistantSuggestionsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium!.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        for (final (index, text) in [
          l.assistantSuggestion1,
          l.assistantSuggestion2,
          l.assistantSuggestion3,
          l.assistantSuggestion4,
        ].indexed)
          _SuggestionChip(
            key: Key('assistant-suggestion-${index + 1}'),
            text: text,
            onTap: () => _send(text, fromSuggestion: true),
          ),
      ],
      for (final message in state.messages)
        AssistantEntrance(
          key: ValueKey(message.id),
          shouldAnimate: () =>
              message.id > (_baselineId ?? -1) &&
              !_entered.contains(message.id),
          onEnd: () => _entered.add(message.id),
          child: AssistantMessageBubble(
            message: message,
            liveRegion: message.id > (_baselineId ?? -1),
            actions: _visibleActions(context, message, toReport),
            onAction: _openAction,
            onFeedback: (up) => context.read<AssistantBloc>().add(
              AssistantFeedbackGiven(message.id, up: up),
            ),
            onTalkToHuman: _escalate,
            onRetry:
                message.isError &&
                    identical(message, lastMessage) &&
                    state.lastFailedQuestion != null &&
                    !state.isSending
                ? () => context.read<AssistantBloc>().add(
                    AssistantRetryRequested(locale: _locale),
                  )
                : null,
          ),
        ),
      if (state.isSending) const AssistantTypingBubble(),
      if (state.quotaExceeded) AssistantNoticeBubble(text: l.assistantQuota),
      if (showEscalation)
        AssistantEscalationCard(
          status: state.escalationStatus,
          onEscalate: _escalate,
        ),
    ];
    if (toReport.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final bloc = context.read<AssistantBloc>();
        for (final route in toReport) {
          bloc.add(AssistantActionTapped(route, matched: false));
        }
      });
    }
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        // dragDetails n'est renseigné que pour un geste, jamais pour animateTo.
        if (notification.dragDetails != null) _userDragGeneration++;
        return false;
      },
      child: ListView.separated(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DonyPressable(
        onTap: onTap,
        child: Semantics(
          button: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre du haut : retour, étincelle, titre + pastille IA, menu et scarabée.
class _AssistantAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AssistantAppBar({required this.onReset});

  final VoidCallback onReset;

  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return AppBar(
      toolbarHeight: 64,
      scrolledUnderElevation: 0,
      leading: const DonyAppBarBackButton(),
      titleSpacing: 0,
      title: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.assistantTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          l.assistantBadge,
                          style: tt.labelMedium!.copyWith(color: cs.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l.assistantSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          key: const Key('assistant-menu'),
          tooltip: l.assistantMenu,
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (_) => onReset(),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              key: const Key('assistant-reset'),
              value: 'reset',
              child: Text(l.assistantReset),
            ),
          ],
        ),
        const DonyFeedbackButton(),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
