import 'dart:async';

import 'package:dony/app/main_shell.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_visibility.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_bubble.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Chemin de l'écran réellement affiché, pages poussées comprises.
///
/// `currentConfiguration.uri` ne bouge pas sur un `push` (la route poussée est
/// une `ImperativeRouteMatch` posée par-dessus) : lu tel quel, il garderait
/// l'écran du dessous et la bulle resterait affichée sur `/assistant` ou sur
/// un écran de paiement poussé.
@visibleForTesting
String visibleRoutePath(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) return '';
  final last = config.last;
  final list = last is ImperativeRouteMatch ? last.matches : config;
  return list.uri.path;
}

/// Couche de la bulle flottante de l'assistant, montée une seule fois dans le
/// `builder` de `MaterialApp.router` (voir `app.dart`), au-dessus de toutes
/// les routes.
///
/// À placer dans un `Stack` : elle occupe toute la zone (`Positioned.fill`)
/// mais ne capte aucun toucher en dehors de la bulle. Ce n'est pas un enfant
/// « normal » du `Stack` exprès : un enfant non positionné vide réduirait le
/// `Stack`, donc l'app entière, à zéro.
///
/// Elle ne montre rien tant que la sonde `GET /assistant/status` n'a pas
/// répondu « disponible » (`AssistantState.available`, faux par défaut), pour
/// un invité, quand l'utilisateur l'a masquée, clavier ouvert, sous une feuille
/// ou un dialogue, sur un écran à caméra ([HideAssistantBubble]), ni sur les
/// écrans listés dans [isAssistantBubbleExcludedLocation].
///
/// C'est aussi elle qui lance la sonde : à l'entrée en session connectée, puis
/// au retour au premier plan (au plus une fois toutes les 10 minutes, le BLoC
/// y veille).
class AssistantBubbleOverlay extends StatefulWidget {
  const AssistantBubbleOverlay({super.key, this.router, this.blockers});

  /// Routeur à suivre ; `appRouter` par défaut (tests : un routeur local).
  final GoRouter? router;

  /// Bloqueurs à suivre ; ceux de l'app par défaut (tests : un registre local).
  final AssistantBubbleBlockers? blockers;

  @override
  State<AssistantBubbleOverlay> createState() => _AssistantBubbleOverlayState();
}

class _AssistantBubbleOverlayState extends State<AssistantBubbleOverlay> {
  late final AssistantBloc _assistant = getIt<AssistantBloc>();
  late final ValueNotifier<bool> _signedIn;
  StreamSubscription<AuthState>? _authSub;
  AppLifecycleListener? _lifecycle;

  /// Dernier chemin vu et état de l'aide : l'aide se ferme (et s'écrit) dès
  /// que l'utilisateur change de route, sans jamais revenir.
  String? _lastPath;
  bool _hintShown = false;
  bool _hintClosed = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>();
    _signedIn = ValueNotifier<bool>(
      assistantSignedInAfter(auth.state, previous: false),
    );
    _authSub = auth.stream.listen(_onAuth);
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    if (_signedIn.value) _assistant.add(const AssistantStatusRequested());
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    _lifecycle?.dispose();
    _signedIn.dispose();
    super.dispose();
  }

  void _onAuth(AuthState state) {
    final next = assistantSignedInAfter(state, previous: _signedIn.value);
    if (next == _signedIn.value) return;
    _signedIn.value = next;
    if (next) _assistant.add(const AssistantStatusRequested());
  }

  void _onResume() {
    if (_signedIn.value) {
      _assistant.add(const AssistantStatusRequested(force: false));
    }
  }

  /// Ferme l'aide pour de bon : une seule écriture, quelle que soit la cause
  /// (toucher, glissement, délai, changement de route).
  void _closeHint(AppPreferencesBloc prefs) {
    if (_hintClosed) return;
    _hintClosed = true;
    prefs.add(const AssistantHintDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final router = widget.router ?? appRouter;
    final blockers = widget.blockers ?? assistantBubbleBlockers;
    return Positioned.fill(
      child: BlocProvider<AssistantBloc>.value(
        value: _assistant,
        child: ValueListenableBuilder<bool>(
          valueListenable: _signedIn,
          builder: (context, signedIn, _) => ListenableBuilder(
            // La bulle est hors de tout écran : le chemin courant vient du
            // routeur. Lecture seule, jamais de `go`/`push` pendant la
            // notification (le `push` part d'un toucher).
            listenable: Listenable.merge([
              router.routerDelegate,
              blockers.active,
            ]),
            builder: (context, _) =>
                _buildBubble(context, router, blockers, signedIn),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    GoRouter router,
    AssistantBubbleBlockers blockers,
    bool signedIn,
  ) {
    final path = visibleRoutePath(router);
    final (enabled, side, y, hintSeen) = context
        .select<AppPreferencesBloc, (bool, String, double, bool)>((bloc) {
          final p = bloc.state.preferences;
          return (
            p.assistantBubbleEnabled,
            p.assistantBubbleSide,
            p.assistantBubbleY,
            p.assistantHintSeen,
          );
        });
    final disabled = context.select<AssistantBloc, bool>(
      (bloc) => bloc.state.disabled,
    );
    final available = context.select<AssistantBloc, bool>(
      (bloc) => bloc.state.available,
    );
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final prefs = context.read<AppPreferencesBloc>();

    // L'aide ne survit pas à un changement de route : fermée et écrite une
    // fois, sans repartir si l'utilisateur revient sur l'écran.
    final routeChanged = _lastPath != null && _lastPath != path;
    _lastPath = path;
    if (routeChanged && _hintShown && !hintSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeHint(prefs);
      });
    }

    final visible =
        !blockers.active.value &&
        shouldShowAssistantBubble(
          path: path,
          signedIn: signedIn,
          enabled: enabled,
          disabled: disabled,
          available: available,
          keyboardOpen: keyboardOpen,
        );
    if (!visible) return const SizedBox.shrink();

    final showHint = !hintSeen && !_hintClosed && !(routeChanged && _hintShown);
    _hintShown = showHint;
    return AssistantBubble(
      side: side,
      yFraction: y,
      bottomInset: MainShell.navBarContentHeight,
      showHint: showHint,
      onTap: () {
        if (!hintSeen) _closeHint(prefs);
        // `AssistantOpened('bubble')` part de l'écran lui-même, à partir de
        // `?source=` : l'envoyer ici doublerait l'événement
        // `assistant_opened`.
        unawaited(router.push('/assistant?source=bubble'));
      },
      onMoved: (side, y) => prefs.add(AssistantBubbleMoved(side, y)),
      onHintDismissed: () => _closeHint(prefs),
    );
  }
}
