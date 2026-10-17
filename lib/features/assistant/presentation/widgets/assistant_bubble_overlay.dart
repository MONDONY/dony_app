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

/// Écrans d'un colis : l'assistant ouvert depuis eux parle de ce colis.
const _parcelScreens = {'/bids/:bidId', '/receptions/:bidId'};

/// Adresse de l'assistant ouvert depuis la bulle : l'écran affiché (motif de
/// route, comme dans PostHog, ex. `/bids/:bidId`) pour qu'il l'explique, et le
/// colis de cet écran. Jamais de donnée de l'utilisateur : un motif et un
/// identifiant, revérifié par le back.
@visibleForTesting
String assistantLocationFrom(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final query = <String, String>{'source': 'bubble'};
  if (config.isNotEmpty) {
    final last = config.last;
    final list = last is ImperativeRouteMatch ? last.matches : config;
    final screen = list.fullPath;
    if (screen.isNotEmpty) query['screen'] = screen;
    final bidId = list.pathParameters['bidId'];
    if (_parcelScreens.contains(screen) && bidId != null && bidId.isNotEmpty) {
      query['parcel'] = bidId;
    }
  }
  return Uri(path: '/assistant', queryParameters: query).toString();
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
///
/// Et elle clôt la conversation quand le compte change : déconnexion, compte
/// supprimé, session invitée ou passage direct d'un compte à un autre
/// ([AssistantSessionEnded]). Le BLoC est un singleton de l'app : sans cela,
/// l'échange d'un compte passerait au suivant. Un verrou PIN ou un
/// rafraîchissement du même compte la gardent.
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

  /// Dernier compte connecté vu. Survit au verrou PIN et aux états de
  /// passage (chargement, erreur) : seul un autre compte ou une fermeture de
  /// session clôt la conversation.
  String? _uid;
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
    _uid = auth.state.currentUserId;
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
    final uid = state.currentUserId;
    final previousUid = _uid;
    final switched = uid != null && previousUid != null && uid != previousUid;
    final closed =
        uid == null && previousUid != null && assistantSessionClosedBy(state);
    if (uid != null) {
      _uid = uid;
    } else if (closed) {
      _uid = null;
    }
    // Avant toute sonde : la sonde du compte suivant part d'un état vierge.
    if (switched || closed) _assistant.add(const AssistantSessionEnded());

    final next = assistantSignedInAfter(state, previous: _signedIn.value);
    final entered = next && !_signedIn.value;
    _signedIn.value = next;
    // Nouvelle session, ou autre compte sans déconnexion visible entre les
    // deux : la disponibilité se redemande pour ce compte.
    if (entered || (switched && next)) {
      _assistant.add(const AssistantStatusRequested());
    }
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
        unawaited(router.push(assistantLocationFrom(router)));
      },
      onMoved: (side, y) => prefs.add(AssistantBubbleMoved(side, y)),
      onHintDismissed: () => _closeHint(prefs),
    );
  }
}
