import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_published_item_prices_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:dony/features/matching/presentation/widgets/trip_published/trip_published_item_prices_card.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockSuggestions extends Mock implements PriceSuggestionRepository {}

class _MockGrid extends Mock implements PriceGridRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _GridException extends AppException {
  const _GridException() : super('nope', code: 'price-grid/duplicate');
}

const _route = TripPriceSuggestion(
  currency: 'EUR',
  pricePerKg: 8,
  sampleSize: 12,
  items: [
    TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 15),
    TripPriceSuggestionItem(label: 'Ordinateur', unitPrice: 30),
    TripPriceSuggestionItem(label: 'Documents', unitPrice: 10),
  ],
);

AnnouncementModel _trip({List<AnnouncementGridItemModel> grid = const []}) =>
    AnnouncementModel(
      id: 'a1',
      travelerId: 't1',
      departureCity: 'Paris',
      arrivalCity: 'Abidjan',
      departureDate: DateTime(2026, 12, 20),
      availableKg: 23,
      totalKg: 23,
      pricePerKg: 8,
      status: 'ACTIVE',
      pricingMode: grid.isEmpty ? 'KG' : 'MIXED',
      priceGridItems: grid,
      createdAt: DateTime(2026, 11),
      updatedAt: DateTime(2026, 11),
    );

PriceGridItemModel _item(int i) => PriceGridItemModel(
  id: 'g$i',
  label: 'Article $i',
  unitPriceNet: 10,
  unitPriceDisplay: 11,
  position: i,
);

/// Vraies polices de l'app : avec la police de repli des tests, chaque
/// glyphe fait un cadratin et la mesure des libellés serait fausse.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late _MockSuggestions suggestions;
  late _MockGrid grid;
  late _MockAnalytics analytics;
  late List<PriceGridItemModel> gridItems;
  late List<Object?> editorExtras;

  setUpAll(() {
    registerFallbackValue(<String, Object>{});
  });

  setUp(() {
    suggestions = _MockSuggestions();
    grid = _MockGrid();
    analytics = _MockAnalytics();
    gridItems = [];
    editorExtras = [];
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    when(
      () => suggestions.getSuggestions(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => _route);
    when(() => grid.getItems()).thenAnswer((_) async => List.of(gridItems));
    when(
      () => grid.addItem(
        label: any(named: 'label'),
        unitPriceNet: any(named: 'unitPriceNet'),
      ),
    ).thenAnswer((inv) async {
      final item = PriceGridItemModel(
        id: 'g${gridItems.length}',
        label: inv.namedArguments[#label] as String,
        unitPriceNet: inv.namedArguments[#unitPriceNet] as double,
        unitPriceDisplay: 0,
        position: gridItems.length,
      );
      gridItems.add(item);
      return item;
    });
    getIt.registerFactory<TripPublishedItemPricesCubit>(
      () => TripPublishedItemPricesCubit(suggestions, analytics),
    );
    getIt.registerFactory<PriceGridBloc>(() => PriceGridBloc(grid, analytics));
  });

  tearDown(getIt.reset);

  GoRouter router(Widget home) => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/profile/price-grid',
        builder: (_, state) {
          editorExtras.add(state.extra);
          return const Scaffold(body: Text('editor'));
        },
      ),
    ],
  );

  Future<GoRouter> pumpCard(
    WidgetTester tester, {
    AnnouncementModel? trip,
    Locale locale = AppL10n.fr,
  }) async {
    final r = router(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: TripPublishedItemPricesCard(announcement: trip ?? _trip()),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: r,
      ),
    );
    await tester.pumpAndSettle();
    return r;
  }

  testWidgets('grille vide : proposition des prix de la route', (tester) async {
    await pumpCard(tester);
    expect(
      find.text("Vous n'avez pas mis de prix par article"),
      findsOneWidget,
    );
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Ordinateur'), findsOneWidget);
    expect(
      find.text('Ils vaudront pour vos prochains trajets, pas pour celui-ci.'),
      findsOneWidget,
    );
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tripPublishedItemPricesShown,
        properties: {'variant': 'proposal', 'suggestions_count': 3},
      ),
    ).called(1);
  });

  testWidgets('Ajouter : prix envoyés à la grille, carte « ajoutés »', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.tap(find.byKey(const Key('published-item-prices-add')));
    await tester.pumpAndSettle();
    verify(() => grid.addItem(label: 'Téléphone', unitPriceNet: 15)).called(1);
    expect(
      find.byKey(const Key('published-item-prices-added')),
      findsOneWidget,
    );
    expect(
      find.text('Prix ajoutés pour vos prochains trajets'),
      findsOneWidget,
    );
    expect(
      find.text(
        '3 prix par article dans votre profil. '
        'Ce trajet garde son prix au kilo.',
      ),
      findsOneWidget,
    );
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tripPublishedItemPricesAdded,
        properties: {'count': 3},
      ),
    ).called(1);
    // L'ajout passe par le bloc de la grille : ses événements partent aussi.
    verify(
      () => analytics.logEvent(AnalyticsEvents.priceGridCreated),
    ).called(1);
  });

  testWidgets('Ajouter en échec : message et proposition gardée', (
    tester,
  ) async {
    when(
      () => grid.addItem(
        label: any(named: 'label'),
        unitPriceNet: any(named: 'unitPriceNet'),
      ),
    ).thenThrow(const _GridException());
    await pumpCard(tester);
    await tester.tap(find.byKey(const Key('published-item-prices-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('published-item-prices-add-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('published-item-prices-proposal')),
      findsOneWidget,
    );
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tripPublishedItemPricesAddFailed,
        properties: {'error_code': 'price-grid/duplicate'},
      ),
    ).called(1);
  });

  testWidgets('Modifier : éditeur prérempli, grille relue au retour', (
    tester,
  ) async {
    final r = await pumpCard(tester);
    await tester.tap(find.byKey(const Key('published-item-prices-edit')));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    expect(editorExtras.single, isA<List<PriceGridSuggestion>>());
    expect(editorExtras.single! as List<PriceGridSuggestion>, hasLength(3));
    verify(
      () =>
          analytics.logEvent(AnalyticsEvents.tripPublishedItemPricesEditOpened),
    ).called(1);

    // Deux prix enregistrés dans l'éditeur, puis retour.
    gridItems.addAll([_item(0), _item(1)]);
    r.pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('published-item-prices-added')),
      findsOneWidget,
    );
    expect(find.textContaining('2 prix par article'), findsOneWidget);

    // « Voir mes prix » rouvre l'éditeur, sans préremplissage.
    await tester.tap(find.byKey(const Key('published-item-prices-see')));
    await tester.pumpAndSettle();
    expect(editorExtras.last, isNull);
  });

  testWidgets('sans prix de route : seul « Ajouter mes prix »', (tester) async {
    when(
      () => suggestions.getSuggestions(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => null);
    await pumpCard(tester);
    expect(
      find.byKey(const Key('published-item-prices-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('published-item-prices-add')), findsNothing);
    await tester.tap(find.byKey(const Key('published-item-prices-add-mine')));
    await tester.pumpAndSettle();
    expect(editorExtras.single, isNull);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tripPublishedItemPricesShown,
        properties: {'variant': 'none', 'suggestions_count': 0},
      ),
    ).called(1);
  });

  testWidgets('trajet publié avec des prix : pastilles, aucune proposition', (
    tester,
  ) async {
    await pumpCard(
      tester,
      trip: _trip(
        grid: const [
          AnnouncementGridItemModel(
            id: 'x',
            label: 'Téléphone',
            unitPriceNet: 15,
            unitPriceDisplay: 17,
          ),
          AnnouncementGridItemModel(
            id: 'y',
            label: 'Ordinateur',
            unitPriceNet: 30,
            unitPriceDisplay: 34,
          ),
        ],
      ),
    );
    expect(
      find.byKey(const Key('published-item-prices-filled')),
      findsOneWidget,
    );
    expect(find.text('Prix par article'), findsOneWidget);
    expect(find.textContaining('Téléphone · '), findsOneWidget);
    expect(find.textContaining('Ordinateur · '), findsOneWidget);
    expect(
      find.byKey(const Key('published-item-prices-proposal')),
      findsNothing,
    );
    verifyNever(() => grid.getItems());
  });

  testWidgets('grille déjà remplie, trajet sans prix : rien d\'affiché', (
    tester,
  ) async {
    gridItems.add(_item(0));
    await pumpCard(tester);
    expect(
      find.byKey(const Key('published-item-prices-proposal')),
      findsNothing,
    );
    expect(find.byKey(const Key('published-item-prices-filled')), findsNothing);
  });

  testWidgets('injection incomplète : aucune carte, aucun plantage', (
    tester,
  ) async {
    await getIt.reset();
    await tester.pumpWidget(
      localizedApp(
        Scaffold(body: TripPublishedItemPricesCard(announcement: _trip())),
      ),
    );
    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('écran de succès à 360 dp', () {
    setUpAll(_loadAppFonts);
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('libellés sur une ligne, bouton principal visible '
          '(${locale.languageCode})', (tester) async {
        if (locale.languageCode == 'en') enableEnglish();
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final r = router(
          Builder(
            builder: (context) => DonySuccessScreen(
              mascotteType: DonyMascotteType.succes,
              title: context.l10n.tripPublishSuccessTitleCreate,
              subtitle: context.l10n.tripPublishSuccessSubtitle(
                'Paris',
                'Abidjan',
              ),
              ctaLabel: context.l10n.tripPublishSuccessParcelsCta,
              ctaVariant: DonyButtonVariant.accent,
              onCta: () {},
              secondaryLabel: context.l10n.tripPublishSuccessCta,
              onSecondary: () {},
              tertiaryLabel: context.l10n.tripPublishSuccessShareCta,
              onTertiary: () {},
              extra: TripPublishedItemPricesCard(announcement: _trip()),
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: r,
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);

        final context = tester.element(find.byType(DonySuccessScreen));
        final l = context.l10n;
        // Le bouton principal reste à l'écran.
        final cta = tester.getRect(find.text(l.tripPublishSuccessParcelsCta));
        expect(cta.bottom, lessThanOrEqualTo(780));

        await tester.scrollUntilVisible(
          find.byKey(const Key('published-item-prices-add')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        final edit = find.byKey(const Key('published-item-prices-edit'));
        final add = find.byKey(const Key('published-item-prices-add'));
        expect(tester.getSize(edit).height, tester.getSize(add).height);
        for (final label in [l.commonEdit, l.tripPublishedItemPricesAddCta]) {
          final text = find.text(label);
          final laidOut = tester.getSize(text);
          final painted = tester.getRect(text);
          // Une ligne, et pas rétréci par le FittedBox du bouton.
          expect(laidOut.height, lessThan(30), reason: label);
          expect(painted.width, closeTo(laidOut.width, 0.5), reason: label);
        }
      });
    }
  });
}
