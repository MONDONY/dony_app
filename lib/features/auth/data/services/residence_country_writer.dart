import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Enregistre le pays de résidence choisi pendant l'inscription, dans l'ordre
/// strict serveur puis Hive.
///
/// Le serveur est la source de vérité de la devise dérivée et des paiements :
/// rien n'est écrit en local tant qu'il n'a pas accepté le pays. Une erreur
/// du serveur remonte telle quelle à l'appelant, Hive reste intact.
///
/// [HiveService.kCurrencyCode] reçoit la devise **renvoyée par le serveur**,
/// jamais `CountryCatalog.byCode(...).currency` : la table locale n'est qu'un
/// miroir d'affichage. Sans ce cache, `ActiveCurrency.current` rend `null` et
/// les prix retombent sur les plafonds EUR.
///
/// Partagé par `CountryOnboardingCubit.select` et `ProfileBasicsCubit.submit`.
Future<void> writeResidenceCountry(
  BusinessPrefsRepository repository,
  Box<dynamic> prefs,
  String countryCode,
) async {
  // Le PUT remplace toutes les préférences : la lecture préalable sert à ne
  // rien écraser, elle ne peut donc pas être sautée. Chaque appel réseau est
  // en revanche réessayé sur une panne transitoire (réseau instable, 5xx).
  final current = await _withRetry('fetch', repository.fetchPrefs);
  final saved = await _withRetry(
    'update',
    () => repository.updatePrefs(current.copyWith(country: countryCode)),
  );
  await prefs.put(HiveService.kCountryCode, countryCode);
  await prefs.put(HiveService.kCurrencyCode, saved.currencyCode);
  await prefs.put(HiveService.kTravelerCountryUnsupported, false);
}

/// Nombre total de tentatives d'un appel réseau (une première + deux reprises).
const int _maxAttempts = 3;

/// Délai entre deux tentatives ; remis à zéro dans les tests.
@visibleForTesting
Duration residenceRetryDelay = const Duration(milliseconds: 600);

/// Seules les pannes transitoires méritent une reprise : un refus métier
/// (422, 401, 403, 404, 409) rendrait le même verdict.
bool _isTransient(Object error) => switch (_unwrap(error)) {
  NetworkException() ||
  TimeoutException() ||
  OfflineException() ||
  ServerException() ||
  RateLimitException() => true,
  _ => false,
};

/// L'intercepteur Dio range l'`AppException` typée dans `DioException.error`.
Object _unwrap(Object error) =>
    error is DioException && error.error is AppException ? error.error! : error;

Future<T> _withRetry<T>(String step, Future<T> Function() call) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } catch (error) {
      final willRetry = attempt < _maxAttempts && _isTransient(error);
      // Aucune donnée personnelle : l'étape, le rang de la tentative, le type
      // d'erreur. Jamais le pays, ni le message de l'exception.
      AppLog.warn(
        'residence_country_write_failed',
        data: {
          'step': step,
          'attempt': attempt,
          'error_type': _unwrap(error).runtimeType.toString(),
          'will_retry': willRetry,
        },
      );
      if (!willRetry) rethrow;
      await Future<void>.delayed(residenceRetryDelay * attempt);
    }
  }
}
