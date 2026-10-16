import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Rayons des bulles : l'angle côté auteur est resserré, comme sur la maquette.
const double _bubbleRadius = 18;
const double _bubbleTail = 4;

/// Taille minimale d'une cible tactile.
const double _minTarget = 44;

/// Entrée courte d'une bulle (fondu + léger glissement vers le haut).
///
/// `TweenAnimationBuilder` plutôt qu'un contrôleur : l'animation reste
/// interruptible (une reconstruction ne la relance pas) et ne laisse aucun
/// `Ticker` à disposer. Inactive quand le système réduit les animations ou
/// pour les bulles déjà présentes à l'ouverture de l'écran.
class AssistantEntrance extends StatelessWidget {
  const AssistantEntrance({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: DonyDuration.base,
      curve: DonyCurve.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Bulle de texte brut (jamais de Markdown) de l'utilisateur ou de l'assistant.
class AssistantBubbleShell extends StatelessWidget {
  const AssistantBubbleShell({
    super.key,
    required this.fromUser,
    required this.child,
    this.maxWidthFactor,
  });

  final bool fromUser;
  final Widget child;
  final double? maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final factor = maxWidthFactor ?? (fromUser ? 0.8 : 0.88);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * factor),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fromUser ? cs.primary : cs.surface,
            border: fromUser ? null : Border.all(color: cs.outline),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(fromUser ? _bubbleRadius : _bubbleTail),
              topRight: const Radius.circular(_bubbleRadius),
              bottomLeft: const Radius.circular(_bubbleRadius),
              bottomRight: Radius.circular(
                fromUser ? _bubbleTail : _bubbleRadius,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: child,
          ),
        ),
      ),
    );
  }
}

TextStyle _bodyStyle(BuildContext context, Color color) => Theme.of(
  context,
).textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.45, color: color);

/// Message d'accueil + mention IA, en tête de toute conversation.
class AssistantWelcomeBubble extends StatelessWidget {
  const AssistantWelcomeBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return AssistantBubbleShell(
      fromUser: false,
      maxWidthFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.assistantWelcome, style: _bodyStyle(context, cs.onSurface)),
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.assistantDisclaimer,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Message simple de l'assistant sans action (avis de quota, par exemple).
class AssistantNoticeBubble extends StatelessWidget {
  const AssistantNoticeBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => AssistantBubbleShell(
    fromUser: false,
    child: Text(
      text,
      style: _bodyStyle(context, Theme.of(context).colorScheme.onSurface),
    ),
  );
}

/// Trois points qui pulsent pendant que l'assistant écrit.
///
/// Statiques quand le système réduit les animations. `AnimationController`
/// manuel (comme `DonyPulsingDot`) : aucun `Timer` en attente dans un test qui
/// ne fait qu'un `pump()`.
class AssistantTypingBubble extends StatefulWidget {
  const AssistantTypingBubble({super.key});

  @override
  State<AssistantTypingBubble> createState() => _AssistantTypingBubbleState();
}

class _AssistantTypingBubbleState extends State<AssistantTypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('assistant-typing'),
      label: context.l10n.assistantTyping,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_bubbleTail),
                topRight: Radius.circular(_bubbleRadius),
                bottomLeft: Radius.circular(_bubbleRadius),
                bottomRight: Radius.circular(_bubbleRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      _Dot(color: cs.onSurfaceVariant, opacity: _dotOpacity(i)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chaque point est décalé d'un tiers de cycle ; au repos (animations
  /// réduites) les trois sont à demi opaques.
  double _dotOpacity(int index) {
    if (!_controller.isAnimating) return 0.6;
    final phase = (_controller.value - index / 3) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * wave;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(width: 7, height: 7),
    ),
  );
}

/// Un message de la conversation, avec ses actions, ses pouces et le passage
/// à un humain.
///
/// [actions] ne contient que les actions dont la route existe dans l'app : le
/// filtrage et le signalement des autres sont faits par l'écran.
class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({
    super.key,
    required this.message,
    required this.actions,
    required this.onAction,
    required this.onFeedback,
    required this.onTalkToHuman,
    this.onRetry,
  });

  final AssistantMessage message;
  final List<AssistantAction> actions;
  final ValueChanged<AssistantAction> onAction;
  final ValueChanged<bool> onFeedback;
  final VoidCallback onTalkToHuman;

  /// Non nul seulement sur le message d'erreur de la dernière question.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (message.author == AssistantAuthor.user) {
      return AssistantBubbleShell(
        fromUser: true,
        child: Text(message.text, style: _bodyStyle(context, cs.onPrimary)),
      );
    }
    if (message.isError) return _errorBubble(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssistantBubbleShell(
          fromUser: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message.text, style: _bodyStyle(context, cs.onSurface)),
              for (final action in actions) ...[
                const SizedBox(height: 10),
                _ActionButton(action: action, onTap: () => onAction(action)),
              ],
            ],
          ),
        ),
        _Reactions(
          message: message,
          onFeedback: onFeedback,
          onTalkToHuman: onTalkToHuman,
        ),
      ],
    );
  }

  Widget _errorBubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return AssistantBubbleShell(
      fromUser: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.assistantError, style: _bodyStyle(context, cs.onSurface)),
          if (onRetry != null)
            TextButton(
              key: const Key('assistant-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(_minTarget, _minTarget),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(l.assistantRetry),
            ),
        ],
      ),
    );
  }
}

/// « Y aller : … » : bouton plein vers un écran de l'app.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});

  final AssistantAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyPressable(
      key: Key('assistant-action-${action.route}'),
      onTap: onTap,
      child: Semantics(
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.assistantGoTo(action.label),
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pouces et « Parler à un humain » sous une réponse.
class _Reactions extends StatelessWidget {
  const _Reactions({
    required this.message,
    required this.onFeedback,
    required this.onTalkToHuman,
  });

  final AssistantMessage message;
  final ValueChanged<bool> onFeedback;
  final VoidCallback onTalkToHuman;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final up = message.feedback == 'up';
    final down = message.feedback == 'down';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: Key('assistant-thumb-up-${message.id}'),
            tooltip: l.assistantThumbUp,
            onPressed: () => onFeedback(true),
            constraints: const BoxConstraints(
              minWidth: _minTarget,
              minHeight: _minTarget,
            ),
            icon: Icon(
              up ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
              size: 18,
              color: up ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          IconButton(
            key: Key('assistant-thumb-down-${message.id}'),
            tooltip: l.assistantThumbDown,
            onPressed: () => onFeedback(false),
            constraints: const BoxConstraints(
              minWidth: _minTarget,
              minHeight: _minTarget,
            ),
            icon: Icon(
              down
                  ? Icons.thumb_down_alt_rounded
                  : Icons.thumb_down_alt_outlined,
              size: 18,
              color: down ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          TextButton(
            key: Key('assistant-human-${message.id}'),
            onPressed: onTalkToHuman,
            style: TextButton.styleFrom(
              minimumSize: const Size(_minTarget, _minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: cs.primary,
            ),
            child: Text(
              l.assistantTalkToHuman,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
