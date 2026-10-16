import 'dart:async';

import 'package:dony/app/main_shell.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
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
/// Elle ne montre rien pour un invité, quand l'utilisateur l'a masquée, quand
/// l'assistant est éteint (`AssistantState.disabled`), clavier ouvert, ni sur
/// les écrans listés dans [isAssistantBubbleExcludedLocation].
class AssistantBubbleOverlay extends StatelessWidget {
  const AssistantBubbleOverlay({super.key, this.router});

  /// Routeur à suivre ; `appRouter` par défaut (tests : un routeur local).
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final router = this.router ?? appRouter;
    final delegate = router.routerDelegate;
    return Positioned.fill(
      child: BlocProvider<AssistantBloc>.value(
        value: getIt<AssistantBloc>(),
        // La bulle est hors de tout écran : le chemin courant vient du
        // routeur. Lecture seule, jamais de `go`/`push` pendant la
        // notification (le `push` part d'un toucher).
        child: ListenableBuilder(
          listenable: delegate,
          builder: (context, _) {
            final path = visibleRoutePath(router);
            final signedIn = context.select<AuthBloc, bool>(
              (bloc) => bloc.state.currentUser != null,
            );
            final (enabled, side, y, hintSeen) = context
                .select<AppPreferencesBloc, (bool, String, double, bool)>((
                  bloc,
                ) {
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
            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
            if (!shouldShowAssistantBubble(
              path: path,
              signedIn: signedIn,
              enabled: enabled,
              disabled: disabled,
              keyboardOpen: keyboardOpen,
            )) {
              return const SizedBox.shrink();
            }
            final prefs = context.read<AppPreferencesBloc>();
            return AssistantBubble(
              side: side,
              yFraction: y,
              bottomInset: MainShell.navBarContentHeight,
              showHint: !hintSeen,
              onTap: () {
                if (!hintSeen) prefs.add(const AssistantHintDismissed());
                // `AssistantOpened('bubble')` part de l'écran lui-même, à
                // partir de `?source=` : l'envoyer ici doublerait l'événement
                // `assistant_opened`.
                unawaited(router.push('/assistant?source=bubble'));
              },
              onMoved: (side, y) => prefs.add(AssistantBubbleMoved(side, y)),
              onHintDismissed: () => prefs.add(const AssistantHintDismissed()),
            );
          },
        ),
      ),
    );
  }
}
