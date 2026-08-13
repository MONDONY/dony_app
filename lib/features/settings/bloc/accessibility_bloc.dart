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
  AccessibilityBloc(this._box, this._analytics) : super(_load(_box)) {
    on<FollowSystemTextScaleToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(followSystemTextScale: e.value),
        HiveService.kA11yFollowSystemTextScale,
        e.value,
        'follow_system_text_scale',
      ),
    );

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

    on<HighContrastModeChanged>(
      (e, emit) => _apply(
        emit,
        state.copyWith(highContrast: e.value),
        HiveService.kA11yHighContrast,
        e.value,
        'high_contrast',
      ),
    );

    on<ReduceMotionModeChanged>(
      (e, emit) => _apply(
        emit,
        state.copyWith(reduceMotion: e.value),
        HiveService.kA11yReduceMotion,
        e.value,
        'reduce_motion',
      ),
    );

    on<BoldTextToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(boldText: e.value),
        HiveService.kA11yBoldText,
        e.value,
        'bold_text',
      ),
    );

    on<UnderlineLinksToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(underlineLinks: e.value),
        HiveService.kA11yUnderlineLinks,
        e.value,
        'underline_links',
      ),
    );

    on<ReinforceLabelsToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(reinforceLabels: e.value),
        HiveService.kA11yReinforceLabels,
        e.value,
        'reinforce_labels',
      ),
    );

    on<PersistentMessagesToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(persistentMessages: e.value),
        HiveService.kA11yPersistentMessages,
        e.value,
        'persistent_messages',
      ),
    );

    on<ConfirmImportantActionsToggled>(
      (e, emit) => _apply(
        emit,
        state.copyWith(confirmImportantActions: e.value),
        HiveService.kA11yConfirmImportant,
        e.value,
        'confirm_important_actions',
      ),
    );

    on<AccessibilityResetRequested>((e, emit) {
      const fresh = AccessibilityState();
      _persistAll(_box, fresh);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.accessibilitySettingChanged,
          properties: const {'setting': 'reset', 'value': 'all'},
        ),
      );
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
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.accessibilitySettingChanged,
        properties: {'setting': settingName, 'value': '$value'},
      ),
    );
    emit(next);
  }

  /// Lit l'état depuis Hive, en migrant d'abord l'ancien format si présent.
  ///
  /// Les valeurs migrées sont utilisées directement depuis le résultat de
  /// [_migrateLegacy], jamais relues via `box.get` juste après le `box.put`
  /// qui vient de les écrire : un `Box` réel garantit ce round-trip, mais
  /// rien ne l'exige côté contrat, et s'en passer est à la fois plus sûr et
  /// plus direct.
  static AccessibilityState _load(Box box) {
    final legacy = _migrateLegacy(box);
    String mode(String key, String? migrated) {
      if (migrated != null) return migrated;
      final raw = box.get(key, defaultValue: AccessibilityMode.system);
      return AccessibilityMode.isValid(raw as String?)
          ? raw as String
          : AccessibilityMode.system;
    }

    return AccessibilityState(
      followSystemTextScale:
          legacy.followSystemTextScale ??
          box.get(HiveService.kA11yFollowSystemTextScale, defaultValue: true)
              as bool,
      textScaleFactor:
          (legacy.textScaleFactor ??
                  (box.get(HiveService.kA11yTextScaleFactor, defaultValue: 1.0)
                          as num)
                      .toDouble())
              .clamp(kA11yMinTextScale, kA11yMaxTextScale),
      highContrast: mode(HiveService.kA11yHighContrast, legacy.highContrast),
      reduceMotion: mode(HiveService.kA11yReduceMotion, legacy.reduceMotion),
      boldText: box.get(HiveService.kA11yBoldText, defaultValue: false) as bool,
      underlineLinks:
          box.get(HiveService.kA11yUnderlineLinks, defaultValue: false) as bool,
      reinforceLabels:
          box.get(HiveService.kA11yReinforceLabels, defaultValue: false)
              as bool,
      persistentMessages:
          box.get(HiveService.kA11yPersistentMessages, defaultValue: false)
              as bool,
      confirmImportantActions:
          box.get(HiveService.kA11yConfirmImportant, defaultValue: false)
              as bool,
    );
  }

  /// Convertit les trois clés de l'ancien écran vers le nouveau format, les
  /// écrit dans le box puis les supprime. Retourne les valeurs migrées pour
  /// que [_load] les consomme directement (champs `null` = rien à migrer).
  ///
  /// `'normal'` et `false` étaient les valeurs par défaut : ils traduisent une
  /// absence de choix, donc ils deviennent « suivre le système » et non un
  /// réglage forcé.
  static _LegacyMigration _migrateLegacy(Box box) {
    final legacyScale = box.get(HiveService.kTextScale) as String?;
    final legacyContrast = box.get(HiveService.kHighContrast) as bool?;
    final legacyReduce = box.get(HiveService.kReduceAnimations) as bool?;

    bool? follow;
    double? factor;
    String? highContrast;
    String? reduceMotion;

    if (legacyScale != null) {
      final (f, fa) = switch (legacyScale) {
        'small' => (false, 0.85),
        'large' => (false, 1.3),
        'xlarge' => (false, 1.6),
        _ => (true, 1.0),
      };
      follow = f;
      factor = fa.toDouble();
      box.put(HiveService.kA11yFollowSystemTextScale, follow);
      box.put(HiveService.kA11yTextScaleFactor, factor);
      box.delete(HiveService.kTextScale);
    }

    if (legacyContrast != null) {
      highContrast = legacyContrast
          ? AccessibilityMode.on
          : AccessibilityMode.system;
      box.put(HiveService.kA11yHighContrast, highContrast);
      box.delete(HiveService.kHighContrast);
    }

    if (legacyReduce != null) {
      reduceMotion = legacyReduce
          ? AccessibilityMode.on
          : AccessibilityMode.system;
      box.put(HiveService.kA11yReduceMotion, reduceMotion);
      box.delete(HiveService.kReduceAnimations);
    }

    return _LegacyMigration(
      followSystemTextScale: follow,
      textScaleFactor: factor,
      highContrast: highContrast,
      reduceMotion: reduceMotion,
    );
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

/// Résultat intermédiaire de [AccessibilityBloc._migrateLegacy] : uniquement
/// les champs concernés par une clé héritée présente. `null` = rien à migrer
/// pour ce champ, [AccessibilityBloc._load] retombe alors sur le box.
class _LegacyMigration {
  const _LegacyMigration({
    this.followSystemTextScale,
    this.textScaleFactor,
    this.highContrast,
    this.reduceMotion,
  });

  final bool? followSystemTextScale;
  final double? textScaleFactor;
  final String? highContrast;
  final String? reduceMotion;
}
