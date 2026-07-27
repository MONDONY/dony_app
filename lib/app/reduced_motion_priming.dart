import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Synchronise `Animate.defaultDuration` (statique global de
/// `flutter_animate`) sur l'état résolu de la réduction du mouvement, avant
/// que quoi que ce soit ne soit construit.
///
/// L'état initial d'[AccessibilityBloc] est fourni de façon synchrone par
/// son constructeur (`super(_load(_box))`), jamais par un `emit()`. Or
/// `BlocListener`/`BlocConsumer` s'abonnent à `bloc.stream`, qui ne rejoue
/// pas l'état déjà présent au moment de l'abonnement. Sans cet appel, un
/// utilisateur ayant activé la réduction des animations (dans yadony ou dans
/// les réglages de son téléphone) rouvrirait l'application avec
/// `Animate.defaultDuration` bloqué à sa valeur par défaut (300 ms) pour
/// toute la session, jusqu'à ce qu'il change un réglage d'accessibilité
/// yadony par hasard — ce qui n'arrive jamais pour l'utilisateur dont le seul
/// réglage actif est celui de son OS.
///
/// [systemReducesMotion] doit venir de `MediaQuery.disableAnimationsOf`,
/// lu au plus tôt depuis `didChangeDependencies` (avant le premier `build`,
/// contrairement à `initState`, où aucun `MediaQuery` fiable n'est encore
/// disponible). Résout les trois modes tri-états : [AccessibilityMode.on]
/// et [AccessibilityMode.off] priment explicitement sur le système ;
/// [AccessibilityMode.system] — la valeur par défaut, donc le cas le plus
/// fréquent, pas un cas limite — retombe sur [systemReducesMotion].
///
/// Idempotente et bon marché : peut être rappelée sans risque à chaque
/// nouvelle dépendance héritée (`didChangeDependencies` peut être invoquée
/// plusieurs fois, par exemple quand le clavier ouvre/ferme et fait varier
/// `MediaQuery`), elle ne fait que réaffecter la même variable statique au
/// résultat déterministe des entrées courantes.
///
/// Isolée dans son propre fichier (plutôt que définie dans `app.dart`, qui
/// importe `router.dart`) pour rester testable sans entraîner la
/// compilation de tout l'arbre de routes dans les tests.
void primeReducedMotionDuration(
  AccessibilityState state, {
  required bool systemReducesMotion,
}) {
  final reduce = switch (state.reduceMotion) {
    AccessibilityMode.on => true,
    AccessibilityMode.off => false,
    _ => systemReducesMotion,
  };
  Animate.defaultDuration =
      reduce ? Duration.zero : const Duration(milliseconds: 300);
}
