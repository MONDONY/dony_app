import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

/// Issue d'un enregistrement dans la galerie.
enum GallerySaveOutcome {
  saved,

  /// Accès aux photos refusé. Sur iOS, après un premier refus, le système ne
  /// redemande plus : seul le renvoi aux Réglages débloque l'utilisateur.
  accessDenied,

  notEnoughSpace,

  /// Toute autre erreur (format, plugin, inattendue).
  failed;

  bool get isSaved => this == GallerySaveOutcome.saved;
}

/// Enregistrement d'une image dans la galerie du téléphone, commun aux
/// affiches (trajet, demande d'envoi) et au QR code du colis
/// (YADONY-FLUTTER-PROD-T).
///
/// Avant lui, chaque écran appelait `Gal` directement, avalait l'exception
/// et montrait un message générique : un utilisateur iOS qui avait refusé
/// l'accès aux photos voyait « Impossible d'enregistrer » sans savoir quoi
/// faire, et rien n'arrivait dans Sentry. Le service distingue les causes,
/// les journalise ([AppLog]) et émet [AnalyticsEvents.gallerySaveFailed]
/// avec un `error_code` ; [notifyFailure] affiche le message adapté, avec
/// « Ouvrir les Réglages » quand l'accès est refusé.
///
/// Les dépendances natives sont injectables pour les tests.
class GallerySaveService {
  const GallerySaveService({
    Future<bool> Function()? requestAccess,
    Future<void> Function(Uint8List bytes, String name)? putImageBytes,
    Future<void> Function()? openSettings,
    AnalyticsService? Function()? analytics,
  }) : _requestAccess = requestAccess,
       _putImageBytes = putImageBytes,
       _openSettings = openSettings,
       _analytics = analytics;

  /// Instance enregistrée dans GetIt, ou une instance par défaut (tests de
  /// widget sans graphe d'injection).
  static GallerySaveService resolve() =>
      getItSafe<GallerySaveService>() ?? const GallerySaveService();

  final Future<bool> Function()? _requestAccess;
  final Future<void> Function(Uint8List bytes, String name)? _putImageBytes;
  final Future<void> Function()? _openSettings;
  final AnalyticsService? Function()? _analytics;

  /// Demande l'accès puis écrit [bytes] sous [name]. Ne lève jamais.
  ///
  /// [context] identifie l'appelant dans l'analytics et les logs
  /// (`trip_poster`, `trip_poster_group`, `package_request_poster`,
  /// `bid_qr`).
  Future<GallerySaveOutcome> save(
    Uint8List bytes, {
    required String name,
    required String context,
  }) async {
    var stage = 'request_access';
    try {
      // gal n'appelle jamais requestAccess() lui-même avant d'écrire : sans
      // cette demande, WRITE_EXTERNAL_STORAGE (maxSdkVersion=28) n'est
      // accordée nulle part sur Android 7 à 9. Sans effet si l'accès est
      // déjà accordé.
      final granted = await (_requestAccess ?? Gal.requestAccess)();
      if (!granted) {
        _report(
          context,
          stage: stage,
          code: 'access_denied',
          outcome: GallerySaveOutcome.accessDenied,
        );
        return GallerySaveOutcome.accessDenied;
      }
      stage = 'write';
      await (_putImageBytes ?? _galPut)(bytes, name);
      return GallerySaveOutcome.saved;
    } on GalException catch (e, st) {
      final outcome = switch (e.type) {
        GalExceptionType.accessDenied => GallerySaveOutcome.accessDenied,
        GalExceptionType.notEnoughSpace => GallerySaveOutcome.notEnoughSpace,
        _ => GallerySaveOutcome.failed,
      };
      _report(
        context,
        stage: stage,
        code: _galCode(e.type),
        outcome: outcome,
        error: e,
        stackTrace: st,
      );
      return outcome;
    } on Object catch (e, st) {
      _report(
        context,
        stage: stage,
        code: 'unknown',
        outcome: GallerySaveOutcome.failed,
        error: e,
        stackTrace: st,
      );
      return GallerySaveOutcome.failed;
    }
  }

  /// Message d'échec adapté à [outcome] ; [fallback] pour une erreur sans
  /// cause exploitable. Ne fait rien pour [GallerySaveOutcome.saved].
  void notifyFailure(
    BuildContext context,
    GallerySaveOutcome outcome, {
    required String fallback,
  }) {
    if (!context.mounted) return;
    final l = context.l10n;
    switch (outcome) {
      case GallerySaveOutcome.saved:
        return;
      case GallerySaveOutcome.accessDenied:
        DonySnackbar.show(
          context,
          message: l.gallerySaveAccessDenied,
          type: DonySnackbarType.error,
          duration: const Duration(seconds: 6),
          actionLabel: l.gallerySaveOpenSettings,
          onAction: () => unawaited(openSettings()),
        );
      case GallerySaveOutcome.notEnoughSpace:
        DonySnackbar.show(
          context,
          message: l.gallerySaveNotEnoughSpace,
          type: DonySnackbarType.error,
        );
      case GallerySaveOutcome.failed:
        DonySnackbar.show(
          context,
          message: fallback,
          type: DonySnackbarType.error,
        );
    }
  }

  /// Ouvre les réglages de Yadony. Ne lève jamais.
  Future<void> openSettings() async {
    try {
      await (_openSettings ?? AppSettings.openAppSettings)();
    } on Object catch (e) {
      AppLog.warn(
        'gallery_save: open settings failed',
        data: {'error': e.runtimeType.toString()},
      );
    }
  }

  static Future<void> _galPut(Uint8List bytes, String name) =>
      Gal.putImageBytes(bytes, name: name);

  static String _galCode(GalExceptionType type) => switch (type) {
    GalExceptionType.accessDenied => 'access_denied',
    GalExceptionType.notEnoughSpace => 'not_enough_space',
    GalExceptionType.notSupportedFormat => 'not_supported_format',
    GalExceptionType.unexpected => 'unexpected',
  };

  void _report(
    String context, {
    required String stage,
    required String code,
    required GallerySaveOutcome outcome,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final data = <String, Object>{
      'context': context,
      'stage': stage,
      'error_code': code,
    };
    // Accès refusé ou stockage plein : un choix ou un état du téléphone, pas
    // un bug. Le reste remonte comme une issue Sentry.
    if (outcome == GallerySaveOutcome.failed) {
      AppLog.error(
        'gallery_save failed',
        error: error,
        stackTrace: stackTrace,
        data: data,
      );
    } else {
      AppLog.warn('gallery_save refused', data: data);
    }
    final analytics = (_analytics ?? getItSafe<AnalyticsService>)();
    unawaited(
      analytics?.logEvent(AnalyticsEvents.gallerySaveFailed, properties: data),
    );
  }
}
