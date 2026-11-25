import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/bloc/trip_published_item_prices_cubit.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements PriceSuggestionRepository {}

class _Exception extends AppException {
  const _Exception() : super('nope', code: 'price-grid/duplicate');
}

const _route = TripPriceSuggestion(
  currency: 'EUR',
  pricePerKg: 8,
  sampleSize: 12,
  items: [
    TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 15),
    TripPriceSuggestionItem(label: 'Ordinateur', unitPrice: 30),
    TripPriceSuggestionItem(label: 'Documents', unitPrice: 10),
    TripPriceSuggestionItem(label: 'Tablette', unitPrice: 20),
    TripPriceSuggestionItem(label: 'Montre', unitPrice: 12),
  ],
);

void main() {
  late _MockRepository repository;
  late MockAnalyticsBackend backend;
  late TripPublishedItemPricesCubit cubit;

  setUp(() {
    repository = _MockRepository();
    backend = MockAnalyticsBackend();
    cubit = TripPublishedItemPricesCubit(
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

  Future<void> start({
    List<GridPreviewItem> published = const [],
    TripPriceSuggestionState? routeSuggestion,
    SupportedCurrency currency = SupportedCurrency.eur,
  }) => cubit.start(
    publishedItems: published,
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    currency: currency,
    routeSuggestion: routeSuggestion,
  );

  void verifyShown(String variant, int count) => verify(
    () => backend.capture(
      AnalyticsEvents.tripPublishedItemPricesShown,
      any(
        that: allOf([
          containsPair('variant', variant),
          containsPair('suggestions_count', count),
        ]),
      ),
    ),
  ).called(1);

  test(
    'trajet publié avec des prix par article : filled, rien de lu',
    () async {
      await start(
        published: const [
          GridPreviewItem(id: 'a', label: 'Téléphone', unitPriceDisplay: 17),
        ],
      );
      expect(cubit.state.status, PublishedItemPricesStatus.filled);
      expect(cubit.state.items, hasLength(1));
      verifyNever(
        () => repository.getSuggestions(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          currency: any(named: 'currency'),
        ),
      );
      verifyShown('filled', 0);
    },
  );

  test(
    'grille vide + prix de la route rechargés : proposal, 4 au plus',
    () async {
      stub(_route);
      await start();
      // La grille n'est pas encore lue : rien d'affiché.
      expect(cubit.state.status, PublishedItemPricesStatus.checking);
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
      expect(cubit.state.suggestions, hasLength(4));
      expect(
        cubit.state.suggestions.first,
        const PriceGridSuggestion(label: 'Téléphone', unitPriceNet: 15),
      );
      verifyShown('proposal', 4);
    },
  );

  test('grille lue avant les prix de la route : même résultat', () async {
    stub(_route);
    cubit.gridLoaded(0);
    expect(cubit.state.status, PublishedItemPricesStatus.checking);
    await start();
    expect(cubit.state.status, PublishedItemPricesStatus.proposal);
  });

  test('prix déjà chargés par l\'étape prix : pas de nouvel appel', () async {
    await start(
      routeSuggestion: const TripPriceSuggestionState(
        status: TripPriceSuggestionStatus.loaded,
        suggestion: _route,
      ),
    );
    cubit.gridLoaded(0);
    expect(cubit.state.status, PublishedItemPricesStatus.proposal);
    verifyNever(
      () => repository.getSuggestions(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        currency: any(named: 'currency'),
      ),
    );
  });

  test('prix de l\'étape dans une autre devise : rechargés', () async {
    stub(null);
    await start(
      routeSuggestion: const TripPriceSuggestionState(
        status: TripPriceSuggestionStatus.loaded,
        currency: SupportedCurrency.xof,
        suggestion: _route,
      ),
    );
    cubit.gridLoaded(0);
    expect(cubit.state.status, PublishedItemPricesStatus.empty);
    verifyShown('none', 0);
  });

  test(
    'trajet dans une autre devise que la grille : aucune proposition',
    () async {
      stub(
        const TripPriceSuggestion(
          currency: 'XOF',
          items: [TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 9000)],
        ),
      );
      await start(currency: SupportedCurrency.xof);
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.empty);
    },
  );

  test('grille déjà remplie mais trajet sans prix : carte masquée', () async {
    stub(_route);
    await start();
    cubit.gridLoaded(3);
    expect(cubit.state.status, PublishedItemPricesStatus.hidden);
    verifyNever(
      () =>
          backend.capture(AnalyticsEvents.tripPublishedItemPricesShown, any()),
    );
  });

  test('grille illisible : carte masquée', () async {
    stub(_route);
    await start();
    cubit.gridFailed(const _Exception());
    expect(cubit.state.status, PublishedItemPricesStatus.hidden);
    // Une lecture tardive ne la fait pas réapparaître.
    cubit.gridLoaded(0);
    expect(cubit.state.status, PublishedItemPricesStatus.hidden);
  });

  group('ajout', () {
    setUp(() async {
      stub(_route);
      await start();
      cubit.gridLoaded(0);
    });

    test('Ajouter puis grille relue : added + count', () {
      final toAdd = cubit.addRequested();
      expect(toAdd, hasLength(4));
      expect(cubit.state.status, PublishedItemPricesStatus.adding);
      // Pas de second envoi pendant l'ajout.
      expect(cubit.addRequested(), isNull);
      cubit.gridLoaded(4);
      expect(cubit.state.status, PublishedItemPricesStatus.added);
      expect(cubit.state.addedCount, 4);
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPublishedItemPricesAdded,
          any(that: containsPair('count', 4)),
        ),
      ).called(1);
    });

    test('échec : proposition gardée, message, événement d\'échec', () {
      cubit.addRequested();
      cubit.gridFailed(const _Exception());
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
      expect(cubit.state.addFailed, isTrue);
      // La grille d'avant, rétablie par le bloc, ne vaut pas succès.
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPublishedItemPricesAddFailed,
          any(that: containsPair('error_code', 'price-grid/duplicate')),
        ),
      ).called(1);
    });

    test('échec sans code : error_code unknown', () {
      cubit.addRequested();
      cubit.gridFailed(StateError('x'));
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPublishedItemPricesAddFailed,
          any(that: containsPair('error_code', 'unknown')),
        ),
      ).called(1);
    });

    test('Modifier : prix préremplis, puis grille remplie au retour', () {
      final extra = cubit.editOpened();
      expect(extra, hasLength(4));
      verify(
        () => backend.capture(
          AnalyticsEvents.tripPublishedItemPricesEditOpened,
          any(),
        ),
      ).called(1);
      cubit.gridLoaded(2);
      expect(cubit.state.status, PublishedItemPricesStatus.added);
      expect(cubit.state.addedCount, 2);
      verifyNever(
        () => backend.capture(
          AnalyticsEvents.tripPublishedItemPricesAdded,
          any(),
        ),
      );
    });

    test('Modifier puis retour sans rien enregistrer : proposition', () {
      cubit.editOpened();
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
    });

    test('Modifier puis relecture en échec : état gardé', () {
      cubit.editOpened();
      cubit.gridFailed(const _Exception());
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
      cubit.gridLoaded(3);
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
    });

    test('Voir mes prix après l\'ajout puis grille vidée : proposition', () {
      cubit.addRequested();
      cubit.gridLoaded(4);
      expect(cubit.editOpened(), isEmpty);
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.proposal);
      expect(cubit.state.addedCount, 0);
    });
  });

  test(
    'sans prix de route, Ajouter mes prix puis retour vide : empty',
    () async {
      stub(null);
      await start();
      cubit.gridLoaded(0);
      expect(cubit.addRequested(), isNull);
      expect(cubit.editOpened(), isEmpty);
      cubit.gridLoaded(0);
      expect(cubit.state.status, PublishedItemPricesStatus.empty);
    },
  );

  test('fermé pendant le chargement : aucun état émis', () async {
    stub(_route);
    final pending = start();
    await cubit.close();
    await pending;
    expect(cubit.state.status, PublishedItemPricesStatus.checking);
  });

  test('state : copyWith et égalité', () {
    const a = TripPublishedItemPricesState();
    expect(a.copyWith(), a);
    expect(a.copyWith(addFailed: true), isNot(a));
  });
}
