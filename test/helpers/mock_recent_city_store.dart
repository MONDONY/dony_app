import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:mocktail/mocktail.dart';

class MockRecentCityStore extends Mock implements RecentCityStore {}

/// `registerFallbackValue` pour `CityFieldRole`/`CityModel` — requis une
/// seule fois par fichier de test (`setUpAll`) avant tout `any()` portant sur
/// ces types.
void registerCityFallbackValues() {
  registerFallbackValue(CityFieldRole.departure);
  registerFallbackValue(
    const CityModel(name: '', countryCode: '', countryName: '', lat: 0, lng: 0),
  );
}

/// Enregistre un `RecentCityStore` factice (aucun historique, `add` no-op)
/// dans GetIt — tout écran affichant un `CityAutocompleteField` avec
/// `recentRole` non nul en a besoin pour se construire en test.
MockRecentCityStore registerFakeRecentCityStore() {
  if (getIt.isRegistered<RecentCityStore>()) {
    getIt.unregister<RecentCityStore>();
  }
  final store = MockRecentCityStore();
  when(() => store.read(any())).thenReturn(const <CityModel>[]);
  when(() => store.add(any(), any())).thenAnswer((_) async {});
  getIt.registerLazySingleton<RecentCityStore>(() => store);
  return store;
}

void unregisterFakeRecentCityStore() {
  if (getIt.isRegistered<RecentCityStore>()) {
    getIt.unregister<RecentCityStore>();
  }
}
