import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Registre de ce qui doit masquer la bulle de l'assistant sans changer de
/// route : feuilles et dialogues (voir [AssistantModalObserver]), écrans
/// plein écran qui affichent une caméra ([HideAssistantBubble]).
class AssistantBubbleBlockers {
  int _count = 0;

  /// `true` tant qu'au moins un bloqueur est actif.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Remet le registre à zéro (isolation entre tests).
  @visibleForTesting
  void reset() {
    _count = 0;
    active.value = false;
  }

  void acquire() {
    _count++;
    _sync();
  }

  void release() {
    if (_count > 0) _count--;
    _sync();
  }

  /// Notifie sans jamais le faire pendant la construction de l'arbre : les
  /// écouteurs (l'overlay) appellent `setState`.
  void _sync() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) => active.value = _count > 0);
    } else {
      active.value = _count > 0;
    }
  }
}

/// Registre de l'app.
final assistantBubbleBlockers = AssistantBubbleBlockers();

/// Observateur de l'app, posé sur `appRouter` (navigateur racine).
final assistantModalObserver = AssistantModalObserver();

/// Compte les routes modales (feuilles, dialogues) ouvertes sur le navigateur
/// racine, où `DonyBottomSheet.show(useRootNavigator: true)` et les dialogues
/// vivent : hors de `GoRouter`, donc invisibles pour le chemin courant.
class AssistantModalObserver extends NavigatorObserver {
  AssistantModalObserver([AssistantBubbleBlockers? blockers])
    : _blockers = blockers ?? assistantBubbleBlockers;

  final AssistantBubbleBlockers _blockers;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _blockers.acquire();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _blockers.release();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _blockers.release();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute) _blockers.release();
    if (newRoute is PopupRoute) _blockers.acquire();
  }
}

/// Masque la bulle de l'assistant tant que [child] est monté (écran avec
/// caméra plein écran).
class HideAssistantBubble extends StatefulWidget {
  const HideAssistantBubble({super.key, required this.child, this.blockers});

  final Widget child;
  final AssistantBubbleBlockers? blockers;

  @override
  State<HideAssistantBubble> createState() => _HideAssistantBubbleState();
}

class _HideAssistantBubbleState extends State<HideAssistantBubble> {
  late final AssistantBubbleBlockers _blockers =
      widget.blockers ?? assistantBubbleBlockers;

  @override
  void initState() {
    super.initState();
    _blockers.acquire();
  }

  @override
  void dispose() {
    _blockers.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
