import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

/// Doublures partagées par tous les tests qui touchent à la devise.
///
/// Elles vivent ici plutôt que recopiées dans chaque fichier : le piège
/// `whenListen` documenté dans [stubBusinessPrefsBloc] n'a de valeur que
/// corrigé à un seul endroit.

class MockBusinessPrefsBloc
    extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

class _MockHiveService extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

/// Prépare un [BusinessPrefsBloc] mocké.
///
/// `stream` est stubé à la main plutôt que via `whenListen` : ce dernier
/// enveloppe la source dans un `asBroadcastStream()` qui la consomme dès
/// l'appel (donc avant le tap), laissant un flux clos aux abonnés tardifs.
/// Reconstruire un flux frais à chaque accès, en recopiant l'état **courant**,
/// évite aussi qu'un `BlocBuilder` de l'écran testé n'écrase un état stubé
/// spécifiquement par un test (bannière d'erreur, par exemple).
MockBusinessPrefsBloc stubBusinessPrefsBloc({
  BusinessPrefsState state = const BusinessPrefsState(),
}) {
  final bloc = MockBusinessPrefsBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.stream).thenAnswer((_) => Stream.value(bloc.state));
  return bloc;
}

/// Enregistre un [HiveService] dont le cache renvoie [currencyCode] comme
/// devise active, et le désenregistre en fin de test.
///
/// [currencyCode] est volontairement typé `Object?` : les tests vérifient
/// aussi le comportement face à une valeur en cache d'un type inattendu.
void registerCurrencyPreference(Object? currencyCode) {
  final hive = _MockHiveService();
  final prefs = _MockBox();
  when(() => hive.userPrefs).thenReturn(prefs);
  when(
    () => prefs.get(HiveService.kCurrencyCode, defaultValue: null),
  ).thenReturn(currencyCode);
  getIt.registerSingleton<HiveService>(hive);
  addTearDown(() => getIt.unregister<HiveService>());
}
