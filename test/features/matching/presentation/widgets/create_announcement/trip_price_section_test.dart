// Section prix de l'étape « Prix & conditions » avec le cubit des prix
// conseillés : pastille « le plus courant », exemples d'articles, analytics,
// préremplissage de la grille, et libellés sur une ligne à 360 dp (FR/EN).
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_price_section.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/currency_test_doubles.dart';
import '../../../../../helpers/l10n_test_helpers.dart';
import '../trip_owner/trip_card_harness.dart' show loadAppFonts;

class _MockSuggestionCubit extends MockCubit<TripPriceSuggestionState>
    implements TripPriceSuggestionCubit {}

class _MockAnnouncementFormBloc
    extends MockBloc<AnnouncementFormEvent, AnnouncementFormState>
    implements AnnouncementFormBloc {}

const _backendState = TripPriceSuggestionState(
  status: TripPriceSuggestionStatus.loaded,
  suggestion: TripPriceSuggestion(
    currency: 'EUR',
    pricePerKg: 9,
    sampleSize: 14,
    items: [
      TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 15),
      TripPriceSuggestionItem(label: 'Ordinateur', unitPrice: 30),
      TripPriceSuggestionItem(label: 'Documents', unitPrice: 10),
      TripPriceSuggestionItem(label: 'Tablette', unitPrice: 20),
    ],
  ),
);

Object? _gridExtra;

class _Harness {
  _Harness({int priceOption = -1, double customPrice = 0})
    : option = ValueNotifier<int>(priceOption),
      custom = ValueNotifier<double>(customPrice),
      ctrl = TextEditingController(),
      kg = ValueNotifier<double>(23);

  final ValueNotifier<int> option;
  final ValueNotifier<double> custom;
  final TextEditingController ctrl;
  final ValueNotifier<double> kg;

  void dispose() {
    option.dispose();
    custom.dispose();
    ctrl.dispose();
    kg.dispose();
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  TripPriceSuggestionCubit? cubit,
  AnnouncementFormState formState = const AnnouncementFormState(),
  int priceOption = -1,
  double customPrice = 0,
  Locale locale = AppL10n.fr,
}) async {
  final h = _Harness(priceOption: priceOption, customPrice: customPrice);
  addTearDown(h.dispose);
  final formBloc = _MockAnnouncementFormBloc();
  whenListen(
    formBloc,
    const Stream<AnnouncementFormState>.empty(),
    initialState: formState,
  );
  final content = SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          KgPriceStepperCard(
            currency: SupportedCurrency.eur,
            priceOptionNotifier: h.option,
            customPriceNotifier: h.custom,
            customPriceCtrl: h.ctrl,
          ),
          KgPriceEarningsBlock(
            currency: SupportedCurrency.eur,
            priceOptionNotifier: h.option,
            customPriceNotifier: h.custom,
            customPriceCtrl: h.ctrl,
            availableKgNotifier: h.kg,
          ),
          ItemPricesCard(
            currency: SupportedCurrency.eur,
            gridCurrency: SupportedCurrency.eur,
            priceOptionNotifier: h.option,
            customPriceNotifier: h.custom,
            customPriceCtrl: h.ctrl,
          ),
        ],
      ),
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementFormBloc>.value(value: formBloc),
              if (cubit != null)
                BlocProvider<TripPriceSuggestionCubit>.value(value: cubit),
            ],
            child: content,
          ),
        ),
      ),
      GoRoute(
        path: '/profile/price-grid',
        builder: (_, state) {
          _gridExtra = state.extra;
          return const Scaffold(body: Text('grid-screen'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return h;
}

TripPriceSuggestionCubit _cubit(TripPriceSuggestionState state) {
  final cubit = _MockSuggestionCubit();
  whenListen(
    cubit,
    const Stream<TripPriceSuggestionState>.empty(),
    initialState: state,
  );
  return cubit;
}

String _eur(num v) =>
    CurrencyFormatter.formatOrPlain(v, SupportedCurrency.eur, compact: true);

void main() {
  setUpAll(() async {
    registerFallbackValue(TripItemPricesSource.step);
    // Vraies polices : la largeur des libellés doit être celle de l'app,
    // pas celle de la police de test (un carré par caractère).
    await loadAppFonts();
  });

  setUp(() => _gridExtra = null);

  group('prix conseillé du back', () {
    testWidgets('prix = médiane de la route : pastille « le plus courant »', (
      tester,
    ) async {
      await _pump(tester, cubit: _cubit(_backendState));

      expect(
        tester.widget<Text>(find.byKey(const Key('kg-price-amount'))).data,
        '9',
      );
      expect(find.text('Prix le plus courant sur ce trajet'), findsOneWidget);
      expect(find.byKey(const Key('kg-price-reset')), findsNothing);
      // 23 kg à 9 € : 207 €.
      expect(find.text('Vous touchez ${_eur(207)}'), findsOneWidget);
    });

    testWidgets('« + » : pastille remplacée par le lien, analytics émis', (
      tester,
    ) async {
      final cubit = _cubit(_backendState);
      final h = await _pump(tester, cubit: cubit);

      await tester.tap(find.byKey(const Key('kg-price-increase')));
      await tester.pump();

      expect(h.custom.value, 10);
      expect(find.byKey(const Key('kg-price-most-common')), findsNothing);
      expect(
        find.text('Revenir au prix conseillé (${_eur(9)})'),
        findsOneWidget,
      );
      verify(
        () => cubit.priceAdjusted(up: true, fromSuggested: true),
      ).called(1);

      await tester.tap(find.byKey(const Key('kg-price-reset')));
      await tester.pump();
      expect(h.custom.value, 9);
      verify(cubit.priceResetToSuggested).called(1);
      // Laisse finir le fondu de la pastille revenue.
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('carte vide : trois exemples de la route, sans plus', (
      tester,
    ) async {
      await _pump(tester, cubit: _cubit(_backendState));

      expect(find.byKey(const Key('item-prices-examples')), findsOneWidget);
      expect(find.text('Téléphone · ${_eur(15)}'), findsOneWidget);
      expect(find.text('Ordinateur · ${_eur(30)}'), findsOneWidget);
      expect(find.text('Documents · ${_eur(10)}'), findsOneWidget);
      expect(find.textContaining('Tablette'), findsNothing);
    });

    testWidgets('« Ajouter mes prix » : analytics puis grille préremplie', (
      tester,
    ) async {
      final cubit = _cubit(_backendState);
      await _pump(tester, cubit: cubit);

      await tester.ensureVisible(find.byKey(const Key('item-prices-add')));
      await tester.tap(find.byKey(const Key('item-prices-add')));
      await tester.pumpAndSettle();

      verify(() => cubit.itemPricesOpened(TripItemPricesSource.step)).called(1);
      expect(find.text('grid-screen'), findsOneWidget);
      expect(_gridExtra, isA<List<PriceGridSuggestion>>());
      expect((_gridExtra! as List<PriceGridSuggestion>).first.unitPriceNet, 15);
    });

    testWidgets('« Modifier » de la carte remplie : source card_edit', (
      tester,
    ) async {
      final cubit = _cubit(_backendState);
      await _pump(
        tester,
        cubit: cubit,
        formState: const AnnouncementFormState(
          pricingMode: PricingMode.mixed,
          gridLoaded: true,
          gridPreviewItems: [GridPreviewItemFixture.phone],
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('item-prices-edit')));
      await tester.tap(find.byKey(const Key('item-prices-edit')));
      await tester.pumpAndSettle();

      verify(
        () => cubit.itemPricesOpened(TripItemPricesSource.cardEdit),
      ).called(1);
    });
  });

  group('gridSuggestionsFrom', () {
    test('devise de la grille ≠ devise des prix : aucune proposition', () {
      registerCurrencyPreference('XOF');
      expect(gridSuggestionsFrom(_backendState), isEmpty);
    });

    test('prix gardés tels quels, sans bornes ; montants nuls écartés', () {
      const state = TripPriceSuggestionState(
        suggestion: TripPriceSuggestion(
          currency: 'EUR',
          items: [
            TripPriceSuggestionItem(label: 'Clé USB', unitPrice: 2),
            TripPriceSuggestionItem(label: 'Moto', unitPrice: 900),
            TripPriceSuggestionItem(label: 'Vide', unitPrice: 0),
          ],
        ),
      );
      final list = gridSuggestionsFrom(state);
      expect(list.map((e) => e.label), ['Clé USB', 'Moto']);
      expect(list.map((e) => e.unitPriceNet), [2, 900]);
    });
  });

  group('libellés sur une ligne à 360 dp', () {
    for (final locale in [AppL10n.fr, const Locale('en')]) {
      testWidgets('${locale.languageCode} : lien, bouton, pastille', (
        tester,
      ) async {
        if (locale.languageCode == 'en') enableEnglish();
        tester.view.physicalSize = const Size(360, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // Prix ≠ conseillé : le lien « Revenir au prix conseillé » s'affiche.
        await _pump(
          tester,
          cubit: _cubit(_backendState),
          priceOption: 3, // 10 €
          locale: locale,
        );
        expect(tester.takeException(), isNull);

        for (final key in [
          const Key('kg-price-reset'),
          const Key('item-prices-add'),
        ]) {
          final finder = find.descendant(
            of: find.byKey(key),
            matching: find.byType(Text),
          );
          final text = tester.widget<Text>(finder.first);
          final size = tester.getSize(finder.first);
          final style =
              text.style ??
              DefaultTextStyle.of(tester.element(finder.first)).style;
          final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.4);
          expect(
            size.height,
            lessThan(lineHeight * 1.9),
            reason: '${text.data} tient sur une ligne',
          );
          final paragraph = tester.renderObject<RenderParagraph>(finder.first);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${text.data} n\'est pas coupé',
          );
        }
      });
    }
  });
}

/// Article de grille de test.
abstract final class GridPreviewItemFixture {
  static const phone = GridPreviewItem(
    id: 'g1',
    label: 'Téléphone',
    unitPriceDisplay: 15,
  );
}
