import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPriceSuggestionRepository extends Mock
    implements PriceSuggestionRepository {}

/// Enregistre `TripPriceSuggestionCubit` (fourni par l'écran de création de
/// trajet) sur un dépôt qui répond [suggestion] — `null` par défaut, comme un
/// back qui ne connaît pas encore la route (404). Sans effet s'il l'est déjà.
MockPriceSuggestionRepository registerTestPriceSuggestionCubit({
  TripPriceSuggestion? suggestion,
}) {
  final repository = MockPriceSuggestionRepository();
  when(
    () => repository.getSuggestions(
      departureCity: any(named: 'departureCity'),
      arrivalCity: any(named: 'arrivalCity'),
      currency: any(named: 'currency'),
    ),
  ).thenAnswer((_) async => suggestion);
  if (!getIt.isRegistered<TripPriceSuggestionCubit>()) {
    getIt.registerFactory<TripPriceSuggestionCubit>(
      () => TripPriceSuggestionCubit(repository, getIt<AnalyticsService>()),
    );
  }
  return repository;
}
