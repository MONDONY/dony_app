import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Pose `Animate.defaultDuration` à froid depuis l'état déjà chargé du
/// bloc, avant que quoi que ce soit ne soit construit.
///
/// L'état initial d'[AccessibilityBloc] est fourni de façon synchrone par
/// son constructeur (`super(_load(_box))`), jamais par un `emit()`. Or
/// `BlocListener`/`BlocConsumer` s'abonnent à `bloc.stream`, qui ne rejoue
/// pas l'état déjà présent au moment de l'abonnement. Sans cet appel, un
/// utilisateur ayant activé « réduire les animations » lors d'une session
/// précédente rouvrirait l'application avec `Animate.defaultDuration`
/// bloqué à sa valeur par défaut (300 ms) pour toute la session, jusqu'à ce
/// qu'il change un autre réglage d'accessibilité par hasard.
///
/// Ne traite que le mode [AccessibilityMode.on] explicite : c'est le seul
/// cas où l'utilisateur a lui-même demandé la réduction, sans dépendre de
/// `MediaQuery`, indisponible à cet instant (avant le premier `build`). Le
/// mode `system` reste résolu comme avant par le `listener` du
/// `BlocConsumer` de `app.dart`, dès le premier changement d'état — le
/// traiter à froid nécessiterait un `MediaQuery` fiable, donc au plus tôt un
/// `addPostFrameCallback` après la première frame, ce qui laisserait de
/// toute façon échapper les widgets `flutter_animate` construits pendant
/// cette même première frame. Le gain n'a pas semblé justifier la
/// complexité et le risque supplémentaires pour cette correction ciblée.
///
/// Isolée dans son propre fichier (plutôt que définie dans `app.dart`, qui
/// importe `router.dart`) pour rester testable sans entraîner la
/// compilation de tout l'arbre de routes dans les tests.
void primeReducedMotionDuration(AccessibilityState state) {
  if (state.reduceMotion == AccessibilityMode.on) {
    Animate.defaultDuration = Duration.zero;
  }
}
