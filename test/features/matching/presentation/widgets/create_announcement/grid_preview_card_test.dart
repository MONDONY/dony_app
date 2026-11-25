// Prix par article de l'étape « Prix & conditions » (carte remplie) :
// affichage des prix de la grille du profil (net sous grille de commission,
// conversion dans la devise du trajet) et rechargement au retour de l'écran
// de grille. Anciennement la carte « aperçu de grille » du mode MIXED.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_price_section.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../../helpers/l10n_test_helpers.dart';

class _MockAnnouncementFormBloc
    extends MockBloc<AnnouncementFormEvent, AnnouncementFormState>
    implements AnnouncementFormBloc {}

const _items = [
  GridPreviewItem(id: 'a1', label: 'Téléphone', unitPriceDisplay: 12.60),
  GridPreviewItem(id: 'a2', label: 'Vêtement', unitPriceDisplay: 8.40),
  GridPreviewItem(id: 'a3', label: 'Chaussures', unitPriceDisplay: 15.75),
  GridPreviewItem(id: 'a4', label: 'Sac de riz', unitPriceDisplay: 26.25),
  GridPreviewItem(id: 'a5', label: 'Livre', unitPriceDisplay: 5.25),
];

/// Extra reçu par la route de la grille (préremplissage d'une grille vide).
Object? _lastGridExtra;

/// Monte la carte derrière un GoRouter réel : « Modifier » pousse la route de
/// la grille, et le retour doit provoquer un rechargement.
Widget _wrap(
  List<GridPreviewItem> items, {
  AnnouncementFormBloc? bloc,
  SupportedCurrency currency = SupportedCurrency.eur,
  SupportedCurrency? gridCurrency,
}) {
  final formBloc = bloc ?? _MockAnnouncementFormBloc();
  if (bloc == null) {
    whenListen(
      formBloc,
      const Stream<AnnouncementFormState>.empty(),
      initialState: AnnouncementFormState(gridPreviewItems: items),
    );
  }
  final priceOption = ValueNotifier<int>(-1);
  final customPrice = ValueNotifier<double>(6);
  final customCtrl = TextEditingController();
  addTearDown(() {
    priceOption.dispose();
    customPrice.dispose();
    customCtrl.dispose();
  });
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: ItemPricesCard(
              currency: currency,
              gridCurrency: gridCurrency,
              priceOptionNotifier: priceOption,
              customPriceNotifier: customPrice,
              customPriceCtrl: customCtrl,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/price-grid',
        builder: (context, state) {
          _lastGridExtra = state.extra;
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ),
          );
        },
      ),
    ],
  );

  return BlocProvider<AnnouncementFormBloc>.value(
    value: formBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    // mocktail exige une valeur de repli pour capturer les events du BLoC.
    registerFallbackValue(const AnnouncementGridPreviewLoadRequested());
  });

  group('Prix par article — liste', () {
    testWidgets('tous les articles sont listés avec leur prix', (tester) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('item-prices-filled')), findsOneWidget);
      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(find.text('Vos prix par article'), findsOneWidget);
    });

    testWidgets('rappelle que le reste est compté au kilo', (tester) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      // Aucun prix posé : le prix conseillé de la devise (8 €/kg).
      final eight = CurrencyFormatter.formatOrPlain(
        8,
        SupportedCurrency.eur,
        compact: true,
      );
      expect(
        find.text('Le reste est compté au kilo, à $eight/kg.'),
        findsOneWidget,
      );
    });
  });

  group('Prix par article — sous grille de commission', () {
    const netItems = [
      GridPreviewItem(
        id: 'n1',
        label: 'Livre',
        unitPriceDisplay: 5.25,
        unitPriceNet: 5,
      ),
    ];

    testWidgets('l\'étiquette montre le net, pas le prix majoré', (
      tester,
    ) async {
      useTestCommissionGrid();
      await tester.pumpWidget(
        _wrap(netItems, gridCurrency: SupportedCurrency.eur),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(CurrencyFormatter.format(5, SupportedCurrency.eur)),
        findsOneWidget,
      );
      expect(
        find.text(CurrencyFormatter.format(5.25, SupportedCurrency.eur)),
        findsNothing,
      );
    });

    testWidgets('sans grille, l\'étiquette garde le prix affiché', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(netItems, gridCurrency: SupportedCurrency.eur),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(CurrencyFormatter.format(5.25, SupportedCurrency.eur)),
        findsOneWidget,
      );
    });
  });

  group('Prix par article — rafraîchissement au retour', () {
    late AnnouncementFormBloc bloc;

    setUp(() {
      _lastGridExtra = 'non visité';
      bloc = _MockAnnouncementFormBloc();
      whenListen(
        bloc,
        const Stream<AnnouncementFormState>.empty(),
        initialState: const AnnouncementFormState(gridPreviewItems: _items),
      );
    });

    testWidgets('« Modifier » ouvre l\'écran de grille du profil', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('item-prices-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Retour'), findsOneWidget);
      // Grille déjà remplie : rien à préremplir.
      expect(_lastGridExtra, isNull);
    });

    testWidgets('le retour recharge les prix par article', (tester) async {
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('item-prices-edit')));
      await tester.pumpAndSettle();

      verifyNever(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      );

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      ).called(1);
    });

    testWidgets('openPriceGridAndRefresh transmet les prix de la route', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      const suggestions = [
        PriceGridSuggestion(label: 'Téléphone', unitPriceNet: 15),
      ];
      final context = tester.element(find.byType(ItemPricesCard));
      final done = openPriceGridAndRefresh(context, suggestions: suggestions);
      await tester.pumpAndSettle();
      expect(_lastGridExtra, suggestions);

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      await done;
      verify(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      ).called(1);
    });
  });

  group('Prix par article — devise du trajet ≠ devise de la grille', () {
    const eurItems = [
      GridPreviewItem(id: 'b1', label: 'Téléphone', unitPriceDisplay: 10),
      GridPreviewItem(id: 'b2', label: 'Vêtement', unitPriceDisplay: 12),
    ];
    String xof(num v) => CurrencyFormatter.format(v, SupportedCurrency.xof);
    String eur(num v) => CurrencyFormatter.format(v, SupportedCurrency.eur);

    tearDown(ActiveRates.resetForTest);

    testWidgets('EUR → XOF : prix convertis et mention affichée', (
      tester,
    ) async {
      ActiveRates.setServerRates({'XOF': 655.957});
      await tester.pumpWidget(
        _wrap(
          eurItems,
          currency: SupportedCurrency.xof,
          gridCurrency: SupportedCurrency.eur,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(xof(6560)), findsOneWidget);
      expect(find.text(xof(7871)), findsOneWidget);
      // Jamais le prix brut sous le symbole du trajet (FLUTTER-ER).
      expect(find.text(xof(10)), findsNothing);
      expect(find.text('Converti depuis EUR au taux du jour'), findsOneWidget);
    });

    testWidgets('même devise : prix inchangés, pas de mention', (tester) async {
      ActiveRates.setServerRates({'XOF': 655.957});
      await tester.pumpWidget(
        _wrap(eurItems, gridCurrency: SupportedCurrency.eur),
      );
      await tester.pumpAndSettle();

      expect(find.text(eur(10)), findsOneWidget);
      expect(find.text(eur(12)), findsOneWidget);
      expect(
        find.byKey(const Key('grid-preview-converted-note')),
        findsNothing,
      );
    });

    testWidgets('taux indisponibles : symbole de la grille, pas de mention', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          eurItems,
          currency: SupportedCurrency.xof,
          gridCurrency: SupportedCurrency.eur,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(eur(10)), findsOneWidget);
      expect(find.text(eur(12)), findsOneWidget);
      expect(find.text(xof(10)), findsNothing);
      expect(
        find.byKey(const Key('grid-preview-converted-note')),
        findsNothing,
      );
    });

    testWidgets('devise de la grille inconnue : montant sans symbole', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(eurItems, currency: SupportedCurrency.xof));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text(xof(10)), findsNothing);
    });

    testWidgets('mention traduite en anglais', (tester) async {
      useEnglish();
      ActiveRates.setServerRates({'XOF': 655.957});
      await tester.pumpWidget(
        _wrap(
          eurItems,
          currency: SupportedCurrency.xof,
          gridCurrency: SupportedCurrency.eur,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Converted from EUR at today's rate"), findsOneWidget);
    });
  });

  group('Prix par article — English', () {
    testWidgets('titre et bouton « Edit » traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Your prices per item'), findsWidgets);
    });
  });
}
