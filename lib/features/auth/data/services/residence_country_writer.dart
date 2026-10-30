import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
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
  final current = await repository.fetchPrefs();
  final saved = await repository.updatePrefs(
    current.copyWith(country: countryCode),
  );
  await prefs.put(HiveService.kCountryCode, countryCode);
  await prefs.put(HiveService.kCurrencyCode, saved.currencyCode);
  await prefs.put(HiveService.kTravelerCountryUnsupported, false);
}
