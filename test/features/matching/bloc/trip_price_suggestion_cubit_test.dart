import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements PriceSuggestionRepository {}

void main() {
  late _MockRepository repository;
  late MockAnalyticsBackend backend;
  late TripPriceSuggestionCubit cubit;

  setUp(() {
    repository = _MockRepository();
    backend = MockAnalyticsBackend();
    cubit = TripPriceSuggestionCubit(
      repository,
      makeEnabledAnalytics(backend)..onConfigured(),
    );
  });

  tearDown(() => cubit.close());

  void stub(TripPriceSuggestion? result) {
    when(
      () => repository.getSuggestions(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('load', () {
    test('médiane du back : source backend, pastille possible', () async {
      stub(
        const TripPriceSuggestion(
          currency: 'EUR',
          pricePerKg: 9,
          sampleSize: 12,
          items: [TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 15)],
        ),
      );
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        currency: SupportedCurrency.eur,
      );
      await flush();

      expect(cubit.state.status, TripPriceSuggestionStatus.loaded);
      expect(cubit.state.source, TripPriceSuggestionSource.backend);
      expect(cubit.state.suggestedPricePerKg, 9);
      expect(cubit.state.isMostCommonOnRoute, isTrue);
      expect(cubit.state.items, hasLength(1));
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPriceSuggestionLoaded,
          any(
            that: allOf([
              containsPair('has_kg_price', true),
              containsPair('sample_size_bracket', '10-49'),
              containsPair('items_count', 1),
              containsPair('source', 'backend'),
              containsPair('currency', 'EUR'),
            ]),
          ),
        ),
      ).called(1);
    });

    test('back ancien (null) : repli sur la médiane embarquée', () async {
      stub(null);
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: SupportedCurrency.eur,
      );
      await flush();

      expect(cubit.state.source, TripPriceSuggestionSource.fallback);
      expect(cubit.state.suggestedPricePerKg, 8);
      expect(cubit.state.isMostCommonOnRoute, isFalse);
      expect(cubit.state.items, isEmpty);
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPriceSuggestionLoaded,
          any(
            that: allOf([
              containsPair('has_kg_price', false),
              containsPair('sample_size_bracket', '0'),
              containsPair('source', 'fallback'),
            ]),
          ),
        ),
      ).called(1);
    });

    test('pricePerKg null : repli, mais les articles restent', () async {
      stub(
        const TripPriceSuggestion(
          currency: 'EUR',
          sampleSize: 2,
          items: [TripPriceSuggestionItem(label: 'Ordinateur', unitPrice: 30)],
        ),
      );
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: SupportedCurrency.eur,
      );

      expect(cubit.state.source, TripPriceSuggestionSource.fallback);
      expect(cubit.state.items.single.label, 'Ordinateur');
    });

    test('réponse dans une autre devise : ignorée', () async {
      stub(const TripPriceSuggestion(currency: 'EUR', pricePerKg: 9));
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: SupportedCurrency.xof,
      );

      expect(cubit.state.source, TripPriceSuggestionSource.fallback);
      expect(cubit.state.suggestedPricePerKg, 2000);
    });

    test('médiane hors bornes : ramenée dans le sélecteur', () async {
      stub(const TripPriceSuggestion(currency: 'EUR', pricePerKg: 80));
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: SupportedCurrency.eur,
      );
      expect(cubit.state.suggestedPricePerKg, 25);
    });

    test(
      'même route deux fois : un seul appel ; villes vides : aucun',
      () async {
        stub(null);
        await cubit.load(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          currency: SupportedCurrency.eur,
        );
        await cubit.load(
          departureCity: ' paris ',
          arrivalCity: 'DAKAR',
          currency: SupportedCurrency.eur,
        );
        await cubit.load(
          departureCity: '',
          arrivalCity: 'Dakar',
          currency: SupportedCurrency.eur,
        );
        verify(
          () => repository.getSuggestions(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            currency: any(named: 'currency'),
          ),
        ).called(1);
      },
    );

    test('réponse périmée (route changée entre-temps) : écartée', () async {
      final first = Completer<TripPriceSuggestion?>();
      when(
        () => repository.getSuggestions(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          currency: 'EUR',
        ),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getSuggestions(
          departureCity: 'Paris',
          arrivalCity: 'Abidjan',
          currency: 'EUR',
        ),
      ).thenAnswer(
        (_) async => const TripPriceSuggestion(currency: 'EUR', pricePerKg: 10),
      );

      final pending = cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: SupportedCurrency.eur,
      );
      await cubit.load(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        currency: SupportedCurrency.eur,
      );
      first.complete(const TripPriceSuggestion(currency: 'EUR', pricePerKg: 5));
      await pending;

      expect(cubit.state.suggestedPricePerKg, 10);
    });
  });

  group('gestes sur le prix', () {
    test('priceAdjusted', () async {
      cubit.priceAdjusted(up: true, fromSuggested: true);
      cubit.priceAdjusted(up: false, fromSuggested: false);
      await flush();
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPriceAdjusted,
          any(
            that: allOf([
              containsPair('direction', 'up'),
              containsPair('from_suggested', true),
            ]),
          ),
        ),
      ).called(1);
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPriceAdjusted,
          any(that: containsPair('direction', 'down')),
        ),
      ).called(1);
    });

    test('kgPriceAddedOnEdit / kgPriceRemovedOnEdit', () async {
      cubit
        ..kgPriceAddedOnEdit()
        ..kgPriceRemovedOnEdit();
      await flush();
      verify(
        () => backend.capture(AnalyticsEvents.tripKgPriceAddedOnEdit, any()),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.tripKgPriceRemovedOnEdit, any()),
      ).called(1);
    });

    test('priceResetToSuggested', () async {
      cubit.priceResetToSuggested();
      await flush();
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPriceResetToSuggested,
          any(that: containsPair('source', 'fallback')),
        ),
      ).called(1);
    });

    test('itemPricesOpened : step et card_edit', () async {
      cubit
        ..itemPricesOpened(TripItemPricesSource.step)
        ..itemPricesOpened(TripItemPricesSource.cardEdit);
      await flush();
      verify(
        () => backend.capture(
          AnalyticsEvents.tripItemPricesOpened,
          any(that: containsPair('source', 'step')),
        ),
      ).called(1);
      verify(
        () => backend.capture(
          AnalyticsEvents.tripItemPricesOpened,
          any(that: containsPair('source', 'card_edit')),
        ),
      ).called(1);
    });
  });

  test('sampleSizeBracket', () {
    expect(sampleSizeBracket(0), '0');
    expect(sampleSizeBracket(2), '1-2');
    expect(sampleSizeBracket(3), '3-9');
    expect(sampleSizeBracket(10), '10-49');
    expect(sampleSizeBracket(50), '50+');
  });

  test('état : copyWith', () {
    const state = TripPriceSuggestionState();
    final next = state.copyWith(
      status: TripPriceSuggestionStatus.loading,
      currency: SupportedCurrency.xof,
      suggestion: () => const TripPriceSuggestion(currency: 'XOF'),
    );
    expect(next.status, TripPriceSuggestionStatus.loading);
    expect(next.currency, SupportedCurrency.xof);
    expect(next.suggestion?.currency, 'XOF');
    expect(next.copyWith().suggestion, next.suggestion);
  });
}
