import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/core/services/gdpr_helper.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AnalyticsConsentState extends Equatable {
  const AnalyticsConsentState();

  @override
  List<Object?> get props => const [];
}

/// Décision en cours (réconciliation avec le serveur) : l'écran n'affiche
/// rien d'autre qu'un fond, pour ne pas clignoter si la question est inutile.
class AnalyticsConsentResolving extends AnalyticsConsentState {
  const AnalyticsConsentResolving();
}

/// La question doit être posée : zone RGPD, ou pays inconnu, sans réponse.
class AnalyticsConsentAsk extends AnalyticsConsentState {
  const AnalyticsConsentAsk();
}

/// Rien à demander (déjà répondu, hors zone RGPD, mesure non configurée) ou
/// réponse enregistrée : l'écran peut partir vers la suite de l'inscription.
class AnalyticsConsentDone extends AnalyticsConsentState {
  const AnalyticsConsentDone();
}

/// Écran « Une dernière chose », juste après le code de vérification.
///
/// [resolve] reprend la décision de `AnalyticsConsentGate` (même
/// `GdprHelper.resolveConsentAction`) après avoir réconcilié le consentement
/// avec le serveur : un compte qui a déjà répondu (réinstallation, second
/// appareil) n'est jamais redemandé. En zone hors RGPD, le garde accorde le
/// consentement de lui-même : l'écran passe son chemin.
class AnalyticsConsentCubit extends Cubit<AnalyticsConsentState> {
  AnalyticsConsentCubit(
    this._analytics,
    this._consentPrompt, {
    required bool Function() requiresConsent,
  }) : _requiresConsent = requiresConsent,
       super(const AnalyticsConsentResolving());

  final AnalyticsService _analytics;
  final ConsentPrompt _consentPrompt;
  final bool Function() _requiresConsent;

  Future<void> resolve() async {
    try {
      await _analytics.syncFromBackend();
    } catch (_) {
      // Hors ligne : le consentement local fait foi, la décision continue.
    }
    if (isClosed) return;
    final action = GdprHelper.resolveConsentAction(
      isConfigured: _analytics.isConfigured,
      hasAnswered: _analytics.hasAnswered,
      requiresConsent: _requiresConsent(),
    );
    emit(
      action == AnalyticsConsentAction.askConsent
          ? const AnalyticsConsentAsk()
          : const AnalyticsConsentDone(),
    );
  }

  /// Enregistre la réponse (« Accepter » ou « Non merci ») puis laisse
  /// l'écran partir. La demande levée par le garde est retirée : la feuille de
  /// l'accueil ne repose pas la question.
  Future<void> answer({required bool granted}) async {
    try {
      await _analytics.setConsent(granted: granted);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.analyticsConsentAnswered,
          properties: {'granted': granted, 'surface': 'signup_screen'},
        ),
      );
    } finally {
      // Même si l'écriture locale échoue, l'inscription doit continuer.
      _consentPrompt.clear();
      if (!isClosed) emit(const AnalyticsConsentDone());
    }
  }
}
