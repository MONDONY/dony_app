// Étape 3 « Le prix » : ordre des sections, tout sur un écran, prix au kilo,
// devise verrouillée à la modification. Présentation seulement : le payload
// envoyé au back reste celui d'avant (même total, mêmes champs).
import 'dart:io';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

const _seed = PackageRequestFormState(
  currentStep: 2,
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  weightKg: 4,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: ['Vêtements & tissus'],
  currency: SupportedCurrency.eur,
);

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync()),
      ),
    );
  }
  await loader.load();
}

void main() {
  late _MockRepo repo;
  late PackageRequestFormBloc bloc;

  setUpAll(() async {
    // Les vraies polices : avec la police de repli des tests (carrés), les
    // hauteurs et largeurs mesurées ne seraient pas celles de l'écran.
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
    ]);
    await _loadFont('HankenGrotesk', [
      'HankenGrotesk-SemiBold.ttf',
      'HankenGrotesk-Bold.ttf',
      'HankenGrotesk-ExtraBold.ttf',
    ]);
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(<PaymentMethod>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(DateTime(2026));
  });

  setUpAll(() async {
    // Les vraies polices : avec la police de repli des tests (carrés), les
    // hauteurs et largeurs mesurées ne seraient pas celles de l'écran.
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
    ]);
    await _loadFont('HankenGrotesk', [
      'HankenGrotesk-SemiBold.ttf',
      'HankenGrotesk-Bold.ttf',
      'HankenGrotesk-ExtraBold.ttf',
    ]);
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(<PaymentMethod>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repo = _MockRepo();
  });

  /// Monte l'étape à 360 dp de large. [height] simule l'espace laissé à
  /// l'étape par la barre du haut et la barre d'action du bas de l'assistant.
  Future<void> pump(
    WidgetTester tester, {
    PackageRequestFormState seed = _seed,
    double height = 534,
    double textScale = 1,
    bool? mobileMoneyAccountActive,
    GlobalKey<Step3RecapBudgetState>? key,
    ValueNotifier<bool>? canContinue,
  }) async {
    tester.view
      ..physicalSize = Size(360, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Créé dans le corps du test (zone du testeur) : un bloc créé dans setUp
    // ne rafraîchit pas l'interface sous tester.pump.
    bloc = PackageRequestFormBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
    )..add(FormDraftRestored(seed));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<PackageRequestFormBloc>.value(value: bloc),
              BlocProvider(
                create: (_) => PackageRequestPhotosCubit(
                  repo,
                  makeDisabledAnalytics(MockAnalyticsBackend()),
                ),
              ),
            ],
            child: Scaffold(
              body: Step3RecapBudget(
                key: key,
                canContinueNotifier: canContinue,
                currency: seed.currency,
                mobileMoneyAccountActive: mobileMoneyAccountActive,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

  double maxScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;

  group('ordre des sections', () {
    for (final english in [false, true]) {
      testWidgets('${english ? 'en' : 'fr'} : résumé, devise, paiement, '
          'mode, sélecteur, champ, tous visibles sans défilement', (
        tester,
      ) async {
        if (english) useEnglish();
        await pump(tester);
        final summary = top(tester, find.textContaining('Paris'));
        final currency = top(tester, find.text('Euro (EUR)'));
        final payment = top(tester, find.text(english ? 'Card' : 'Carte'));
        final modes = top(tester, find.byKey(const Key('price-mode-open')));
        final basis = top(tester, find.byKey(const Key('price-basis-total')));
        final field = top(tester, find.byKey(const Key('total-budget-input')));
        expect(
          [summary, currency, payment, modes, basis, field],
          orderedEquals(
            [summary, currency, payment, modes, basis, field]..sort(),
          ),
        );
        expect(summary < currency, isTrue);
        expect(currency < payment, isTrue);
        expect(payment < modes, isTrue);
        expect(modes < basis, isTrue);
        expect(basis < field, isTrue);
        // Tout tient dans la hauteur laissée à l'étape : aucun défilement.
        expect(maxScroll(tester), 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'résumé compact : trajet, poids et contenu sur une seule ligne',
      (tester) async {
        await pump(tester);
        final route = top(tester, find.text('Paris → Abidjan'));
        expect(top(tester, find.text('4 kg')), route);
        expect(top(tester, find.text('Vêtements & tissus')), route);
      },
    );

    testWidgets('code promo et information de publication après le prix', (
      tester,
    ) async {
      await pump(tester, seed: _seed.copyWith(totalBudgetEur: 20), height: 900);
      final field = top(tester, find.byKey(const Key('total-budget-input')));
      final promo = top(tester, find.byKey(const Key('promo-code-input')));
      final banner = top(
        tester,
        find.textContaining('les voyageurs sur ce trajet sont prévenus'),
      );
      expect(field < promo, isTrue);
      expect(promo < banner, isTrue);
    });
  });

  group('devise et moyens de paiement', () {
    testWidgets('F CFA : mobile money et espèces, jamais de carte', (
      tester,
    ) async {
      await pump(
        tester,
        seed: _seed.copyWith(
          currency: SupportedCurrency.xof,
          acceptedPaymentMethods: {
            PaymentMethod.mobileMoney,
            PaymentMethod.cash,
          },
        ),
      );
      expect(find.text('Mobile money'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Carte'), findsNothing);
      expect(find.textContaining('F CFA au total'), findsOneWidget);
    });

    testWidgets('euro : carte et espèces, pas de mobile money', (tester) async {
      await pump(tester);
      expect(find.text('Carte'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Mobile money'), findsNothing);
      expect(find.text('€ au total'), findsOneWidget);
    });

    testWidgets('compte mobile money absent : avertissement sous les moyens '
        'de paiement, avant le prix', (tester) async {
      await pump(
        tester,
        seed: _seed.copyWith(
          currency: SupportedCurrency.xof,
          acceptedPaymentMethods: {PaymentMethod.mobileMoney},
        ),
        mobileMoneyAccountActive: false,
        height: 700,
      );
      final chips = top(tester, find.text('Mobile money'));
      final warning = top(
        tester,
        find.byKey(const Key('request-mobile-money-setup-notice')),
      );
      final modes = top(tester, find.byKey(const Key('price-mode-open')));
      expect(chips < warning, isTrue);
      expect(warning < modes, isTrue);
      expect(
        find.byKey(const Key('request-activate-mobile-money-cta')),
        findsOneWidget,
      );
    });
  });

  group('prix au kilo', () {
    testWidgets('par défaut : prix total, comportement inchangé', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('total-budget-input')), '45');
      await tester.pump();
      expect(bloc.state.totalBudgetEur, 45);
      expect(find.byKey(const Key('price-per-kilo-computed')), findsNothing);
    });

    testWidgets(
      '4 kg × 5 € : le total calculé part au bloc, la ligne de calcul '
      'est affichée',
      (tester) async {
        await pump(tester);
        await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('total-budget-input')),
          '5',
        );
        await tester.pump();

        await tester.pump();
        expect(bloc.state.totalBudgetEur, 20);
        expect(find.text('€ / kg'), findsOneWidget);
        final five = CurrencyFormatter.format(
          5,
          SupportedCurrency.eur,
          compact: true,
        );
        final twenty = CurrencyFormatter.format(
          20,
          SupportedCurrency.eur,
          compact: true,
        );
        expect(find.text('4 kg × $five = $twenty au total'), findsOneWidget);
        expect(
          find.textContaining('Prix de l\'envoi (4 kg × '),
          findsOneWidget,
        );
      },
    );

    testWidgets('arrondi à la précision de la devise', (tester) async {
      await pump(tester, seed: _seed.copyWith(weightKg: 3));
      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('total-budget-input')),
        '3,335',
      );
      await tester.pump();
      expect(bloc.state.totalBudgetEur, 10.01);
    });

    testWidgets('en F CFA : arrondi au franc', (tester) async {
      await pump(
        tester,
        seed: _seed.copyWith(
          currency: SupportedCurrency.xof,
          weightKg: 1.5,
          acceptedPaymentMethods: {PaymentMethod.cash},
        ),
      );
      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('total-budget-input')),
        '333',
      );
      await tester.pump();
      expect(bloc.state.totalBudgetEur, 500);
    });

    testWidgets('poids inconnu : prix au kilo grisé et expliqué', (
      tester,
    ) async {
      await pump(
        tester,
        seed: const PackageRequestFormState(
          currentStep: 2,
          currency: SupportedCurrency.eur,
        ),
      );
      expect(
        find.byKey(const Key('price-basis-per-kilo-hint')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      // Toujours en prix total : l'unité est celle du total.
      expect(find.text('€ au total'), findsOneWidget);
      expect(find.text('€ / kg'), findsNothing);
    });

    testWidgets(
      'plafond contrôlé sur le total : 200 €/kg × 4 kg = 800 € refusé',
      (tester) async {
        final key = GlobalKey<Step3RecapBudgetState>();
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);
        await pump(tester, key: key, canContinue: canContinue);
        await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('total-budget-input')),
          '200',
        );
        await tester.pump();
        key.currentState!.submit();
        await tester.pump();

        expect(bloc.state.totalBudgetEur, 800);
        expect(canContinue.value, isFalse);
        expect(find.textContaining('560'), findsWidgets);
      },
    );

    testWidgets('changement de mode : la valeur est conservée quand c\'est '
        'possible', (tester) async {
      await pump(tester, seed: _seed.copyWith(totalBudgetEur: 20));
      final field = find.byKey(const Key('total-budget-input'));
      expect(tester.widget<TextFormField>(field).controller!.text, '20');

      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, '5');
      expect(bloc.state.totalBudgetEur, 20);

      await tester.tap(find.byKey(const Key('price-basis-total')));
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, '20');
      expect(bloc.state.totalBudgetEur, 20);
    });

    testWidgets('total non convertible : champ vidé, total jamais changé en '
        'silence', (tester) async {
      await pump(tester, seed: _seed.copyWith(weightKg: 3, totalBudgetEur: 10));
      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('total-budget-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(bloc.state.totalBudgetEur, isNull);
    });

    testWidgets('le payload envoyé est identique, en prix total ou au kilo', (
      tester,
    ) async {
      final calls = <Map<Symbol, dynamic>>[];
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
          promoCode: any(named: 'promoCode'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((inv) {
        calls.add(Map.of(inv.namedArguments));
        return Future<PackageRequest>.error(Exception('stop'));
      });
      when(
        () => repo.quote(
          any(),
          promoCode: any(named: 'promoCode'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) => Future.error(Exception('pas de devis')));

      final key = GlobalKey<Step3RecapBudgetState>();
      await pump(tester, key: key);
      await tester.enterText(find.byKey(const Key('total-budget-input')), '20');
      await tester.pump();
      key.currentState!.submit();
      await tester.pump();
      await tester.pump();

      // Même demande, saisie au kilo.
      await pump(tester, key: GlobalKey<Step3RecapBudgetState>());
      await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('total-budget-input')), '5');
      await tester.pump();
      bloc.add(const FormStep3Submitted());
      await tester.pump();
      await tester.pump();

      expect(calls, hasLength(2));
      expect(calls[0][#totalBudgetEur], 20);
      expect(calls[1], calls[0]);
    });
  });

  group('modification', () {
    testWidgets('devise verrouillée, même ordre que la création', (
      tester,
    ) async {
      await pump(
        tester,
        seed: _seed.copyWith(editingRequestId: 'pr-1', totalBudgetEur: 20),
      );
      final locked = find.byKey(
        const Key('package-request-currency-locked-row'),
      );
      expect(locked, findsOneWidget);
      expect(
        find.byKey(const Key('package-request-currency-selector-row')),
        findsNothing,
      );
      expect(find.text('Changer'), findsNothing);
      expect(find.text('non modifiable'), findsOneWidget);
      expect(
        top(tester, find.textContaining('Paris')) < top(tester, locked),
        isTrue,
      );
      expect(top(tester, locked) < top(tester, find.text('Carte')), isTrue);
      expect(
        top(tester, find.text('Carte')) <
            top(tester, find.byKey(const Key('price-mode-open'))),
        isTrue,
      );
      expect(
        top(tester, find.byKey(const Key('price-mode-open'))) <
            top(tester, find.byKey(const Key('total-budget-input'))),
        isTrue,
      );
    });
  });

  group('robustesse', () {
    for (final english in [false, true]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${english ? 'en' : 'fr'}, texte x$scale : aucun overflow, '
            'aucun tiret cadratin', (tester) async {
          if (english) useEnglish();
          await pump(
            tester,
            seed: _seed.copyWith(
              currency: SupportedCurrency.xof,
              acceptedPaymentMethods: {
                PaymentMethod.mobileMoney,
                PaymentMethod.cash,
              },
              totalBudgetEur: 15000,
            ),
            mobileMoneyAccountActive: false,
            height: 1400,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          final texts = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
          for (final s in texts) {
            expect(s.contains('—'), isFalse, reason: s);
          }
          // Aucun libellé de bouton, de segment ou de carte n'est rétréci ni
          // coupé : une seule ligne chacun.
          for (final k in ['price-basis-total', 'price-basis-per-kilo']) {
            final box = tester.getSize(find.byKey(Key(k)));
            expect(box.height, lessThan(60), reason: k);
          }
        });
      }
    }
  });
}
