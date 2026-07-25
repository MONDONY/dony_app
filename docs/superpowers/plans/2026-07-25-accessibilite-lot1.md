# Accessibilité lot 1 — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre réellement effectifs les réglages d'accessibilité de dony_app, refondre l'écran, et ajouter six options, en visant WCAG 2.1 AA sur les fondations.

**Architecture:** `AccessibilityBloc` devient un singleton fourni à la racine dans `app.dart`. Son état pilote trois leviers : le choix de la variante de `ThemeData` (contraste, mouvement, soulignement des liens), un `MediaQuery` réinjecté (taille de texte, gras, animations) et un `AccessibilityScope` (InheritedWidget) pour les quatre flags que `MediaQuery` ne porte pas. L'écran de réglages est reconstruit autour d'un aperçu vivant.

**Tech Stack:** Flutter, flutter_bloc, Hive, flutter_animate, GoRouter, mocktail, bloc_test, app_settings (nouvelle dépendance).

**Spec de référence:** `docs/superpowers/specs/2026-07-25-accessibilite-lot1-design.md`

**Branche:** `feature/accessibilite-lot1` (déjà créée, la spec y est commitée).

## Global Constraints

- Jamais de `setState`, l'état passe par un BLoC. Jamais de `Navigator.push`, la navigation passe par GoRouter.
- Tout BLoC reçoit `AnalyticsService` en paramètre de constructeur et l'enregistre dans `lib/core/di/injection.dart`.
- Tout appel `_analytics.logEvent(...)` est enveloppé dans `unawaited(...)`.
- Aucune donnée personnelle dans les propriétés analytics.
- Tout nom d'event est déclaré dans `AnalyticsEvents` avant usage, puis ajouté au tableau de `dony_app/CLAUDE.md`.
- Aucun tiret cadratin dans un texte affiché à l'utilisateur. Une virgule à la place. Les commentaires de code sont exemptés.
- Couleurs sémantiques lues via `Theme.of(context).colorScheme`, jamais via `DonyColors.surface`, `DonyColors.textPrimary`, `DonyColors.bgApp` ou `DonyColors.borderDefault`, qui sont light-only.
- Espacements via `DonySpacing`, rayons via `DonyRadius`, typographie via `Theme.of(context).textTheme`.
- `fontSize` inférieur à 12 interdit.
- Cible tactile minimale 44 x 44.
- Tout `DonyButton` d'un bottom sheet va dans `stickyBottom`, jamais dans le `child` scrollable.
- Ne jamais committer sur `main`. Le travail se fait sur `feature/accessibilite-lot1`.
- Aucun `Co-Authored-By: Claude` dans les messages de commit.
- Ne jamais lancer deux commandes Flutter en parallèle, elles se marchent dessus et fabriquent de faux échecs.
- Couverture cible 90 %.
- Commande de test : `flutter test <chemin>`. Commande d'analyse : `flutter analyze`.

## File Structure

**Créés :**

| Fichier | Responsabilité |
|---|---|
| `lib/core/design/accessibility_scope.dart` | InheritedWidget portant les 4 flags non couverts par `MediaQuery`, plus l'extension `context.a11y` |
| `lib/core/design/theme/a11y_theme_options.dart` | Objet valeur passé à `AppTheme` : contraste, mouvement, soulignement |
| `lib/features/settings/presentation/widgets/a11y_preview_card.dart` | Carte d'aperçu vivant |
| `lib/features/settings/presentation/widgets/a11y_slider_row.dart` | Ligne curseur de taille de texte |
| `lib/features/settings/presentation/widgets/a11y_tristate_row.dart` | Ligne tri-état plus son bottom sheet |

**Réécrits :** les trois fichiers de `lib/features/settings/bloc/accessibility_*.dart` et `lib/features/settings/presentation/screens/accessibility_settings_screen.dart`.

**Modifiés :** `lib/app/app.dart`, `lib/app/router.dart`, `lib/core/di/injection.dart`, `lib/core/storage/hive_service.dart`, `lib/core/design/theme/app_theme.dart`, `lib/core/design/tokens/color_tokens.dart`, `lib/core/design/design_system.dart`, `lib/core/design/widgets/dony_snackbar.dart`, `lib/core/design/widgets/dony_badge.dart`, `lib/core/design/widgets/dony_urgent_badge.dart`, `lib/core/design/widgets/dony_status_banner.dart`, `lib/core/services/analytics_events.dart`, `lib/features/settings/data/models/user_preferences_model.dart`, `pubspec.yaml`, `dony_app/CLAUDE.md`.

---

### Task 1 : État, clés Hive et migration

**Files:**
- Modify: `lib/core/storage/hive_service.dart` (bloc « Accessibilité », lignes 37-40)
- Rewrite: `lib/features/settings/bloc/accessibility_state.dart`
- Rewrite: `lib/features/settings/bloc/accessibility_event.dart`
- Rewrite: `lib/features/settings/bloc/accessibility_bloc.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Test: `test/features/settings/bloc/accessibility_bloc_test.dart` (réécrit)

**Interfaces:**
- Consumes: `HiveService.userPrefs` (un `Box<dynamic>`), `AnalyticsService.logEvent`.
- Produces:
  - `AccessibilityState` avec les champs `followSystemTextScale` (bool), `textScaleFactor` (double), `highContrast` (String), `reduceMotion` (String), `boldText` (bool), `underlineLinks` (bool), `reinforceLabels` (bool), `persistentMessages` (bool), `confirmImportantActions` (bool), plus `copyWith` sur tous.
  - Events : `FollowSystemTextScaleToggled(bool value)`, `TextScaleFactorChanged(double value)`, `HighContrastModeChanged(String value)`, `ReduceMotionModeChanged(String value)`, `BoldTextToggled(bool value)`, `UnderlineLinksToggled(bool value)`, `ReinforceLabelsToggled(bool value)`, `PersistentMessagesToggled(bool value)`, `ConfirmImportantActionsToggled(bool value)`, `AccessibilityResetRequested()`.
  - Constructeur `AccessibilityBloc(Box box, AnalyticsService analytics)`.
  - Constantes de mode : `AccessibilityMode.system = 'system'`, `.on = 'on'`, `.off = 'off'`.
  - `AnalyticsEvents.accessibilitySettingChanged = 'accessibility_setting_changed'`.

- [ ] **Step 1 : Écrire les tests qui échouent**

Remplacer entièrement `test/features/settings/bloc/accessibility_bloc_test.dart` par :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockBox box;
  late MockAnalyticsService analytics;

  setUp(() {
    box = MockBox();
    analytics = MockAnalyticsService();
    when(() => box.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => box.get(any())).thenReturn(null);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => box.delete(any())).thenAnswer((_) async {});
    when(() => analytics.logEvent(any(),
        properties: any(named: 'properties'))).thenAnswer((_) async {});
  });

  AccessibilityBloc build() => AccessibilityBloc(box, analytics);

  group('AccessibilityBloc — valeurs par défaut', () {
    test('un box vierge donne les valeurs par défaut', () {
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isTrue);
      expect(bloc.state.textScaleFactor, 1.0);
      expect(bloc.state.highContrast, AccessibilityMode.system);
      expect(bloc.state.reduceMotion, AccessibilityMode.system);
      expect(bloc.state.boldText, isFalse);
      expect(bloc.state.underlineLinks, isFalse);
      expect(bloc.state.reinforceLabels, isFalse);
      expect(bloc.state.persistentMessages, isFalse);
      expect(bloc.state.confirmImportantActions, isFalse);
      bloc.close();
    });
  });

  group('AccessibilityBloc — migration depuis l\'ancien format', () {
    void legacy({String? textScale, bool? highContrast, bool? reduce}) {
      when(() => box.get(HiveService.kTextScale)).thenReturn(textScale);
      when(() => box.get(HiveService.kHighContrast)).thenReturn(highContrast);
      when(() => box.get(HiveService.kReduceAnimations)).thenReturn(reduce);
    }

    test('small devient 0.85 sans suivi système', () {
      legacy(textScale: 'small');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 0.85);
      bloc.close();
    });

    test('normal devient suivi système à 1.0', () {
      legacy(textScale: 'normal');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isTrue);
      expect(bloc.state.textScaleFactor, 1.0);
      bloc.close();
    });

    test('large devient 1.3 sans suivi système', () {
      legacy(textScale: 'large');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 1.3);
      bloc.close();
    });

    test('xlarge devient 1.6 sans suivi système', () {
      legacy(textScale: 'xlarge');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 1.6);
      bloc.close();
    });

    test('high_contrast true devient on, false devient system', () {
      legacy(highContrast: true);
      final a = build();
      expect(a.state.highContrast, AccessibilityMode.on);
      a.close();

      legacy(highContrast: false);
      final b = build();
      expect(b.state.highContrast, AccessibilityMode.system);
      b.close();
    });

    test('reduce_animations true devient on, false devient system', () {
      legacy(reduce: true);
      final a = build();
      expect(a.state.reduceMotion, AccessibilityMode.on);
      a.close();

      legacy(reduce: false);
      final b = build();
      expect(b.state.reduceMotion, AccessibilityMode.system);
      b.close();
    });

    test('les anciennes clés sont supprimées après migration', () {
      legacy(textScale: 'large', highContrast: true, reduce: true);
      final bloc = build();
      verify(() => box.delete(HiveService.kTextScale)).called(1);
      verify(() => box.delete(HiveService.kHighContrast)).called(1);
      verify(() => box.delete(HiveService.kReduceAnimations)).called(1);
      bloc.close();
    });

    test('les nouvelles clés sont écrites après migration', () {
      legacy(textScale: 'large');
      final bloc = build();
      verify(() => box.put(HiveService.kA11yFollowSystemTextScale, false))
          .called(1);
      verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.3)).called(1);
      bloc.close();
    });

    test('aucune migration si aucune ancienne clé', () {
      final bloc = build();
      verifyNever(() => box.delete(HiveService.kTextScale));
      bloc.close();
    });
  });

  group('AccessibilityBloc — réglages', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleFactorChanged persiste et émet',
      build: build,
      act: (b) => b.add(const TextScaleFactorChanged(1.45)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.textScaleFactor, 'textScaleFactor', 1.45),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.45)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleFactorChanged borne la valeur entre 0.85 et 2.0',
      build: build,
      act: (b) => b
        ..add(const TextScaleFactorChanged(5.0))
        ..add(const TextScaleFactorChanged(0.1)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.textScaleFactor, 'max borné', 2.0),
        isA<AccessibilityState>()
            .having((s) => s.textScaleFactor, 'min borné', 0.85),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'FollowSystemTextScaleToggled persiste et émet',
      build: build,
      act: (b) => b.add(const FollowSystemTextScaleToggled(false)),
      expect: () => [
        isA<AccessibilityState>().having(
            (s) => s.followSystemTextScale, 'followSystemTextScale', isFalse),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yFollowSystemTextScale, false))
            .called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'HighContrastModeChanged accepte on',
      build: build,
      act: (b) => b.add(const HighContrastModeChanged(AccessibilityMode.on)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.highContrast, 'highContrast', AccessibilityMode.on),
      ],
      verify: (_) {
        verify(() =>
                box.put(HiveService.kA11yHighContrast, AccessibilityMode.on))
            .called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ReduceMotionModeChanged accepte off',
      build: build,
      act: (b) => b.add(const ReduceMotionModeChanged(AccessibilityMode.off)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.reduceMotion, 'reduceMotion', AccessibilityMode.off),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'BoldTextToggled persiste et émet',
      build: build,
      act: (b) => b.add(const BoldTextToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having((s) => s.boldText, 'boldText', isTrue),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yBoldText, true)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'UnderlineLinksToggled persiste et émet',
      build: build,
      act: (b) => b.add(const UnderlineLinksToggled(true)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.underlineLinks, 'underlineLinks', isTrue),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yUnderlineLinks, true)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ReinforceLabelsToggled persiste et émet',
      build: build,
      act: (b) => b.add(const ReinforceLabelsToggled(true)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.reinforceLabels, 'reinforceLabels', isTrue),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'PersistentMessagesToggled persiste et émet',
      build: build,
      act: (b) => b.add(const PersistentMessagesToggled(true)),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.persistentMessages, 'persistentMessages', isTrue),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ConfirmImportantActionsToggled persiste et émet',
      build: build,
      act: (b) => b.add(const ConfirmImportantActionsToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having((s) => s.confirmImportantActions,
            'confirmImportantActions', isTrue),
      ],
    );
  });

  group('AccessibilityBloc — réinitialisation', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'AccessibilityResetRequested remet toutes les valeurs par défaut',
      build: build,
      seed: () => const AccessibilityState(
        followSystemTextScale: false,
        textScaleFactor: 1.8,
        highContrast: AccessibilityMode.on,
        reduceMotion: AccessibilityMode.on,
        boldText: true,
        underlineLinks: true,
        reinforceLabels: true,
        persistentMessages: true,
        confirmImportantActions: true,
      ),
      act: (b) => b.add(const AccessibilityResetRequested()),
      expect: () => [const AccessibilityState()],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.0)).called(1);
        verify(() => box.put(HiveService.kA11yBoldText, false)).called(1);
      },
    );
  });

  group('AccessibilityBloc — analytics', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'chaque changement émet accessibility_setting_changed sans PII',
      build: build,
      act: (b) => b.add(const BoldTextToggled(true)),
      verify: (_) {
        verify(() => analytics.logEvent(
              'accessibility_setting_changed',
              properties: {'setting': 'bold_text', 'value': 'true'},
            )).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'la réinitialisation émet un event dédié',
      build: build,
      act: (b) => b.add(const AccessibilityResetRequested()),
      verify: (_) {
        verify(() => analytics.logEvent(
              'accessibility_setting_changed',
              properties: {'setting': 'reset', 'value': 'all'},
            )).called(1);
      },
    );
  });
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/settings/bloc/accessibility_bloc_test.dart`
Expected: FAIL à la compilation, `AccessibilityMode` et les nouveaux events n'existent pas.

- [ ] **Step 3 : Ajouter les clés Hive**

Dans `lib/core/storage/hive_service.dart`, remplacer le bloc « Accessibilité » existant par :

```dart
  // ── Accessibilité ────────────────────────────────────────────────────────
  // Clés héritées, lues une seule fois pour la migration puis supprimées.
  static const String kTextScale         = 'text_scale';       // 'small'|'normal'|'large'|'xlarge'
  static const String kHighContrast      = 'high_contrast';    // bool
  static const String kReduceAnimations  = 'reduce_animations';// bool

  static const String kA11yFollowSystemTextScale = 'a11y_follow_system_text_scale'; // bool
  static const String kA11yTextScaleFactor       = 'a11y_text_scale_factor';        // double
  static const String kA11yHighContrast          = 'a11y_high_contrast';            // 'system'|'on'|'off'
  static const String kA11yReduceMotion          = 'a11y_reduce_motion';            // 'system'|'on'|'off'
  static const String kA11yBoldText              = 'a11y_bold_text';                // bool
  static const String kA11yUnderlineLinks        = 'a11y_underline_links';          // bool
  static const String kA11yReinforceLabels       = 'a11y_reinforce_labels';         // bool
  static const String kA11yPersistentMessages    = 'a11y_persistent_messages';      // bool
  static const String kA11yConfirmImportant      = 'a11y_confirm_important';        // bool
```

- [ ] **Step 4 : Écrire l'état**

Remplacer entièrement `lib/features/settings/bloc/accessibility_state.dart` :

```dart
part of 'accessibility_bloc.dart';

/// Valeurs possibles des réglages tri-états.
///
/// Stockées en `String` et non en `bool?` : Hive ne distingue pas une clé
/// absente d'une clé à `null`, ce qui rendrait « jamais choisi » et
/// « explicitement désactivé » indiscernables.
abstract final class AccessibilityMode {
  static const String system = 'system';
  static const String on = 'on';
  static const String off = 'off';

  static const List<String> values = [system, on, off];

  /// Vrai si [mode] est une valeur connue. Toute autre valeur, lue depuis un
  /// box corrompu, doit retomber sur [system].
  static bool isValid(String? mode) => mode != null && values.contains(mode);
}

/// Bornes du facteur de taille de texte.
///
/// Le plafond à 2.0 vient de WCAG 1.4.4 : les contenus doivent rester
/// utilisables jusqu'à 200 %. Au-delà, les écrans ne sont pas tenables.
const double kA11yMinTextScale = 0.85;
const double kA11yMaxTextScale = 2.0;

class AccessibilityState extends Equatable {
  const AccessibilityState({
    this.followSystemTextScale = true,
    this.textScaleFactor = 1.0,
    this.highContrast = AccessibilityMode.system,
    this.reduceMotion = AccessibilityMode.system,
    this.boldText = false,
    this.underlineLinks = false,
    this.reinforceLabels = false,
    this.persistentMessages = false,
    this.confirmImportantActions = false,
  });

  /// Quand vrai, la taille suit le réglage du système et [textScaleFactor] est
  /// ignoré.
  final bool followSystemTextScale;

  /// Facteur appliqué quand [followSystemTextScale] est faux. Borné entre
  /// [kA11yMinTextScale] et [kA11yMaxTextScale].
  final double textScaleFactor;

  final String highContrast;
  final String reduceMotion;
  final bool boldText;
  final bool underlineLinks;
  final bool reinforceLabels;
  final bool persistentMessages;
  final bool confirmImportantActions;

  AccessibilityState copyWith({
    bool? followSystemTextScale,
    double? textScaleFactor,
    String? highContrast,
    String? reduceMotion,
    bool? boldText,
    bool? underlineLinks,
    bool? reinforceLabels,
    bool? persistentMessages,
    bool? confirmImportantActions,
  }) =>
      AccessibilityState(
        followSystemTextScale:
            followSystemTextScale ?? this.followSystemTextScale,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        boldText: boldText ?? this.boldText,
        underlineLinks: underlineLinks ?? this.underlineLinks,
        reinforceLabels: reinforceLabels ?? this.reinforceLabels,
        persistentMessages: persistentMessages ?? this.persistentMessages,
        confirmImportantActions:
            confirmImportantActions ?? this.confirmImportantActions,
      );

  @override
  List<Object?> get props => [
        followSystemTextScale,
        textScaleFactor,
        highContrast,
        reduceMotion,
        boldText,
        underlineLinks,
        reinforceLabels,
        persistentMessages,
        confirmImportantActions,
      ];
}
```

- [ ] **Step 5 : Écrire les events**

Remplacer entièrement `lib/features/settings/bloc/accessibility_event.dart` :

```dart
part of 'accessibility_bloc.dart';

abstract class AccessibilityEvent extends Equatable {
  const AccessibilityEvent();
  @override
  List<Object?> get props => [];
}

class FollowSystemTextScaleToggled extends AccessibilityEvent {
  const FollowSystemTextScaleToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class TextScaleFactorChanged extends AccessibilityEvent {
  const TextScaleFactorChanged(this.value);
  final double value;
  @override
  List<Object?> get props => [value];
}

class HighContrastModeChanged extends AccessibilityEvent {
  const HighContrastModeChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class ReduceMotionModeChanged extends AccessibilityEvent {
  const ReduceMotionModeChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class BoldTextToggled extends AccessibilityEvent {
  const BoldTextToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class UnderlineLinksToggled extends AccessibilityEvent {
  const UnderlineLinksToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class ReinforceLabelsToggled extends AccessibilityEvent {
  const ReinforceLabelsToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class PersistentMessagesToggled extends AccessibilityEvent {
  const PersistentMessagesToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class ConfirmImportantActionsToggled extends AccessibilityEvent {
  const ConfirmImportantActionsToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class AccessibilityResetRequested extends AccessibilityEvent {
  const AccessibilityResetRequested();
}
```

- [ ] **Step 6 : Écrire le bloc avec sa migration**

Remplacer entièrement `lib/features/settings/bloc/accessibility_bloc.dart` :

```dart
import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'accessibility_event.dart';
part 'accessibility_state.dart';

class AccessibilityBloc extends Bloc<AccessibilityEvent, AccessibilityState> {
  AccessibilityBloc(this._box, this._analytics)
      : super(_load(_box)) {
    on<FollowSystemTextScaleToggled>((e, emit) => _apply(
          emit,
          state.copyWith(followSystemTextScale: e.value),
          HiveService.kA11yFollowSystemTextScale,
          e.value,
          'follow_system_text_scale',
        ));

    on<TextScaleFactorChanged>((e, emit) {
      final clamped = e.value.clamp(kA11yMinTextScale, kA11yMaxTextScale);
      _apply(
        emit,
        state.copyWith(textScaleFactor: clamped),
        HiveService.kA11yTextScaleFactor,
        clamped,
        'text_scale_factor',
      );
    });

    on<HighContrastModeChanged>((e, emit) => _apply(
          emit,
          state.copyWith(highContrast: e.value),
          HiveService.kA11yHighContrast,
          e.value,
          'high_contrast',
        ));

    on<ReduceMotionModeChanged>((e, emit) => _apply(
          emit,
          state.copyWith(reduceMotion: e.value),
          HiveService.kA11yReduceMotion,
          e.value,
          'reduce_motion',
        ));

    on<BoldTextToggled>((e, emit) => _apply(
          emit,
          state.copyWith(boldText: e.value),
          HiveService.kA11yBoldText,
          e.value,
          'bold_text',
        ));

    on<UnderlineLinksToggled>((e, emit) => _apply(
          emit,
          state.copyWith(underlineLinks: e.value),
          HiveService.kA11yUnderlineLinks,
          e.value,
          'underline_links',
        ));

    on<ReinforceLabelsToggled>((e, emit) => _apply(
          emit,
          state.copyWith(reinforceLabels: e.value),
          HiveService.kA11yReinforceLabels,
          e.value,
          'reinforce_labels',
        ));

    on<PersistentMessagesToggled>((e, emit) => _apply(
          emit,
          state.copyWith(persistentMessages: e.value),
          HiveService.kA11yPersistentMessages,
          e.value,
          'persistent_messages',
        ));

    on<ConfirmImportantActionsToggled>((e, emit) => _apply(
          emit,
          state.copyWith(confirmImportantActions: e.value),
          HiveService.kA11yConfirmImportant,
          e.value,
          'confirm_important_actions',
        ));

    on<AccessibilityResetRequested>((e, emit) {
      const fresh = AccessibilityState();
      _persistAll(_box, fresh);
      unawaited(_analytics.logEvent(
        AnalyticsEvents.accessibilitySettingChanged,
        properties: const {'setting': 'reset', 'value': 'all'},
      ));
      emit(fresh);
    });
  }

  final Box _box;
  final AnalyticsService _analytics;

  void _apply(
    Emitter<AccessibilityState> emit,
    AccessibilityState next,
    String hiveKey,
    Object value,
    String settingName,
  ) {
    _box.put(hiveKey, value);
    unawaited(_analytics.logEvent(
      AnalyticsEvents.accessibilitySettingChanged,
      properties: {'setting': settingName, 'value': '$value'},
    ));
    emit(next);
  }

  /// Lit l'état depuis Hive, en migrant d'abord l'ancien format si présent.
  static AccessibilityState _load(Box box) {
    _migrateLegacy(box);
    final mode = (String key) {
      final raw = box.get(key, defaultValue: AccessibilityMode.system);
      return AccessibilityMode.isValid(raw as String?)
          ? raw as String
          : AccessibilityMode.system;
    };
    return AccessibilityState(
      followSystemTextScale: box.get(HiveService.kA11yFollowSystemTextScale,
          defaultValue: true) as bool,
      textScaleFactor:
          (box.get(HiveService.kA11yTextScaleFactor, defaultValue: 1.0) as num)
              .toDouble()
              .clamp(kA11yMinTextScale, kA11yMaxTextScale),
      highContrast: mode(HiveService.kA11yHighContrast),
      reduceMotion: mode(HiveService.kA11yReduceMotion),
      boldText: box.get(HiveService.kA11yBoldText, defaultValue: false) as bool,
      underlineLinks:
          box.get(HiveService.kA11yUnderlineLinks, defaultValue: false) as bool,
      reinforceLabels: box.get(HiveService.kA11yReinforceLabels,
          defaultValue: false) as bool,
      persistentMessages: box.get(HiveService.kA11yPersistentMessages,
          defaultValue: false) as bool,
      confirmImportantActions:
          box.get(HiveService.kA11yConfirmImportant, defaultValue: false)
              as bool,
    );
  }

  /// Convertit les trois clés de l'ancien écran vers le nouveau format, puis
  /// les supprime. Sans effet si aucune n'est présente.
  ///
  /// `'normal'` et `false` étaient les valeurs par défaut : ils traduisent une
  /// absence de choix, donc ils deviennent « suivre le système » et non un
  /// réglage forcé.
  static void _migrateLegacy(Box box) {
    final legacyScale = box.get(HiveService.kTextScale) as String?;
    final legacyContrast = box.get(HiveService.kHighContrast) as bool?;
    final legacyReduce = box.get(HiveService.kReduceAnimations) as bool?;

    if (legacyScale == null && legacyContrast == null && legacyReduce == null) {
      return;
    }

    if (legacyScale != null) {
      final (follow, factor) = switch (legacyScale) {
        'small' => (false, 0.85),
        'large' => (false, 1.3),
        'xlarge' => (false, 1.6),
        _ => (true, 1.0),
      };
      box.put(HiveService.kA11yFollowSystemTextScale, follow);
      box.put(HiveService.kA11yTextScaleFactor, factor);
      box.delete(HiveService.kTextScale);
    }

    if (legacyContrast != null) {
      box.put(HiveService.kA11yHighContrast,
          legacyContrast ? AccessibilityMode.on : AccessibilityMode.system);
      box.delete(HiveService.kHighContrast);
    }

    if (legacyReduce != null) {
      box.put(HiveService.kA11yReduceMotion,
          legacyReduce ? AccessibilityMode.on : AccessibilityMode.system);
      box.delete(HiveService.kReduceAnimations);
    }
  }

  static void _persistAll(Box box, AccessibilityState s) {
    box.put(HiveService.kA11yFollowSystemTextScale, s.followSystemTextScale);
    box.put(HiveService.kA11yTextScaleFactor, s.textScaleFactor);
    box.put(HiveService.kA11yHighContrast, s.highContrast);
    box.put(HiveService.kA11yReduceMotion, s.reduceMotion);
    box.put(HiveService.kA11yBoldText, s.boldText);
    box.put(HiveService.kA11yUnderlineLinks, s.underlineLinks);
    box.put(HiveService.kA11yReinforceLabels, s.reinforceLabels);
    box.put(HiveService.kA11yPersistentMessages, s.persistentMessages);
    box.put(HiveService.kA11yConfirmImportant, s.confirmImportantActions);
  }
}
```

- [ ] **Step 7 : Déclarer l'event analytics**

Dans `lib/core/services/analytics_events.dart`, ajouter avant l'accolade fermante :

```dart
  // Accessibilité
  static const accessibilitySettingChanged = 'accessibility_setting_changed';
```

- [ ] **Step 8 : Lancer les tests**

Run: `flutter test test/features/settings/bloc/accessibility_bloc_test.dart`
Expected: PASS, tous les groupes.

- [ ] **Step 9 : Vérifier que rien d'autre ne casse à la compilation**

Run: `flutter analyze lib/features/settings lib/core/storage lib/core/services`
Expected: des erreurs sur `accessibility_settings_screen.dart` et `injection.dart`, qui utilisent encore l'ancienne API. C'est attendu, elles sont traitées aux tâches 4 et 5. Aucune autre erreur ne doit apparaître.

- [ ] **Step 10 : Commit**

```bash
git add lib/core/storage/hive_service.dart lib/core/services/analytics_events.dart lib/features/settings/bloc/ test/features/settings/bloc/accessibility_bloc_test.dart
git commit -m "feat(a11y): nouvel etat accessibilite a 9 reglages avec migration

Remplace les 3 champs de l'ancien bloc par 9 reglages, dont 3 tri-etats
stockes en String. Migre les cles text_scale, high_contrast et
reduce_animations vers le nouveau format puis les supprime. Les valeurs
par defaut de l'ancien format sont traduites en 'suivre le systeme',
puisqu'elles traduisent une absence de choix."
```

---

### Task 2 : AccessibilityScope

**Files:**
- Create: `lib/core/design/accessibility_scope.dart`
- Modify: `lib/core/design/design_system.dart` (ajout de l'export)
- Test: `test/core/design/accessibility_scope_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `AccessibilityScope` (InheritedWidget) avec `underlineLinks`, `reinforceLabels`, `persistentMessages`, `confirmImportantActions`, tous `bool`.
  - `AccessibilityScope.of(BuildContext)` renvoyant une instance par défaut si aucun scope n'est monté.
  - Extension `AccessibilityContext on BuildContext` exposant `context.a11y`.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/core/design/accessibility_scope_test.dart` :

```dart
import 'package:dony/core/design/accessibility_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context.a11y lit les valeurs du scope', (tester) async {
    late AccessibilityScope read;
    await tester.pumpWidget(
      const AccessibilityScope(
        underlineLinks: true,
        reinforceLabels: true,
        persistentMessages: false,
        confirmImportantActions: true,
        child: SizedBox.shrink(),
      ),
    );
    final ctx = tester.element(find.byType(SizedBox));
    read = ctx.a11y;
    expect(read.underlineLinks, isTrue);
    expect(read.reinforceLabels, isTrue);
    expect(read.persistentMessages, isFalse);
    expect(read.confirmImportantActions, isTrue);
  });

  testWidgets('sans scope monté, les valeurs par défaut sont sûres',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final ctx = tester.element(find.byType(SizedBox));
    expect(ctx.a11y.underlineLinks, isFalse);
    expect(ctx.a11y.reinforceLabels, isFalse);
    expect(ctx.a11y.persistentMessages, isFalse);
    expect(ctx.a11y.confirmImportantActions, isFalse);
  });

  testWidgets('un changement de valeur reconstruit les dépendants',
      (tester) async {
    var builds = 0;
    Widget wrap(bool underline) => AccessibilityScope(
          underlineLinks: underline,
          reinforceLabels: false,
          persistentMessages: false,
          confirmImportantActions: false,
          child: Builder(builder: (ctx) {
            builds++;
            return Text('${ctx.a11y.underlineLinks}',
                textDirection: TextDirection.ltr);
          }),
        );

    await tester.pumpWidget(wrap(false));
    expect(builds, 1);
    await tester.pumpWidget(wrap(true));
    expect(builds, 2);
    expect(find.text('true'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/design/accessibility_scope_test.dart`
Expected: FAIL, `accessibility_scope.dart` n'existe pas.

- [ ] **Step 3 : Écrire le widget**

Créer `lib/core/design/accessibility_scope.dart` :

```dart
import 'package:flutter/widgets.dart';

/// Porte les réglages d'accessibilité que [MediaQuery] ne couvre pas.
///
/// La taille de texte, le gras et la désactivation des animations passent par
/// `MediaQuery`, donc aucun widget n'a à les lire. Les quatre réglages ci-
/// dessous n'ont pas d'équivalent natif et sont diffusés ici.
///
/// Motif du choix d'un InheritedWidget plutôt qu'un `BlocProvider` : imposer
/// `AccessibilityBloc` à chaque widget du design system couplerait le design
/// system à une feature. Un scope monté une fois à la racine évite ce
/// couplage, et [of] retombe sur des valeurs par défaut sûres quand aucun
/// scope n'est présent, ce qui garde les widgets testables isolément.
class AccessibilityScope extends InheritedWidget {
  const AccessibilityScope({
    super.key,
    required this.underlineLinks,
    required this.reinforceLabels,
    required this.persistentMessages,
    required this.confirmImportantActions,
    required super.child,
  });

  /// Souligne les liens textuels, pour ne pas signaler un lien par la seule
  /// couleur (WCAG 1.4.1).
  final bool underlineLinks;

  /// Ajoute une icône et un mot aux statuts distingués par la couleur seule.
  final bool reinforceLabels;

  /// Les messages temporaires restent affichés jusqu'à fermeture manuelle
  /// (WCAG 2.2.1).
  final bool persistentMessages;

  /// Demande une confirmation explicite avant paiement, annulation et
  /// suppression de compte (WCAG 3.3.4).
  final bool confirmImportantActions;

  static const AccessibilityScope _defaults = AccessibilityScope(
    underlineLinks: false,
    reinforceLabels: false,
    persistentMessages: false,
    confirmImportantActions: false,
    child: SizedBox.shrink(),
  );

  static AccessibilityScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccessibilityScope>() ??
      _defaults;

  @override
  bool updateShouldNotify(AccessibilityScope old) =>
      underlineLinks != old.underlineLinks ||
      reinforceLabels != old.reinforceLabels ||
      persistentMessages != old.persistentMessages ||
      confirmImportantActions != old.confirmImportantActions;
}

extension AccessibilityContext on BuildContext {
  /// Réglages d'accessibilité non couverts par [MediaQuery].
  AccessibilityScope get a11y => AccessibilityScope.of(this);
}
```

- [ ] **Step 4 : Exporter depuis le design system**

Dans `lib/core/design/design_system.dart`, ajouter la ligne d'export avec les autres :

```dart
export 'accessibility_scope.dart';
```

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/core/design/accessibility_scope_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6 : Commit**

```bash
git add lib/core/design/accessibility_scope.dart lib/core/design/design_system.dart test/core/design/accessibility_scope_test.dart
git commit -m "feat(a11y): AccessibilityScope pour les reglages hors MediaQuery

Quatre reglages n'ont pas d'equivalent natif dans MediaQuery. Un
InheritedWidget les diffuse sans coupler le design system a la feature
settings, avec des valeurs par defaut sures quand aucun scope n'est
monte."
```

---

### Task 3 : Variantes de thème et tokens haut contraste

**Files:**
- Create: `lib/core/design/theme/a11y_theme_options.dart`
- Modify: `lib/core/design/tokens/color_tokens.dart` (ajout des tokens `Hc`)
- Modify: `lib/core/design/theme/app_theme.dart`
- Modify: `lib/core/design/design_system.dart` (export de `a11y_theme_options.dart`)
- Test: `test/core/design/theme/app_theme_a11y_test.dart`

**Interfaces:**
- Consumes: `DonyColors` existants.
- Produces:
  - `A11yThemeOptions({bool highContrast, bool reduceMotion, bool underlineLinks})`, avec un constructeur `const A11yThemeOptions()` à valeurs fausses.
  - `AppTheme.light({A11yThemeOptions a11y})` et `AppTheme.dark({A11yThemeOptions a11y})`, tous deux avec `a11y` optionnel valant `const A11yThemeOptions()`.
  - Tokens `DonyColors.textPrimaryHc`, `.textMutedHc`, `.borderDefaultHc`, `.primaryHc`, `.surfaceHc`, `.bgAppHc` et leurs équivalents `Dark`.

**Note de conception :** la spec annonçait `_build(Brightness, {required bool highContrast, required bool reduceMotion})`. `underlineLinks` s'applique via `textButtonTheme`, donc il relève aussi du thème. Trois booléens nommés se dégradent vite, d'où l'objet valeur `A11yThemeOptions`. C'est un raffinement de la spec, pas un changement de comportement.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/core/design/theme/app_theme_a11y_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ratio de contraste WCAG entre deux couleurs opaques.
double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.r * 255) +
        0.7152 * channel(c.g * 255) +
        0.0722 * channel(c.b * 255);
  }

  final la = lum(a), lb = lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppTheme — variantes d\'accessibilité', () {
    test('sans options, le thème clair est inchangé sur les couleurs clés', () {
      final normal = AppTheme.light();
      expect(normal.colorScheme.primary, DonyColors.primary);
      expect(normal.colorScheme.onSurface, DonyColors.textPrimary);
    });

    test('le contraste élevé change le texte et les bordures en clair', () {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final normal = AppTheme.light();
      expect(hc.colorScheme.onSurface, isNot(normal.colorScheme.onSurface));
      expect(hc.colorScheme.outline, isNot(normal.colorScheme.outline));
    });

    test('le texte principal contrasté atteint 7:1 sur la surface', () {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
          hc.colorScheme.onSurface, hc.colorScheme.surface);
      expect(ratio, greaterThanOrEqualTo(7.0));
    });

    test('le texte secondaire contrasté dépasse 4.5:1 sur la surface', () {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
          hc.colorScheme.onSurfaceVariant, hc.colorScheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('le contraste élevé fonctionne aussi en sombre', () {
      final hc = AppTheme.dark(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
          hc.colorScheme.onSurface, hc.colorScheme.surface);
      expect(ratio, greaterThanOrEqualTo(7.0));
    });

    test('le soulignement des liens s\'applique au textButtonTheme', () {
      final off = AppTheme.light();
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(underlineLinks: true),
      );
      TextDecoration? deco(ThemeData t) => t.textButtonTheme.style?.textStyle
          ?.resolve({})?.decoration;
      expect(deco(off), anyOf(isNull, TextDecoration.none));
      expect(deco(on), TextDecoration.underline);
    });

    test('la réduction du mouvement supprime les transitions de page', () {
      final off = AppTheme.light();
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(reduceMotion: true),
      );
      expect(on.pageTransitionsTheme.builders[TargetPlatform.android],
          isNot(off.pageTransitionsTheme.builders[TargetPlatform.android]));
      expect(on.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<PageTransitionsBuilder>());
    });

    test('les bordures contrastées sont plus épaisses sur les champs', () {
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final border = on.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(border.borderSide.width, greaterThanOrEqualTo(1.5));
    });
  });
}
```

Ajouter en tête du fichier de test l'import de `dart:math` sous l'alias attendu :

```dart
import 'dart:math' as math;
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/design/theme/app_theme_a11y_test.dart`
Expected: FAIL, `A11yThemeOptions` n'existe pas et `AppTheme.light` ne prend pas de paramètre.

- [ ] **Step 3 : Créer l'objet d'options**

Créer `lib/core/design/theme/a11y_theme_options.dart` :

```dart
/// Réglages d'accessibilité qui influent sur la construction du [ThemeData].
///
/// Les trois réglages ci-dessous ne peuvent pas passer par `MediaQuery` :
/// ils changent des couleurs, des bordures, des styles de bouton et les
/// transitions de page, donc ils appartiennent au thème.
class A11yThemeOptions {
  const A11yThemeOptions({
    this.highContrast = false,
    this.reduceMotion = false,
    this.underlineLinks = false,
  });

  final bool highContrast;
  final bool reduceMotion;
  final bool underlineLinks;

  @override
  bool operator ==(Object other) =>
      other is A11yThemeOptions &&
      other.highContrast == highContrast &&
      other.reduceMotion == reduceMotion &&
      other.underlineLinks == underlineLinks;

  @override
  int get hashCode => Object.hash(highContrast, reduceMotion, underlineLinks);
}
```

- [ ] **Step 4 : Ajouter les tokens haut contraste**

Dans `lib/core/design/tokens/color_tokens.dart`, ajouter un bloc après les rôles sémantiques existants. Les valeurs sont choisies pour dépasser 7:1 sur leur fond respectif :

```dart
  // ── Variante haut contraste ──────────────────────────────────────────────
  // Ajoutée, jamais substituée aux tokens ci-dessus : le rendu normal ne
  // change pas. Cible 7:1 sur le texte principal, 4.5:1 minimum sur le
  // secondaire, bordures nettement visibles.
  static const surfaceHc       = neutral0;          // blanc pur
  static const bgAppHc         = neutral0;          // pas de fond casse, contraste max
  static const textPrimaryHc   = Color(0xFF000000); // noir pur sur blanc, 21:1
  static const textMutedHc     = Color(0xFF3A3630); // 9.3:1 sur blanc
  static const borderDefaultHc = Color(0xFF5C5850); // bordure nettement visible
  static const primaryHc       = Color(0xFF00368F); // bleu assombri, 9.1:1 sur blanc

  static const surfaceHcDark       = Color(0xFF000000);
  static const bgAppHcDark         = Color(0xFF000000);
  static const textPrimaryHcDark   = neutral0;      // blanc pur sur noir, 21:1
  static const textMutedHcDark     = Color(0xFFD6D2CA);
  static const borderDefaultHcDark = Color(0xFF9A958C);
  static const primaryHcDark       = Color(0xFF8FB6FF);
```

- [ ] **Step 5 : Câbler les options dans AppTheme**

Dans `lib/core/design/theme/app_theme.dart`, remplacer l'en-tête de la classe (lignes 7 à 40 actuelles) par :

```dart
abstract final class AppTheme {
  static ThemeData light({A11yThemeOptions a11y = const A11yThemeOptions()}) =>
      _build(Brightness.light, a11y);

  static ThemeData dark({A11yThemeOptions a11y = const A11yThemeOptions()}) =>
      _build(Brightness.dark, a11y);

  static ThemeData _build(Brightness brightness, A11yThemeOptions a11y) {
    final isLight = brightness == Brightness.light;
    final hc = a11y.highContrast;

    final cs = ColorScheme(
      brightness: brightness,
      primary: hc
          ? (isLight ? DonyColors.primaryHc : DonyColors.primaryHcDark)
          : (isLight ? DonyColors.primary : DonyColors.blueDark500),
      onPrimary: DonyColors.textOnBrand,
      primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
      onPrimaryContainer: isLight ? DonyColors.primaryHover : DonyColors.blueDark500,
      secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
      onSecondary: DonyColors.textOnBrand,
      secondaryContainer: isLight ? DonyColors.accentSoft : DonyColors.terraDark50,
      onSecondaryContainer: isLight ? DonyColors.terra700 : DonyColors.terraDark500,
      surface: hc
          ? (isLight ? DonyColors.surfaceHc : DonyColors.surfaceHcDark)
          : (isLight ? DonyColors.surface : DonyColors.neutralDark100),
      onSurface: hc
          ? (isLight ? DonyColors.textPrimaryHc : DonyColors.textPrimaryHcDark)
          : (isLight ? DonyColors.textPrimary : DonyColors.neutralDark700),
      onSurfaceVariant: hc
          ? (isLight ? DonyColors.textMutedHc : DonyColors.textMutedHcDark)
          : (isLight ? DonyColors.textMuted : DonyColors.neutralDark500),
      surfaceContainerHighest: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      surfaceContainerLow: isLight ? DonyColors.bgApp : DonyColors.neutralDark50,
      outline: hc
          ? (isLight ? DonyColors.borderDefaultHc : DonyColors.borderDefaultHcDark)
          : (isLight ? DonyColors.borderDefault : DonyColors.neutralDark300),
      outlineVariant: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      error: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      onError: DonyColors.textOnBrand,
      errorContainer: isLight ? DonyColors.danger50 : DonyColors.dangerDark50,
      onErrorContainer: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      shadow: isLight ? DonyColors.shadow : DonyColors.shadowDark,
      inverseSurface: isLight ? DonyColors.ink800 : DonyColors.neutral0,
      onInverseSurface: isLight ? DonyColors.neutral0 : DonyColors.textPrimary,
    );

    final scaffoldBg = hc
        ? (isLight ? DonyColors.bgAppHc : DonyColors.bgAppHcDark)
        : (isLight ? DonyColors.bgApp : DonyColors.neutralDark0);

    // Bordures épaissies en haut contraste : la bordure par défaut à 1 px sur
    // neutral200 est quasi invisible pour une basse vision.
    final borderWidth = hc ? 1.5 : 1.0;
```

Ajouter l'import en tête du fichier :

```dart
import 'package:dony/core/design/theme/a11y_theme_options.dart';
```

- [ ] **Step 6 : Appliquer l'épaisseur, le soulignement et les transitions**

Toujours dans `app_theme.dart`, dans le `ThemeData(...)` retourné :

Remplacer les trois `BorderSide(color: cs.outline)` de `inputDecorationTheme` (`border`, `enabledBorder`) et celui de `outlinedButtonTheme` par `BorderSide(color: cs.outline, width: borderWidth)`.

Remplacer le `cardTheme` `side:` par `side: BorderSide(color: cs.outline, width: borderWidth)`.

Remplacer `dividerTheme` par :

```dart
      dividerTheme: DividerThemeData(
        color: cs.outline,
        space: 1,
        thickness: borderWidth,
      ),
```

Remplacer `textButtonTheme` par :

```dart
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: DonyTypography.textTheme.labelLarge?.copyWith(
            decoration: a11y.underlineLinks
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
```

Ajouter, juste après `sliderTheme`, avant l'accolade fermante du `ThemeData` :

```dart
      pageTransitionsTheme: a11y.reduceMotion
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
            })
          : const PageTransitionsTheme(),
```

Et en fin de fichier, après la classe `AppTheme` :

```dart
/// Transition de page instantanée, utilisée quand la réduction du mouvement
/// est active. Les animations de navigation ne sont pas couvertes par
/// `MediaQuery.disableAnimations` sur toutes les plateformes, il faut donc
/// les neutraliser explicitement.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
```

- [ ] **Step 7 : Exporter l'objet d'options**

Dans `lib/core/design/design_system.dart`, ajouter :

```dart
export 'theme/a11y_theme_options.dart';
```

- [ ] **Step 8 : Lancer les tests**

Run: `flutter test test/core/design/theme/app_theme_a11y_test.dart`
Expected: PASS, 8 tests. Si un ratio échoue, ajuster la valeur du token concerné à l'étape 4, jamais le seuil du test.

- [ ] **Step 9 : Vérifier la non-régression du thème normal**

Run: `flutter test test/core/design`
Expected: PASS. Le thème sans options doit être identique à l'existant.

- [ ] **Step 10 : Commit**

```bash
git add lib/core/design/theme/ lib/core/design/tokens/color_tokens.dart lib/core/design/design_system.dart test/core/design/theme/app_theme_a11y_test.dart
git commit -m "feat(a11y): variantes de theme haut contraste et mouvement reduit

AppTheme.light et .dark prennent un A11yThemeOptions qui pilote le
contraste, le soulignement des liens et les transitions de page. Les
tokens haut contraste sont ajoutes et non substitues, donc le rendu
normal est inchange. Les ratios 7:1 et 4.5:1 sont verifies par test."
```

---

### Task 4 : Câblage racine, le cœur du correctif

**Files:**
- Modify: `lib/core/di/injection.dart:550-553`
- Modify: `lib/app/router.dart:1079-1085`
- Modify: `lib/app/app.dart`
- Test: `test/app/accessibility_propagation_test.dart`

**Interfaces:**
- Consumes: `AccessibilityBloc` (Task 1), `AccessibilityScope` (Task 2), `AppTheme.light/dark` avec `A11yThemeOptions` (Task 3).
- Produces: un `MediaQuery` racine reflétant l'état, un `AccessibilityScope` racine, et le thème adéquat.

**C'est la tâche qui corrige le bug.** Sans elle, les tâches 1 à 3 restent inertes, exactement comme le code actuel.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/app/accessibility_propagation_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduit le câblage racine de `app.dart` sans démarrer toute
/// l'application : Firebase, Hive et le routeur ne sont pas nécessaires pour
/// vérifier la propagation.
Widget harness(AccessibilityState state, {required Widget child}) {
  final effectiveContrast = state.highContrast == AccessibilityMode.on;
  final effectiveMotion = state.reduceMotion == AccessibilityMode.on;
  return MaterialApp(
    theme: AppTheme.light(
      a11y: A11yThemeOptions(
        highContrast: effectiveContrast,
        reduceMotion: effectiveMotion,
        underlineLinks: state.underlineLinks,
      ),
    ),
    builder: (context, inner) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: state.followSystemTextScale
              ? mq.textScaler.clamp(maxScaleFactor: kA11yMaxTextScale)
              : TextScaler.linear(state.textScaleFactor),
          boldText: state.boldText,
          disableAnimations: effectiveMotion,
        ),
        child: AccessibilityScope(
          underlineLinks: state.underlineLinks,
          reinforceLabels: state.reinforceLabels,
          persistentMessages: state.persistentMessages,
          confirmImportantActions: state.confirmImportantActions,
          child: inner ?? const SizedBox.shrink(),
        ),
      );
    },
    home: child,
  );
}

void main() {
  group('Propagation des réglages depuis la racine', () {
    testWidgets('un facteur manuel atteint MediaQuery.textScalerOf',
        (tester) async {
      late double scaled;
      await tester.pumpWidget(harness(
        const AccessibilityState(
          followSystemTextScale: false,
          textScaleFactor: 1.5,
        ),
        child: Builder(builder: (ctx) {
          scaled = MediaQuery.textScalerOf(ctx).scale(10);
          return const SizedBox.shrink();
        }),
      ));
      expect(scaled, 15.0);
    });

    testWidgets('le suivi système est plafonné à 200 %', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      late double scaled;
      await tester.pumpWidget(harness(
        const AccessibilityState(followSystemTextScale: true),
        child: Builder(builder: (ctx) {
          scaled = MediaQuery.textScalerOf(ctx).scale(10);
          return const SizedBox.shrink();
        }),
      ));
      expect(scaled, 20.0);
    });

    testWidgets('le gras atteint MediaQuery.boldTextOf', (tester) async {
      late bool bold;
      await tester.pumpWidget(harness(
        const AccessibilityState(boldText: true),
        child: Builder(builder: (ctx) {
          bold = MediaQuery.boldTextOf(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(bold, isTrue);
    });

    testWidgets('la réduction du mouvement atteint disableAnimations',
        (tester) async {
      late bool disabled;
      await tester.pumpWidget(harness(
        const AccessibilityState(reduceMotion: AccessibilityMode.on),
        child: Builder(builder: (ctx) {
          disabled = MediaQuery.disableAnimationsOf(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(disabled, isTrue);
    });

    testWidgets('le contraste forcé sélectionne la variante contrastée',
        (tester) async {
      late Color onSurface;
      await tester.pumpWidget(harness(
        const AccessibilityState(highContrast: AccessibilityMode.on),
        child: Builder(builder: (ctx) {
          onSurface = Theme.of(ctx).colorScheme.onSurface;
          return const SizedBox.shrink();
        }),
      ));
      expect(onSurface, DonyColors.textPrimaryHc);
    });

    testWidgets('les flags du scope sont lisibles via context.a11y',
        (tester) async {
      late bool reinforce;
      await tester.pumpWidget(harness(
        const AccessibilityState(reinforceLabels: true),
        child: Builder(builder: (ctx) {
          reinforce = ctx.a11y.reinforceLabels;
          return const SizedBox.shrink();
        }),
      ));
      expect(reinforce, isTrue);
    });
  });
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/app/accessibility_propagation_test.dart`
Expected: FAIL, `kA11yMaxTextScale` et `AccessibilityMode` doivent déjà exister depuis la tâche 1, mais `A11yThemeOptions` et `AccessibilityScope` doivent être importables. Si la tâche 3 est faite, ce test passe déjà : il valide le harnais avant de câbler la vraie app. Passer alors directement à l'étape 3, la valeur du test est de figer le contrat.

- [ ] **Step 3 : Passer le bloc en singleton**

Dans `lib/core/di/injection.dart`, remplacer :

```dart
  // Settings — Accessibility (text scale, high contrast, reduce animations)
  getIt.registerFactory<AccessibilityBloc>(
    () => AccessibilityBloc(getIt<HiveService>().userPrefs),
  );
```

par :

```dart
  // Settings — Accessibility.
  // Singleton et non factory : l'état pilote le thème et le MediaQuery de
  // toute l'application depuis app.dart. Une factory donnerait une instance
  // distincte à l'écran de réglages, et aucun changement ne sortirait de cet
  // écran, ce qui était précisément le bug corrigé ici.
  getIt.registerLazySingleton<AccessibilityBloc>(
    () => AccessibilityBloc(
      getIt<HiveService>().userPrefs,
      getIt<AnalyticsService>(),
    ),
  );
```

- [ ] **Step 4 : Pointer la route sur le singleton**

Dans `lib/app/router.dart`, remplacer le `GoRoute` `accessibility` par :

```dart
        GoRoute(
          path: 'accessibility',
          builder: (context, state) => BlocProvider.value(
            value: getIt<AccessibilityBloc>(),
            child: const AccessibilitySettingsScreen(),
          ),
        ),
```

- [ ] **Step 5 : Câbler la racine**

Dans `lib/app/app.dart`, ajouter les imports :

```dart
import 'package:dony/core/design/accessibility_scope.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
```

Envelopper le contenu existant. Le `BlocProvider<AppPreferencesBloc>.value` reste la racine, et le bloc d'accessibilité s'ajoute juste en dessous :

```dart
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<AppPreferencesBloc>.value(
            value: getIt<AppPreferencesBloc>(),
          ),
          BlocProvider<AccessibilityBloc>.value(
            value: getIt<AccessibilityBloc>(),
          ),
        ],
        child: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
          builder: (context, prefsState) {
            final themeMode = switch (prefsState.preferences.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            };
            return BlocConsumer<AccessibilityBloc, AccessibilityState>(
              listenWhen: (a, b) => a.reduceMotion != b.reduceMotion,
              listener: (context, a11y) {
                // Statique global de flutter_animate : il ne peut pas être posé
                // dans un build, et doit être remis à sa valeur d'origine dans
                // le tearDown des tests, sinon un test qui active la réduction
                // contamine tous les suivants.
                final reduce = _resolveMotion(context, a11y);
                Animate.defaultDuration =
                    reduce ? Duration.zero : const Duration(milliseconds: 300);
              },
              builder: (context, a11y) {
                final reduceMotion = _resolveMotion(context, a11y);
                final highContrast = _resolveContrast(context, a11y);
                final themeOptions = A11yThemeOptions(
                  highContrast: highContrast,
                  reduceMotion: reduceMotion,
                  underlineLinks: a11y.underlineLinks,
                );
                // Le `MultiBlocProvider` existant (ActiveRoleCubit, AuthBloc,
                // KycBloc, etc.), son `BlocListener<AuthBloc>` et son
                // `AnnotatedRegion` sont imbriqués ici tels quels, sans aucune
                // modification. Seul le `MaterialApp.router` qu'ils
                // contiennent change, à l'étape suivante.
                return /* MultiBlocProvider existant */;
              },
            );
          },
        ),
      );

  /// Résout le mode tri-état du mouvement contre le réglage système.
  static bool _resolveMotion(BuildContext context, AccessibilityState s) =>
      switch (s.reduceMotion) {
        AccessibilityMode.on => true,
        AccessibilityMode.off => false,
        _ => MediaQuery.disableAnimationsOf(context),
      };

  /// Résout le mode tri-état du contraste contre le réglage système.
  static bool _resolveContrast(BuildContext context, AccessibilityState s) =>
      switch (s.highContrast) {
        AccessibilityMode.on => true,
        AccessibilityMode.off => false,
        _ => MediaQuery.highContrastOf(context),
      };
```

Puis, dans le `MaterialApp.router` existant, remplacer les lignes de thème et le `builder` :

```dart
                  child: MaterialApp.router(
                    title: 'dony',
                    theme: AppTheme.light(a11y: themeOptions),
                    darkTheme: AppTheme.dark(a11y: themeOptions),
                    themeMode: themeMode,
                    locale: Locale(prefsState.preferences.languageCode),
                    routerConfig: appRouter,
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) {
                      final mq = MediaQuery.of(context);
                      return MediaQuery(
                        data: mq.copyWith(
                          textScaler: a11y.followSystemTextScale
                              ? mq.textScaler
                                  .clamp(maxScaleFactor: kA11yMaxTextScale)
                              : TextScaler.linear(a11y.textScaleFactor),
                          boldText: a11y.boldText,
                          disableAnimations: reduceMotion,
                        ),
                        child: AccessibilityScope(
                          underlineLinks: a11y.underlineLinks,
                          reinforceLabels: a11y.reinforceLabels,
                          persistentMessages: a11y.persistentMessages,
                          confirmImportantActions: a11y.confirmImportantActions,
                          child: AnalyticsConsentGate(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('fr', 'FR'),
                      Locale('en', 'US'),
                    ],
                  ),
```

- [ ] **Step 6 : Lancer les tests de propagation**

Run: `flutter test test/app/accessibility_propagation_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 7 : Protéger la suite de tests du statique global**

`Animate.defaultDuration` est une variable statique de `flutter_animate`. Un test qui monte l'application avec la réduction du mouvement active la met à `Duration.zero` pour tous les tests suivants du même fichier, ce qui fait passer au vert des animations qui devraient être vérifiées.

Créer `test/flutter_test_config.dart` s'il n'existe pas, sinon ajouter le `tearDown` au fichier existant :

```dart
import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final original = Animate.defaultDuration;
  tearDown(() => Animate.defaultDuration = original);
  await testMain();
}
```

Ce fichier est détecté automatiquement par `flutter test` et s'applique à toute la suite. Vérifier avant de le créer : `ls test/flutter_test_config.dart`. S'il existe déjà, y insérer les deux lignes `original` et `tearDown` sans toucher au reste.

- [ ] **Step 8 : Vérifier l'analyse et la suite existante**

Run: `flutter analyze lib/app lib/core/di`
Expected: aucune erreur.

Run: `flutter test test/app`
Expected: PASS. Si un test existant de `app.dart` casse à cause du `MultiBlocProvider` racine, l'ajuster pour fournir `AccessibilityBloc`, sans jamais supprimer d'assertion.

- [ ] **Step 9 : Commit**

```bash
git add lib/app/app.dart lib/app/router.dart lib/core/di/injection.dart test/app/accessibility_propagation_test.dart
git commit -m "fix(a11y): applique reellement les reglages a toute l'application

AccessibilityBloc passe en singleton fourni a la racine. Son etat pilote
desormais le choix de la variante de theme, un MediaQuery reinjecte
(taille de texte plafonnee a 200 %, gras, animations) et un
AccessibilityScope. Jusqu'ici les trois reglages ecrivaient dans Hive
sans qu'aucun consommateur ne les lise."
```

---

### Task 5 : Widgets de l'écran

**Files:**
- Create: `lib/features/settings/presentation/widgets/a11y_slider_row.dart`
- Create: `lib/features/settings/presentation/widgets/a11y_tristate_row.dart`
- Test: `test/features/settings/presentation/widgets/a11y_rows_test.dart`

**Interfaces:**
- Consumes: `AccessibilityMode` (Task 1), `DonyListTile`, `DonyBottomSheet`, `DonyRadioGroup`.
- Produces:
  - `A11ySliderRow({required double value, required bool enabled, required ValueChanged<double> onChanged})`.
  - `A11yTristateRow({required String label, required String subtitle, required String value, required String sheetTitle, required ValueChanged<String> onChanged, bool showDivider = true, String? iconAsset})`.
  - `a11yModeLabel(String mode)` renvoyant `'Suivre le téléphone'`, `'Toujours activé'` ou `'Toujours désactivé'`.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/features/settings/presentation/widgets/a11y_rows_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_slider_row.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_tristate_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('A11ySliderRow', () {
    testWidgets('affiche le pourcentage courant', (tester) async {
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.25, enabled: true, onChanged: (_) {}),
      ));
      expect(find.text('125 %'), findsOneWidget);
    });

    testWidgets('le curseur est désactivé quand enabled est faux',
        (tester) async {
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.0, enabled: false, onChanged: (_) {}),
      ));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('le curseur remonte la nouvelle valeur', (tester) async {
      double? received;
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.0, enabled: true, onChanged: (v) => received = v),
      ));
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      expect(received, isNotNull);
      expect(received, greaterThan(1.0));
    });
  });

  group('A11yTristateRow', () {
    testWidgets('affiche le libellé du mode courant', (tester) async {
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Suivre le téléphone'), findsOneWidget);
      expect(find.text('Renforce le texte et les bordures'), findsOneWidget);
    });

    testWidgets('le tap ouvre la sheet avec les trois choix', (tester) async {
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (_) {},
        ),
      ));
      await tester.tap(find.text('Contraste élevé').first);
      await tester.pumpAndSettle();
      expect(find.text('Toujours activé'), findsOneWidget);
      expect(find.text('Toujours désactivé'), findsOneWidget);
    });

    testWidgets('sélectionner un choix remonte la valeur et ferme la sheet',
        (tester) async {
      String? received;
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (v) => received = v,
        ),
      ));
      await tester.tap(find.text('Contraste élevé').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toujours activé'));
      await tester.pumpAndSettle();
      expect(received, AccessibilityMode.on);
      expect(find.text('Toujours désactivé'), findsNothing);
    });
  });

  group('a11yModeLabel', () {
    test('traduit les trois modes', () {
      expect(a11yModeLabel(AccessibilityMode.system), 'Suivre le téléphone');
      expect(a11yModeLabel(AccessibilityMode.on), 'Toujours activé');
      expect(a11yModeLabel(AccessibilityMode.off), 'Toujours désactivé');
    });
  });
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/settings/presentation/widgets/a11y_rows_test.dart`
Expected: FAIL, les deux fichiers de widgets n'existent pas.

- [ ] **Step 3 : Écrire la ligne curseur**

Créer `lib/features/settings/presentation/widgets/a11y_slider_row.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Ligne de réglage de la taille du texte.
///
/// Remplace le `SegmentedButton` d'origine : quatre segments plus une icône de
/// coche ne tenaient pas dans la largeur, ce qui coupait « Normale » en trois
/// lignes. Un curseur ne peut pas déborder, quelle que soit la taille de texte
/// appliquée, et offre 24 valeurs au lieu de 4.
class A11ySliderRow extends StatelessWidget {
  const A11ySliderRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;

  /// Faux quand la taille suit le système : le curseur est alors inerte et
  /// grisé, plutôt que masqué, pour que le réglage reste lisible.
  final bool enabled;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final percent = '${(value * 100).round()} %';

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.md,
          DonySpacing.base,
          DonySpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Taille du texte',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  percent,
                  style: tt.titleMedium?.copyWith(color: cs.primary),
                ),
              ],
            ),
            Semantics(
              label: 'Taille du texte',
              value: percent,
              child: Slider(
                value: value,
                min: kA11yMinTextScale,
                max: kA11yMaxTextScale,
                // Pas de 5 % : assez fin pour ajuster, assez grossier pour
                // être atteignable au doigt.
                divisions: ((kA11yMaxTextScale - kA11yMinTextScale) / 0.05)
                    .round(),
                label: percent,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('85 %', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                Text('200 %', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Écrire la ligne tri-état**

Créer `lib/features/settings/presentation/widgets/a11y_tristate_row.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Libellé affiché pour un mode tri-état.
String a11yModeLabel(String mode) => switch (mode) {
      AccessibilityMode.on => 'Toujours activé',
      AccessibilityMode.off => 'Toujours désactivé',
      _ => 'Suivre le téléphone',
    };

/// Ligne de réglage tri-état, ouvrant une sheet à trois choix.
///
/// Motif du choix d'une sheet plutôt que de trois pastilles côte à côte :
/// trois libellés alignés déborderaient à 200 % de taille de texte, soit
/// exactement le défaut que cet écran corrige.
class A11yTristateRow extends StatelessWidget {
  const A11yTristateRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.sheetTitle,
    required this.onChanged,
    this.iconAsset,
    this.showDivider = true,
  });

  final String label;
  final String subtitle;
  final String value;
  final String sheetTitle;
  final ValueChanged<String> onChanged;
  final String? iconAsset;
  final bool showDivider;

  Future<void> _open(BuildContext context) async {
    final picked = await DonyBottomSheet.show<String>(
      context,
      title: sheetTitle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.base),
        child: DonyRadioGroup<String>(
          value: value,
          onChanged: (v) {
            if (v != null) {
              Navigator.of(context, rootNavigator: true).pop(v);
            }
          },
          options: const [
            DonyRadioOption(
              value: AccessibilityMode.system,
              label: 'Suivre le téléphone',
              subtitle: 'Utilise le réglage défini dans votre téléphone',
            ),
            DonyRadioOption(
              value: AccessibilityMode.on,
              label: 'Toujours activé',
              subtitle: 'Quel que soit le réglage du téléphone',
            ),
            DonyRadioOption(
              value: AccessibilityMode.off,
              label: 'Toujours désactivé',
              subtitle: 'Quel que soit le réglage du téléphone',
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyListTile(
      label: label,
      subtitle: subtitle,
      iconAsset: iconAsset,
      iconColor: cs.primary,
      iconBgColor: cs.primaryContainer,
      showDivider: showDivider,
      onTap: () => _open(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              a11yModeLabel(value),
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/settings/presentation/widgets/a11y_rows_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/settings/presentation/widgets/a11y_slider_row.dart lib/features/settings/presentation/widgets/a11y_tristate_row.dart test/features/settings/presentation/widgets/a11y_rows_test.dart
git commit -m "feat(a11y): lignes curseur et tri-etat de l'ecran accessibilite

Le curseur remplace le SegmentedButton, dont les quatre segments
coupaient le libelle Normale en trois lignes. Les reglages tri-etats
passent par une sheet a trois choix plutot que par des pastilles
alignees, qui deborderaient a 200 % de taille de texte."
```

---

### Task 6 : Carte d'aperçu vivant

**Files:**
- Create: `lib/features/settings/presentation/widgets/a11y_preview_card.dart`
- Test: `test/features/settings/presentation/widgets/a11y_preview_card_test.dart`

**Interfaces:**
- Consumes: `AccessibilityState` (Task 1), `A11yThemeOptions` (Task 3), `AccessibilityScope` (Task 2).
- Produces: `A11yPreviewCard({required AccessibilityState state})`.

L'aperçu applique les réglages localement, sans attendre la reconstruction globale, pour que l'effet soit visible dans le même geste que le réglage.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/features/settings/presentation/widgets/a11y_preview_card_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(AccessibilityState state) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: A11yPreviewCard(state: state)),
    );

void main() {
  testWidgets('affiche un exemple de trajet', (tester) async {
    await tester.pumpWidget(wrap(const AccessibilityState()));
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Aperçu'), findsOneWidget);
  });

  testWidgets('le facteur de taille agrandit le texte de l\'aperçu',
      (tester) async {
    Size sizeOf(WidgetTester t) => t.getSize(find.text('Paris'));

    await tester.pumpWidget(wrap(const AccessibilityState(
      followSystemTextScale: false,
      textScaleFactor: 1.0,
    )));
    final small = sizeOf(tester);

    await tester.pumpWidget(wrap(const AccessibilityState(
      followSystemTextScale: false,
      textScaleFactor: 2.0,
    )));
    await tester.pump();
    final big = sizeOf(tester);

    expect(big.height, greaterThan(small.height));
  });

  testWidgets('le contraste élevé change la couleur du texte de l\'aperçu',
      (tester) async {
    Color colorOf(WidgetTester t) =>
        t.widget<Text>(find.text('Paris')).style?.color ?? Colors.transparent;

    await tester.pumpWidget(wrap(const AccessibilityState()));
    final normal = colorOf(tester);

    await tester.pumpWidget(wrap(
      const AccessibilityState(highContrast: AccessibilityMode.on),
    ));
    await tester.pump();
    expect(colorOf(tester), isNot(normal));
  });

  testWidgets('l\'aperçu affiche un badge de statut', (tester) async {
    await tester.pumpWidget(wrap(const AccessibilityState()));
    expect(find.textContaining('Urgent'), findsOneWidget);
  });
}
```

Note : la vérification du texte renforcé (« Départ imminent ») appartient à la tâche 7, qui câble `DonyUrgentBadge`. L'écrire ici obligerait à committer un test rouge, ce que la politique de test du projet interdit.

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/settings/presentation/widgets/a11y_preview_card_test.dart`
Expected: FAIL, `a11y_preview_card.dart` n'existe pas.

- [ ] **Step 3 : Écrire la carte**

Créer `lib/features/settings/presentation/widgets/a11y_preview_card.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Aperçu réagissant en direct aux réglages d'accessibilité.
///
/// Sans lui, l'écran de réglages est invérifiable de l'extérieur : on bascule
/// une option et rien ne bouge à l'écran. L'aperçu applique les réglages
/// localement, via un [Theme] et un [MediaQuery] dérivés de l'état, donc
/// l'effet est visible dans le même geste que le réglage.
class A11yPreviewCard extends StatelessWidget {
  const A11yPreviewCard({super.key, required this.state});

  final AccessibilityState state;

  @override
  Widget build(BuildContext context) {
    final outerTt = Theme.of(context).textTheme;
    final outerCs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = A11yThemeOptions(
      highContrast: state.highContrast == AccessibilityMode.on,
      reduceMotion: state.reduceMotion == AccessibilityMode.on,
      underlineLinks: state.underlineLinks,
    );
    final previewTheme =
        isDark ? AppTheme.dark(a11y: options) : AppTheme.light(a11y: options);

    final mq = MediaQuery.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Text(
            'Aperçu',
            style: outerTt.labelMedium?.copyWith(
              color: outerCs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Theme(
          data: previewTheme,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: state.followSystemTextScale
                  ? mq.textScaler.clamp(maxScaleFactor: kA11yMaxTextScale)
                  : TextScaler.linear(state.textScaleFactor),
              boldText: state.boldText,
            ),
            child: AccessibilityScope(
              underlineLinks: state.underlineLinks,
              reinforceLabels: state.reinforceLabels,
              persistentMessages: state.persistentMessages,
              confirmImportantActions: state.confirmImportantActions,
              child: Builder(builder: _buildSample),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSample(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: cs.outline,
          width: state.highContrast == AccessibilityMode.on ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            children: [
              Text('Paris', style: tt.titleLarge?.copyWith(color: cs.onSurface)),
              Icon(Icons.arrow_forward_rounded, size: 16, color: cs.onSurfaceVariant),
              Text('Dakar', style: tt.titleLarge?.copyWith(color: cs.onSurface)),
              const DonyUrgentBadge(),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            '12 kg disponibles',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Faire une offre',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer les tests**

Run: `flutter test test/features/settings/presentation/widgets/a11y_preview_card_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/settings/presentation/widgets/a11y_preview_card.dart test/features/settings/presentation/widgets/a11y_preview_card_test.dart
git commit -m "feat(a11y): apercu vivant des reglages d'accessibilite

Applique les reglages localement via un Theme et un MediaQuery derives
de l'etat, pour que l'effet soit visible dans le meme geste que le
reglage."
```

---

### Task 7 : Composants sensibles aux flags

**Files:**
- Modify: `lib/core/design/widgets/dony_urgent_badge.dart`
- Modify: `lib/core/design/widgets/dony_badge.dart`
- Modify: `lib/core/design/widgets/dony_status_banner.dart`
- Modify: `lib/core/design/widgets/dony_snackbar.dart`
- Test: `test/core/design/widgets/a11y_aware_widgets_test.dart`

**Interfaces:**
- Consumes: `context.a11y` (Task 2).
- Produces: rien de nouveau, comportement conditionnel des composants existants.

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `test/core/design/widgets/a11y_aware_widgets_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {bool reinforce = false, bool persistent = false}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: AccessibilityScope(
        underlineLinks: false,
        reinforceLabels: reinforce,
        persistentMessages: persistent,
        confirmImportantActions: false,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(DonySnackbar.clearDedup);

  group('DonyUrgentBadge', () {
    testWidgets('sans renforcement, affiche le libellé court', (tester) async {
      await tester.pumpWidget(wrap(const DonyUrgentBadge()));
      expect(find.textContaining('Urgent'), findsOneWidget);
      expect(find.textContaining('Départ imminent'), findsNothing);
    });

    testWidgets('avec renforcement, explicite le statut', (tester) async {
      await tester.pumpWidget(
          wrap(const DonyUrgentBadge(), reinforce: true));
      expect(find.textContaining('Départ imminent'), findsOneWidget);
    });
  });

  group('DonyBadge', () {
    testWidgets('avec renforcement, un badge sans icône en reçoit une',
        (tester) async {
      await tester.pumpWidget(wrap(
        const DonyBadge(label: 'Payé', type: DonyBadgeType.success),
        reinforce: true,
      ));
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('sans renforcement, un badge sans icône n\'en reçoit pas',
        (tester) async {
      await tester.pumpWidget(wrap(
        const DonyBadge(label: 'Payé', type: DonyBadgeType.success),
      ));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('une icône explicite n\'est jamais remplacée', (tester) async {
      await tester.pumpWidget(wrap(
        const DonyBadge(
          label: 'Payé',
          type: DonyBadgeType.success,
          icon: Icons.star,
        ),
        reinforce: true,
      ));
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('DonySnackbar', () {
    testWidgets('sans option, la durée reste de 4 secondes', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(wrap(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));
      DonySnackbar.show(ctx, message: 'Bonjour');
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 4));
    });

    testWidgets('avec messages persistants, la durée est longue et fermable',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(wrap(
        Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
        persistent: true,
      ));
      DonySnackbar.show(ctx, message: 'Bonjour');
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration.inMinutes, greaterThanOrEqualTo(1));
      expect(find.text('Fermer'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/design/widgets/a11y_aware_widgets_test.dart`
Expected: FAIL sur les tests de renforcement et de persistance.

- [ ] **Step 3 : Rendre DonyUrgentBadge explicite**

Dans `lib/core/design/widgets/dony_urgent_badge.dart`, remplacer le `Text` par :

```dart
      child: Text(
        // Sans renforcement, la pastille rouge et l'emoji portent le sens. Avec
        // renforcement, le statut est écrit en toutes lettres : une information
        // ne doit pas dépendre de la seule couleur (WCAG 1.4.1).
        context.a11y.reinforceLabels ? '🔥 Départ imminent' : '🔥 Urgent',
```

- [ ] **Step 4 : Rendre DonyBadge explicite**

Dans `lib/core/design/widgets/dony_badge.dart`, après le `switch` des couleurs, ajouter :

```dart
    // En mode étiquettes renforcées, un badge sans icône en reçoit une, tirée
    // de son type : la couleur seule ne suffit pas à distinguer un succès d'une
    // erreur pour une vision des couleurs atypique.
    final fallbackIcon = switch (type) {
      DonyBadgeType.info => Icons.info_outline,
      DonyBadgeType.success => Icons.check_circle_outline,
      DonyBadgeType.warning => Icons.warning_amber_rounded,
      DonyBadgeType.error => Icons.error_outline,
    };
    final effectiveIcon = icon ??
        (context.a11y.reinforceLabels && iconAsset == null
            ? fallbackIcon
            : null);
```

Puis remplacer `if (icon != null) ...[` par `if (effectiveIcon != null) ...[` et `Icon(icon, size: 12, color: fg)` par `Icon(effectiveIcon, size: 12, color: fg)`.

- [ ] **Step 5 : Rendre DonyStatusBanner explicite**

Dans `lib/core/design/widgets/dony_status_banner.dart`, localiser la résolution de l'icône par type (elle existe déjà pour la valeur par défaut) et s'assurer que le titre reste affiché en mode renforcé. Ajouter, dans le `build`, juste avant la construction du contenu :

```dart
    // Le bandeau porte déjà une icône par type. En mode étiquettes renforcées,
    // on garantit en plus qu'un titre textuel est présent, pour ne pas laisser
    // la couleur de fond porter seule la nature du message.
    final reinforcedTitle = title ??
        (context.a11y.reinforceLabels
            ? switch (type) {
                DonyStatusBannerType.info => 'Information',
                DonyStatusBannerType.success => 'Succès',
                DonyStatusBannerType.warning => 'Attention',
                DonyStatusBannerType.error => 'Erreur',
              }
            : null);
```

Puis remplacer les usages de `title` dans le `build` par `reinforcedTitle`.

Si les noms de l'enum diffèrent, les lire dans le fichier et adapter, sans changer les valeurs.

- [ ] **Step 6 : Rendre DonySnackbar persistant sur option**

Dans `lib/core/design/widgets/dony_snackbar.dart`, dans `show`, juste après la résolution de `cs` et `tt`, ajouter :

```dart
    // Avec l'option « garder les messages affichés », le message ne disparaît
    // plus tout seul : quatre secondes ne suffisent pas à qui lit lentement ou
    // navigue au lecteur d'écran (WCAG 2.2.1). Une action de fermeture
    // explicite remplace la disparition automatique.
    final persistent = context.a11y.persistentMessages;
    final effectiveDuration =
        persistent ? const Duration(minutes: 10) : duration;
    final effectiveActionLabel =
        actionLabel ?? (persistent ? 'Fermer' : null);
```

Puis, dans le `SnackBar` construit plus bas, utiliser `duration: effectiveDuration` à la place de `duration: duration`, et pour l'action : si `onAction` est nul et que `persistent` est vrai, l'action ferme la snackbar via `ScaffoldMessenger.of(context).hideCurrentSnackBar()`. Utiliser `effectiveActionLabel` comme libellé.

- [ ] **Step 7 : Lancer les tests**

Run: `flutter test test/core/design/widgets/a11y_aware_widgets_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 8 : Vérifier que l'aperçu reste vert**

Run: `flutter test test/features/settings/presentation/widgets/a11y_preview_card_test.dart`
Expected: PASS, 4 tests. L'aperçu affiche `DonyUrgentBadge`, qui vient de changer de comportement conditionnel : ce test confirme qu'aucun cas par défaut n'a bougé.

- [ ] **Step 9 : Vérifier la non-régression du design system**

Run: `flutter test test/core/design`
Expected: PASS. Les composants sans scope monté doivent conserver leur comportement d'origine, grâce aux valeurs par défaut de `AccessibilityScope.of`.

- [ ] **Step 10 : Commit**

```bash
git add lib/core/design/widgets/ test/core/design/widgets/a11y_aware_widgets_test.dart
git commit -m "feat(a11y): etiquettes renforcees et messages persistants

Les badges, le badge urgent et les bandeaux de statut cessent de faire
porter l'information par la seule couleur quand l'option est active. Les
messages temporaires restent affiches jusqu'a fermeture manuelle quand
l'option est active."
```

---

### Task 8 : Écran de réglages

**Files:**
- Rewrite: `lib/features/settings/presentation/screens/accessibility_settings_screen.dart`
- Modify: `pubspec.yaml` (ajout de `app_settings`)
- Test: `test/features/settings/presentation/accessibility_settings_screen_test.dart` (réécrit)

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: l'écran complet.

- [ ] **Step 1 : Ajouter la dépendance**

Dans `pubspec.yaml`, sous `dependencies`, à côté de `url_launcher` :

```yaml
  app_settings: ^5.1.1
```

Run: `flutter pub get`

Note : l'ajout d'une dépendance native invalide le build incrémental. Le premier `flutter run` suivant sera long, et un échec au tout premier build sur cache froid se résout en relançant la commande.

- [ ] **Step 2 : Écrire les tests qui échouent**

Remplacer entièrement `test/features/settings/presentation/accessibility_settings_screen_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccessibilityBloc
    extends MockBloc<AccessibilityEvent, AccessibilityState>
    implements AccessibilityBloc {}

void main() {
  late MockAccessibilityBloc bloc;

  setUp(() {
    bloc = MockAccessibilityBloc();
    when(() => bloc.state).thenReturn(const AccessibilityState());
  });

  Widget wrap() => MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<AccessibilityBloc>.value(
          value: bloc,
          child: const AccessibilitySettingsScreen(),
        ),
      );

  group('AccessibilitySettingsScreen — structure', () {
    testWidgets('affiche les quatre sections', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('TEXTE'), findsOneWidget);
      expect(find.text('AFFICHAGE'), findsOneWidget);
      expect(find.text('MOUVEMENT'), findsOneWidget);
      expect(find.text('MESSAGES ET ACTIONS'), findsOneWidget);
    });

    testWidgets('affiche l\'aperçu en tête', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Aperçu'), findsOneWidget);
    });

    testWidgets('n\'utilise plus de SegmentedButton', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byType(SegmentedButton<String>), findsNothing);
    });

    testWidgets('affiche les neuf réglages', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Suivre les réglages du téléphone'), findsOneWidget);
      expect(find.text('Taille du texte'), findsOneWidget);
      expect(find.text('Texte en gras'), findsOneWidget);
      expect(find.text('Contraste élevé'), findsOneWidget);
      expect(find.text('Souligner les liens'), findsOneWidget);
      expect(find.text('Renforcer les étiquettes'), findsOneWidget);
      expect(find.text('Réduire les animations'), findsOneWidget);
      expect(find.text('Garder les messages affichés'), findsOneWidget);
      expect(find.text('Confirmer les actions importantes'), findsOneWidget);
    });
  });

  group('AccessibilitySettingsScreen — interactions', () {
    testWidgets('le curseur est inerte quand le suivi système est actif',
        (tester) async {
      await tester.pumpWidget(wrap());
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('le curseur est actif quand le suivi système est coupé',
        (tester) async {
      when(() => bloc.state).thenReturn(
        const AccessibilityState(followSystemTextScale: false),
      );
      await tester.pumpWidget(wrap());
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNotNull);
    });

    testWidgets('basculer le suivi système envoie l\'event', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Suivre les réglages du téléphone'));
      await tester.pump();
      verify(() => bloc.add(const FollowSystemTextScaleToggled(false)))
          .called(1);
    });

    testWidgets('basculer le gras envoie l\'event', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Texte en gras'));
      await tester.pump();
      verify(() => bloc.add(const BoldTextToggled(true))).called(1);
    });

    testWidgets('choisir un mode de contraste envoie l\'event',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Contraste élevé'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toujours activé'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const HighContrastModeChanged('on'))).called(1);
    });

    testWidgets('la réinitialisation demande confirmation puis envoie l\'event',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Tout réinitialiser'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmer'), findsOneWidget);
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const AccessibilityResetRequested())).called(1);
    });

    testWidgets('annuler la réinitialisation n\'envoie rien', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Tout réinitialiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(const AccessibilityResetRequested()));
    });
  });

  group('AccessibilitySettingsScreen — accessibilité de l\'écran lui-même', () {
    testWidgets('respecte les cibles tactiles et le contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('tient à 200 % de taille de texte sans débordement',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: BlocProvider<AccessibilityBloc>.value(
            value: bloc,
            child: const AccessibilitySettingsScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 3 : Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/settings/presentation/accessibility_settings_screen_test.dart`
Expected: FAIL, l'écran utilise encore l'ancienne API.

- [ ] **Step 4 : Écrire l'écran**

Remplacer entièrement `lib/features/settings/presentation/screens/accessibility_settings_screen.dart` :

```dart
import 'package:app_settings/app_settings.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_preview_card.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_slider_row.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_tristate_row.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Accessibilité'),
      body: BlocBuilder<AccessibilityBloc, AccessibilityState>(
        builder: (context, state) {
          final bloc = context.read<AccessibilityBloc>();
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            children: [
              A11yPreviewCard(state: state),
              const SizedBox(height: DonySpacing.xl),

              const SettingsSectionHeader('TEXTE'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'smartphone',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Suivre les réglages du téléphone',
                    subtitle:
                        'La taille du texte suit celle définie dans votre téléphone',
                    trailing: Switch(
                      value: state.followSystemTextScale,
                      activeThumbColor: cs.primary,
                      onChanged: (v) =>
                          bloc.add(FollowSystemTextScaleToggled(v)),
                    ),
                    onTap: () => bloc.add(FollowSystemTextScaleToggled(
                        !state.followSystemTextScale)),
                  ),
                  A11ySliderRow(
                    value: state.textScaleFactor,
                    enabled: !state.followSystemTextScale,
                    onChanged: (v) => bloc.add(TextScaleFactorChanged(v)),
                  ),
                  DonyListTile(
                    iconAsset: 'bold',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Texte en gras',
                    subtitle: 'Épaissit tous les textes de l\'application',
                    showDivider: false,
                    trailing: Switch(
                      value: state.boldText,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(BoldTextToggled(v)),
                    ),
                    onTap: () => bloc.add(BoldTextToggled(!state.boldText)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('AFFICHAGE'),
              SettingsFlatGroup(
                children: [
                  A11yTristateRow(
                    iconAsset: 'contrast',
                    label: 'Contraste élevé',
                    subtitle:
                        'Renforce le texte, les bordures et les séparateurs',
                    sheetTitle: 'Contraste élevé',
                    value: state.highContrast,
                    onChanged: (v) => bloc.add(HighContrastModeChanged(v)),
                  ),
                  DonyListTile(
                    iconAsset: 'link',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Souligner les liens',
                    subtitle:
                        'Les liens ne sont plus signalés par la couleur seule',
                    trailing: Switch(
                      value: state.underlineLinks,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(UnderlineLinksToggled(v)),
                    ),
                    onTap: () =>
                        bloc.add(UnderlineLinksToggled(!state.underlineLinks)),
                  ),
                  DonyListTile(
                    iconAsset: 'tag',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Renforcer les étiquettes',
                    subtitle:
                        'Ajoute une icône et un mot aux statuts signalés par une couleur',
                    showDivider: false,
                    trailing: Switch(
                      value: state.reinforceLabels,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(ReinforceLabelsToggled(v)),
                    ),
                    onTap: () => bloc
                        .add(ReinforceLabelsToggled(!state.reinforceLabels)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('MOUVEMENT'),
              SettingsFlatGroup(
                children: [
                  A11yTristateRow(
                    iconAsset: 'circle-play',
                    label: 'Réduire les animations',
                    subtitle:
                        'Supprime les transitions, les apparitions et les effets de chargement',
                    sheetTitle: 'Réduire les animations',
                    value: state.reduceMotion,
                    showDivider: false,
                    onChanged: (v) => bloc.add(ReduceMotionModeChanged(v)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('MESSAGES ET ACTIONS'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'message-square',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Garder les messages affichés',
                    subtitle:
                        'Les messages restent visibles jusqu\'à ce que vous les fermiez',
                    trailing: Switch(
                      value: state.persistentMessages,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(PersistentMessagesToggled(v)),
                    ),
                    onTap: () => bloc.add(
                        PersistentMessagesToggled(!state.persistentMessages)),
                  ),
                  DonyListTile(
                    iconAsset: 'shield-check',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Confirmer les actions importantes',
                    subtitle:
                        'Demande une confirmation avant un paiement, une annulation ou une suppression',
                    showDivider: false,
                    trailing: Switch(
                      value: state.confirmImportantActions,
                      activeThumbColor: cs.primary,
                      onChanged: (v) =>
                          bloc.add(ConfirmImportantActionsToggled(v)),
                    ),
                    onTap: () => bloc.add(ConfirmImportantActionsToggled(
                        !state.confirmImportantActions)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),

              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'settings',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'Ouvrir les réglages du téléphone',
                    subtitle:
                        'Taille de texte, contraste et animations du système',
                    showDivider: false,
                    trailing: Icon(Icons.open_in_new_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    onTap: () => AppSettings.openAppSettings(
                        type: AppSettingsType.accessibility),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.base),

              Center(
                child: TextButton(
                  onPressed: () => _confirmReset(context, bloc),
                  child: Text(
                    'Tout réinitialiser',
                    style: tt.labelLarge?.copyWith(color: cs.error),
                  ),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, AccessibilityBloc bloc) async {
    final ok = await DonyDialog.show(
      context,
      title: 'Tout réinitialiser',
      message:
          'Tous les réglages d\'accessibilité reviendront à leur valeur d\'origine.',
      variant: DonyDialogVariant.danger,
    );
    if (ok ?? false) {
      bloc.add(const AccessibilityResetRequested());
    }
  }
}
```

Si l'un des noms d'icône passés à `iconAsset` n'existe pas dans `assets/icons/`, choisir le plus proche présent dans ce dossier plutôt que d'ajouter un asset : un ajout d'asset impose un rebuild complet.

Si `DonyDialogVariant.danger` n'existe pas sous ce nom, lire l'enum dans `dony_dialog.dart` et utiliser la valeur destructive existante.

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/settings/presentation/accessibility_settings_screen_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 6 : Vérifier l'analyse**

Run: `flutter analyze lib/features/settings`
Expected: aucune erreur.

- [ ] **Step 7 : Commit**

```bash
git add lib/features/settings/presentation/screens/accessibility_settings_screen.dart pubspec.yaml pubspec.lock test/features/settings/presentation/accessibility_settings_screen_test.dart
git commit -m "feat(a11y): refonte de l'ecran Accessibilite

Quatre sections, un apercu vivant en tete, un curseur a la place du
SegmentedButton, des sheets a trois choix pour les reglages tri-etats,
un acces aux reglages systeme et une reinitialisation. L'ecran est
verifie a 200 % de taille de texte et contre les regles de cible
tactile et de contraste."
```

---

### Task 9 : Confirmation des actions importantes

**Files:**
- Modify: `lib/features/payments/presentation/payment_auth.dart`
- Modify: le point d'entrée de l'annulation dans `lib/features/cancellation/presentation/`
- Modify: le point d'entrée de la suppression de compte dans `lib/features/settings/presentation/`
- Test: `test/features/settings/a11y_confirm_actions_test.dart`

**Interfaces:**
- Consumes: `context.a11y.confirmImportantActions` (Task 2), `DonyDialog.show` (existant).
- Produces: un helper partagé `confirmImportantAction(BuildContext context, {required String title, required String message})` renvoyant `Future<bool>`, placé dans `lib/core/design/accessibility_scope.dart` pour rester au même endroit que le flag.

- [ ] **Step 1 : Localiser les trois points d'entrée**

Run: `rg -n "requirePaymentAuth" lib/features/payments/presentation/payment_auth.dart`
Run: `rg -rn "AccountDeletionBloc\|RequestDeletion" lib/features/settings lib/features/auth`
Run: `rg -rn "TripCancellationRequested" lib/features/cancellation`

Noter les fichiers et lignes exacts avant de modifier quoi que ce soit.

- [ ] **Step 2 : Écrire le test qui échoue**

Créer `test/features/settings/a11y_confirm_actions_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {required bool confirm}) => MaterialApp(
      theme: AppTheme.light(),
      home: AccessibilityScope(
        underlineLinks: false,
        reinforceLabels: false,
        persistentMessages: false,
        confirmImportantActions: confirm,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('sans l\'option, l\'action passe sans dialogue', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: false,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Confirmer le paiement'), findsNothing);
  });

  testWidgets('avec l\'option, un dialogue s\'intercale', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: true,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le paiement'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('refuser le dialogue annule l\'action', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(
      Builder(builder: (ctx) {
        return TextButton(
          onPressed: () async {
            result = await confirmImportantAction(
              ctx,
              title: 'Confirmer le paiement',
              message: 'Le montant sera bloqué jusqu\'à la livraison.',
            );
          },
          child: const Text('Payer'),
        );
      }),
      confirm: true,
    ));
    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
```

- [ ] **Step 3 : Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/settings/a11y_confirm_actions_test.dart`
Expected: FAIL, `confirmImportantAction` n'existe pas.

- [ ] **Step 4 : Écrire le helper**

Ajouter à la fin de `lib/core/design/accessibility_scope.dart` :

```dart
/// Intercale une confirmation quand l'utilisateur a activé « Confirmer les
/// actions importantes ». Renvoie vrai si l'action peut se poursuivre.
///
/// Sans l'option, la fonction est transparente et renvoie vrai immédiatement :
/// elle ne doit jamais ajouter un dialogue à qui ne l'a pas demandé.
Future<bool> confirmImportantAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!AccessibilityScope.of(context).confirmImportantActions) {
    return true;
  }
  final ok = await DonyDialog.show(
    context,
    title: title,
    message: message,
  );
  return ok ?? false;
}
```

Ajouter en tête du fichier les imports nécessaires :

```dart
import 'package:dony/core/design/widgets/dony_dialog.dart';
import 'package:flutter/material.dart';
```

et remplacer `import 'package:flutter/widgets.dart';` par l'import material, qui l'englobe.

- [ ] **Step 5 : Lancer le test**

Run: `flutter test test/features/settings/a11y_confirm_actions_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6 : Brancher les trois points d'entrée**

Dans `payment_auth.dart`, au tout début de `requirePaymentAuth`, avant la biométrie :

```dart
  final confirmed = await confirmImportantAction(
    context,
    title: 'Confirmer le paiement',
    message:
        'Le montant sera bloqué jusqu\'à la livraison, puis versé au voyageur.',
  );
  if (!confirmed) {
    return false;
  }
```

Adapter le type de retour à celui de la fonction existante, sans modifier sa signature publique.

Dans l'écran d'annulation repéré à l'étape 1, avant l'émission de l'event d'annulation :

```dart
  final confirmed = await confirmImportantAction(
    context,
    title: 'Confirmer l\'annulation',
    message: 'Cette annulation est définitive et peut entraîner des frais.',
  );
  if (!confirmed) {
    return;
  }
```

Dans l'écran de suppression de compte repéré à l'étape 1, avant l'émission de l'event de suppression :

```dart
  final confirmed = await confirmImportantAction(
    context,
    title: 'Confirmer la suppression',
    message: 'Votre compte et vos données seront supprimés définitivement.',
  );
  if (!confirmed) {
    return;
  }
```

Ces trois écrans ont déjà leurs propres confirmations métier. Le helper s'ajoute en amont, il ne les remplace pas : sa raison d'être est de rendre l'étape explicite pour qui a activé l'option, pas de réécrire les parcours.

- [ ] **Step 7 : Vérifier la non-régression des parcours touchés**

Run: `flutter test test/features/payments`
Expected: PASS.

Run: `flutter test test/features/cancellation`
Expected: PASS.

Run: `flutter test test/features/settings`
Expected: PASS.

Si un test casse parce qu'un dialogue supplémentaire apparaît, vérifier d'abord que le test monte bien un `AccessibilityScope` avec `confirmImportantActions: false`, valeur par défaut hors scope. Si c'est le cas et que le test casse quand même, le helper est mal placé : le corriger, jamais assouplir le test.

- [ ] **Step 8 : Commit**

```bash
git add lib/core/design/accessibility_scope.dart lib/features/payments lib/features/cancellation lib/features/settings test/features/settings/a11y_confirm_actions_test.dart
git commit -m "feat(a11y): confirmation explicite des actions importantes

Un helper partage intercale une confirmation avant paiement, annulation
et suppression de compte quand l'option est active. Sans l'option, il est
transparent et n'ajoute aucun dialogue."
```

---

### Task 10 : Nettoyage et documentation

**Files:**
- Modify: `lib/features/settings/data/models/user_preferences_model.dart`
- Modify: `dony_app/CLAUDE.md`
- Test: `test/features/settings/bloc/settings_events_props_test.dart` (à ajuster si besoin)

**Interfaces:**
- Consumes: rien.
- Produces: rien.

- [ ] **Step 1 : Vérifier que les champs sont bien morts**

Run: `rg -n "textScale|highContrast|reduceAnimations" lib/ --glob '!lib/features/settings/bloc/**'`
Expected: seules des occurrences dans `user_preferences_model.dart` et des commentaires. Si un consommateur réel apparaît, s'arrêter et le signaler : la suppression serait alors incorrecte.

- [ ] **Step 2 : Retirer les trois champs**

Dans `lib/features/settings/data/models/user_preferences_model.dart`, supprimer les champs `textScale`, `highContrast` et `reduceAnimations`, leurs paramètres de constructeur, leurs entrées dans `copyWith`, dans la lecture depuis le box et dans l'écriture vers le box.

- [ ] **Step 3 : Lancer les tests des préférences**

Run: `flutter test test/features/settings`
Expected: PASS. Si un test référence les champs supprimés, retirer uniquement les assertions portant sur ces trois champs, sans toucher au reste.

- [ ] **Step 4 : Documenter l'event analytics**

Dans `dony_app/CLAUDE.md`, ajouter une ligne au tableau « Events actuellement implémentés » :

```
| `accessibility_setting_changed` | AccessibilityBloc — un reglage d'accessibilite est modifie (proprietes `setting`, `value`) ou reinitialisation complete (`setting: reset`) |
```

- [ ] **Step 5 : Lancer l'analyse complète**

Run: `flutter analyze`
Expected: aucune erreur.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/settings/data/models/user_preferences_model.dart CLAUDE.md test/features/settings
git commit -m "chore(a11y): retire la seconde source de verite et documente l'event

UserPreferencesModel portait les trois cles d'accessibilite sans etre
consomme nulle part, ce qui garantissait une divergence a terme."
```

---

### Task 11 : Non-régression à 200 %

**Files:**
- Create: `test/a11y/large_text_smoke_test.dart`
- Modify: les écrans qui débordent, au cas par cas

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: rien.

C'est la tâche qui révèle la dette existante. Le périmètre est fermé aux cinq parcours listés. Tout débordement constaté ailleurs est consigné dans le message de commit final et renvoyé au lot 2.

- [ ] **Step 1 : Écrire le test de fumée**

Créer `test/a11y/large_text_smoke_test.dart`. Adapter les imports et les constructions d'écran à ceux réellement utilisés dans les tests existants de chaque feature, en les recopiant depuis ces tests plutôt qu'en les inventant :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monte un écran à 200 % de taille de texte et vérifie qu'aucune exception de
/// mise en page n'est levée.
///
/// WCAG 1.4.4 exige que le contenu reste utilisable jusqu'à 200 %. L'écran de
/// réglages expose désormais ce facteur, donc les parcours principaux doivent
/// le supporter.
Future<void> expectNoOverflowAt200(
  WidgetTester tester,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: screen,
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  // Un groupe par parcours. Le corps de chaque test construit l'écran avec les
  // mêmes mocks que le test existant de la feature concernée.
  group('Taille de texte à 200 %', () {
    testWidgets('accueil', (tester) async {
      // Recopier le montage depuis test/features/home/presentation/home_screen_test.dart
    });

    testWidgets('publication de trajet', (tester) async {
      // Recopier le montage depuis le test de l'écran de publication
    });

    testWidgets('création d\'offre', (tester) async {
      // Recopier le montage depuis test/features/matching/.../create_bid_*
    });

    testWidgets('paiement', (tester) async {
      // Recopier le montage depuis test/features/payments/
    });

    testWidgets('scan', (tester) async {
      // Recopier le montage depuis test/features/tracking/presentation/scan_hub_screen_test.dart
    });
  });
}
```

- [ ] **Step 2 : Remplir chaque test depuis le test existant de sa feature**

Pour chacun des cinq écrans, ouvrir le fichier de test existant cité en commentaire, copier son harnais de montage (mocks, providers, données), et appeler `expectNoOverflowAt200(tester, <écran monté>)`.

- [ ] **Step 3 : Lancer le test**

Run: `flutter test test/a11y/large_text_smoke_test.dart`
Expected: des échecs sur un ou plusieurs écrans, sous forme d'exceptions `RenderFlex overflowed`. C'est le résultat recherché.

- [ ] **Step 4 : Corriger les débordements des cinq écrans**

Pour chaque débordement, appliquer le correctif minimal, dans cet ordre de préférence :

1. Remplacer un `Row` rigide par un `Wrap` quand les éléments peuvent passer à la ligne.
2. Envelopper un `Text` contraint dans un `Expanded` ou un `Flexible`.
3. Remplacer une hauteur fixe par une contrainte minimale.
4. Autoriser le retour à la ligne en retirant un `maxLines: 1` non essentiel.

Ne jamais corriger en réduisant la taille du texte ni en tronquant, ce qui viderait le réglage de son sens.

- [ ] **Step 5 : Relancer jusqu'au vert**

Run: `flutter test test/a11y/large_text_smoke_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6 : Lancer la suite complète et la couverture**

Run: `flutter test --coverage`
Expected: PASS, aucun test rouge.

Run: `genhtml coverage/lcov.info -o coverage/html`
Vérifier que la couverture globale est au moins 90 %. Si elle est en dessous, ajouter des tests sur les fichiers créés par ce lot avant de conclure.

- [ ] **Step 7 : Commit**

```bash
git add test/a11y/ lib/
git commit -m "test(a11y): non-regression a 200 % sur les cinq parcours principaux

Corrige les debordements constates sur accueil, publication de trajet,
creation d'offre, paiement et scan. Les debordements constates hors de
ces cinq parcours sont renvoyes au lot 2, comme prevu par la spec."
```

- [ ] **Step 8 : Vérification manuelle sur appareil**

Aucun test automatisé ne remplace un passage à l'œil. Lancer l'application et vérifier, dans l'ordre :

Run: `flutter run --dart-define-from-file=env.dev.json`

1. Régler la taille sur 200 %, parcourir accueil, publication, offre, paiement, scan.
2. Activer le contraste élevé en clair, puis en sombre.
3. Activer la réduction des animations et vérifier que les transitions de page et les apparitions de liste sont bien neutralisées.
4. Activer le texte en gras, le soulignement des liens et les étiquettes renforcées.
5. Tuer et relancer l'application pour vérifier la persistance.
6. Réinitialiser, vérifier le retour aux valeurs d'origine.

Consigner tout écart constaté. Ne pas déclarer la tâche terminée sur la seule foi des tests.

---

## Ordre d'exécution et dépendances

```
Task 1 (état, migration)
Task 2 (scope)             ─┐
Task 3 (thèmes)            ─┼─→ Task 4 (câblage racine, le correctif)
                            │
Task 5 (widgets de ligne)  ─┤
Task 6 (aperçu)            ─┴─→ Task 8 (écran)
Task 7 (composants)        ────→ independante, avant ou apres Task 6

Task 9 (confirmations)  après Task 2
Task 10 (nettoyage)     après Task 1
Task 11 (200 %)         en dernier, après tout le reste
```

Les tâches 1, 2 et 3 sont indépendantes et peuvent être menées en parallèle. La tâche 4 les rassemble et constitue le correctif proprement dit.

## Vérification finale avant de déclarer le lot terminé

- [ ] `flutter analyze` sans erreur.
- [ ] `flutter test` intégralement vert.
- [ ] Couverture au moins 90 %, rapport généré et consulté.
- [ ] Les douze critères d'acceptation de la spec sont vérifiés un par un.
- [ ] La vérification manuelle de la tâche 11 étape 8 est faite, ses écarts consignés.
- [ ] Aucun commit sur `main`.
