import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/calls/data/call_lock_screen_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallLockScreenState {
  const CallLockScreenState({
    this.loaded = false,
    this.supported = false,
    this.blocker,
  });

  final bool loaded;

  /// Faux hors Android : la ligne des réglages n'a rien à montrer.
  final bool supported;
  final LockScreenCallBlocker? blocker;

  bool get blocked => blocker != null && blocker != LockScreenCallBlocker.none;
}

/// Appels Yadony sur l'écran verrouillé (FLUTTER-92) : repère le réglage
/// système qui les masque et y conduit l'utilisateur, une fois depuis une
/// conversation, puis à la demande depuis Réglages › Notifications.
class CallLockScreenCubit extends Cubit<CallLockScreenState> {
  CallLockScreenCubit(this._service, this._hive, this._analytics)
    : super(const CallLockScreenState());

  final CallLockScreenService _service;
  final HiveService _hive;
  final AnalyticsService _analytics;

  Future<void> load() async {
    final blocker = await _service.blocker();
    if (isClosed) return;
    emit(
      CallLockScreenState(
        loaded: true,
        supported: _service.isSupported,
        blocker: blocker,
      ),
    );
  }

  /// Vrai la première fois seulement qu'un réglage bloque les appels : la
  /// feuille d'explication n'est montrée qu'une fois par installation.
  Future<bool> shouldPrompt() async {
    await load();
    if (!state.blocked) return false;
    return _hive.userPrefs.get(
          HiveService.kCallLockScreenPromptShown,
          defaultValue: false,
        ) !=
        true;
  }

  void markPromptShown() {
    unawaited(
      _hive.userPrefs.put(HiveService.kCallLockScreenPromptShown, true),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.callLockScreenPromptShown,
        properties: {'kind': _kind},
      ),
    );
  }

  /// [source] : `prompt` (feuille d'une conversation) ou `settings`.
  Future<void> openSettings({required String source}) async {
    final blocker = state.blocker;
    if (blocker == null || blocker == LockScreenCallBlocker.none) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.callLockScreenSettingsOpened,
        properties: {'kind': _kind, 'source': source},
      ),
    );
    await _service.openSettings(blocker);
  }

  String get _kind => switch (state.blocker) {
    LockScreenCallBlocker.fullScreenIntent => 'full_screen_intent',
    LockScreenCallBlocker.manufacturer => 'manufacturer',
    _ => 'none',
  };
}
