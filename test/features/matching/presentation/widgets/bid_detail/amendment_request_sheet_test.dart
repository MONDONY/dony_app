import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_request_sheet.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/label_fit_expectations.dart';
import '../../../../../helpers/plane_icon_expectations.dart';
import '../trip_owner/trip_card_harness.dart' show loadAppFonts;

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  travelerName: 'Moussa',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

BidModel _boatBid() => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  travelerName: 'Moussa',
  departureCity: 'Marseille',
  arrivalCity: 'Abidjan',
  status: 'ACCEPTED',
  transportMode: TransportMode.boat,
  volumeM3: 0.5,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

AmendmentOptions _boatOptions() => const AmendmentOptions(
  currency: 'EUR',
  availableVolumeM3: 0.85,
  pricePerM3Display: 120,
  paymentMethods: [BidPaymentMethod.cash, BidPaymentMethod.stripe],
  minAmount: 1,
  maxAmount: 300,
);

AmendmentOptions _options(List<BidPaymentMethod> methods) => AmendmentOptions(
  currency: 'EUR',
  availableKg: 6,
  pricePerKgDisplay: 5.13,
  gridItems: const [
    AmendmentGridItemOption(
      id: 'g1',
      label: 'Téléphone',
      unitPriceDisplay: 11.4,
    ),
  ],
  paymentMethods: methods,
  minAmount: 1,
  maxAmount: 300,
);

const _cashAmendment = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'CASH',
  grossAmount: 22.4,
);

const _cardCheckout = AmendmentCheckout(
  amendment: BidAmendment(
    id: 'am-1',
    status: BidAmendmentStatus.authorizationPending,
    rail: 'STRIPE',
    grossAmount: 22.4,
  ),
  clientSecret: 'pi_1_secret_2',
  paymentMethodTypes: ['card'],
);

/// Texte affiché, espaces insécables lues comme des espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(RegExp('[  ]'), ' ') ==
          text,
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  bool? result;
  PaymentSheetConfig? presentedConfig;
  var presentCalls = 0;

  setUpAll(() => registerFallbackValue(BidPaymentMethod.cash));

  setUp(() {
    result = null;
    presentedConfig = null;
    presentCalls = 0;
    repository = _MockRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options('bid-1')).thenAnswer(
      (_) async => _options([
        BidPaymentMethod.cash,
        BidPaymentMethod.stripe,
        BidPaymentMethod.mobileMoney,
      ]),
    );
    when(
      () => repository.quote(
        'bid-1',
        addedKg: any(named: 'addedKg'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async => 22.4);
    getIt.registerFactory<AmendmentRequestCubit>(
      () => AmendmentRequestCubit(
        repository,
        analytics,
        quoteDebounce: Duration.zero,
      ),
    );
  });

  tearDown(() async => getIt.reset());

  Future<void> open(
    WidgetTester tester, {
    Future<bool> Function(BuildContext)? authorize,
    bool pay = true,
    BidModel? bid,
    Locale locale = AppL10n.fr,
    Size size = const Size(1200, 3200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AmendmentRequestSheet.show(
                  context,
                  bid: bid ?? _bid(),
                  authorize: authorize ?? (_) async => true,
                  presentSheet:
                      (
                        ctx, {
                        required config,
                        required contextLabel,
                        required onSuccess,
                      }) async {
                        presentCalls++;
                        presentedConfig = config;
                        if (pay) onSuccess();
                      },
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> addKilos(WidgetTester tester, int taps) async {
    for (var i = 0; i < taps; i++) {
      await tester.tap(find.byTooltip('Plus').first);
      await tester.pumpAndSettle();
    }
  }

  Finder submit(String label) => find.byWidgetPredicate(
    (w) =>
        w is DonyButton &&
        w.label.replaceAll(RegExp('[\u00A0\u202F]'), ' ') == label,
  );

  testWidgets('sheet_buttonInStickyBottom', (tester) async {
    await open(tester);

    final button = submit('Envoyer la demande à Moussa');
    expect(button, findsOneWidget);
    expect(
      find.ancestor(of: button, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    expect(tester.widget<DonyButton>(button).onPressed, isNull);
    expect(_txt('À payer en plus'), findsOneWidget);
  });

  testWidgets('sheet_showsKgLabelAndGridItems', (tester) async {
    await open(tester);

    expect(_txt('KILOS EN PLUS · 5,13 €/KG · 6 KG LIBRES'), findsOneWidget);
    expect(_txt('ARTICLES DE LA GRILLE DE MOUSSA'), findsOneWidget);
    expect(_txt('Téléphone'), findsOneWidget);
    expect(_txt('+0 kg'), findsOneWidget);
  });

  group('colis au m³ (trajet bateau)', () {
    setUp(() {
      when(
        () => repository.options('bid-1'),
      ).thenAnswer((_) async => _boatOptions());
      when(
        () => repository.quote(
          'bid-1',
          addedKg: any(named: 'addedKg'),
          addedVolumeM3: any(named: 'addedVolumeM3'),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async => 36);
    });

    testWidgets('boatAmendment_showsVolumeSelector_notKilos', (tester) async {
      await open(tester, bid: _boatBid());
      expect(_txt('VOLUME EN PLUS · 120 €/M³ · 0,8 M³ LIBRES'), findsOneWidget);
      expect(_txt('+0 m³'), findsOneWidget);
      expect(find.textContaining('KILOS'), findsNothing);
      expect(find.textContaining('kg'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('boatAmendment_sendsVolume_byTenth', (tester) async {
      await open(tester, bid: _boatBid());
      await addKilos(tester, 3);

      expect(_txt('+0,3 m³'), findsOneWidget);
      verify(
        () => repository.quote(
          'bid-1',
          addedKg: 0,
          addedVolumeM3: 0.3,
          items: const {},
        ),
      ).called(1);
      expect(_txt('36 €'), findsOneWidget);

      await tester.tap(submit('Envoyer la demande à Moussa'));
      await tester.pumpAndSettle();
      verify(
        () => repository.create(
          'bid-1',
          addedKg: 0,
          addedVolumeM3: 0.3,
          items: const {},
          method: BidPaymentMethod.cash,
        ),
      ).called(1);
    });

    testWidgets('boatAmendment_plusButtonStopsAtFreeVolume', (tester) async {
      await open(tester, bid: _boatBid());
      await addKilos(tester, 8);

      expect(_txt('+0,8 m³'), findsOneWidget);
      final plus = find.descendant(
        of: find.byTooltip('Plus').first,
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(plus).onTap, isNull);
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets(
        'boatAmendment_labelsAndButtonFitAt360 (${locale.languageCode})',
        (tester) async {
          await loadAppFonts();
          await open(
            tester,
            bid: _boatBid(),
            locale: locale,
            size: const Size(360, 3200),
          );

          expect(
            find.textContaining(
              locale == AppL10n.en ? 'EXTRA VOLUME' : 'VOLUME EN PLUS',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expectButtonLabelNominal(
            tester,
            find.byWidgetPredicate((w) => w is DonyButton),
          );
        },
      );
    }

    testWidgets('kgAmendment_unchanged_planeParcel', (tester) async {
      // Colis d'un trajet bateau SANS volume (ancien back) ou autre mode :
      // le sélecteur de kilos reste.
      when(
        () => repository.options('bid-1'),
      ).thenAnswer((_) async => _options([BidPaymentMethod.cash]));
      await open(tester);
      expect(_txt('KILOS EN PLUS · 5,13 €/KG · 6 KG LIBRES'), findsOneWidget);
      expect(find.textContaining('M³'), findsNothing);
    });
  });

  testWidgets('sheet_cardMethod_showsBloquerLabel', (tester) async {
    await open(tester);
    await addKilos(tester, 2);
    await tester.tap(_txt('Carte'));
    await tester.pumpAndSettle();

    expect(_txt('+1 kg'), findsOneWidget);
    expect(submit('Bloquer 22,40 € et envoyer'), findsOneWidget);
  });

  testWidgets('sheet_xofBid_noCardChip', (tester) async {
    when(() => repository.options('bid-1')).thenAnswer(
      (_) async =>
          _options([BidPaymentMethod.cash, BidPaymentMethod.mobileMoney]),
    );
    await open(tester);

    expect(_txt('Carte'), findsNothing);
    expect(_txt('Espèces'), findsOneWidget);
    expect(_txt('Mobile money'), findsOneWidget);
  });

  testWidgets('sheet_selectingGridItem_requotesAndEnablesButton', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Téléphone'));
    await tester.pumpAndSettle();

    verify(
      () => repository.quote('bid-1', addedKg: 0, items: {'g1': 1}),
    ).called(1);
    expect(
      tester
          .widget<DonyButton>(submit('Envoyer la demande à Moussa'))
          .onPressed,
      isNotNull,
    );
    expect(_txt('22,40 €'), findsOneWidget);
  });

  testWidgets('sheet_cash_submitPopsTrue', (tester) async {
    when(
      () => repository.create(
        'bid-1',
        addedKg: 1,
        items: const {},
        method: BidPaymentMethod.cash,
      ),
    ).thenAnswer(
      (_) async => const AmendmentCheckout(amendment: _cashAmendment),
    );
    await open(tester);
    await addKilos(tester, 2);
    await tester.tap(submit('Envoyer la demande à Moussa'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(_txt('Modifier mon colis'), findsNothing);
  });

  testWidgets('sheet_card_authorizesThenConfirms', (tester) async {
    when(
      () => repository.create(
        'bid-1',
        addedKg: 1,
        items: const {},
        method: BidPaymentMethod.stripe,
      ),
    ).thenAnswer((_) async => _cardCheckout);
    when(
      () => repository.confirmAuthorization('bid-1', 'am-1'),
    ).thenAnswer((_) async => _cashAmendment);
    await open(tester);
    await addKilos(tester, 2);
    await tester.tap(_txt('Carte'));
    await tester.pumpAndSettle();
    await tester.tap(submit('Bloquer 22,40 € et envoyer'));
    await tester.pumpAndSettle();

    expect(presentedConfig?.clientSecret, 'pi_1_secret_2');
    expect(presentedConfig?.amountEur, 22.4);
    expect(presentedConfig?.analyticsContext, 'bid_amendment');
    verify(() => repository.confirmAuthorization('bid-1', 'am-1')).called(1);
    expect(result, isTrue);
  });

  testWidgets('sheet_card_paymentSheetClosed_cancelsRequest', (tester) async {
    when(
      () => repository.create(
        'bid-1',
        addedKg: 1,
        items: const {},
        method: BidPaymentMethod.stripe,
      ),
    ).thenAnswer((_) async => _cardCheckout);
    when(
      () => repository.cancel('bid-1', 'am-1'),
    ).thenAnswer((_) async => _cashAmendment);
    await open(tester, pay: false);
    await addKilos(tester, 2);
    await tester.tap(_txt('Carte'));
    await tester.pumpAndSettle();
    await tester.tap(submit('Bloquer 22,40 € et envoyer'));
    await tester.pumpAndSettle();

    verify(() => repository.cancel('bid-1', 'am-1')).called(1);
    verifyNever(() => repository.confirmAuthorization(any(), any()));
    expect(result, isNull);
    expect(submit('Bloquer 22,40 € et envoyer'), findsOneWidget);
  });

  testWidgets('sheet_card_localAuthDenied_createsNothing', (tester) async {
    await open(tester, authorize: (_) async => false);
    await addKilos(tester, 2);
    await tester.tap(_txt('Carte'));
    await tester.pumpAndSettle();
    await tester.tap(submit('Bloquer 22,40 € et envoyer'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.create(
        any(),
        addedKg: any(named: 'addedKg'),
        items: any(named: 'items'),
        method: any(named: 'method'),
      ),
    );
    expect(presentCalls, 0);
    expect(
      tester.widget<DonyButton>(submit('Bloquer 22,40 € et envoyer')).onPressed,
      isNotNull,
    );
  });

  testWidgets('sheet_closingError_popsTrueToReload', (tester) async {
    when(
      () => repository.create(
        'bid-1',
        addedKg: 1,
        items: const {},
        method: BidPaymentMethod.cash,
      ),
    ).thenThrow(const ConflictException('x', code: 'amendment-already-open'));
    await open(tester);
    await addKilos(tester, 2);
    await tester.tap(submit('Envoyer la demande à Moussa'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('sheet_loadFailed_retryReloads', (tester) async {
    var calls = 0;
    when(() => repository.options('bid-1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NetworkException('x');
      return _options([BidPaymentMethod.cash]);
    });
    await open(tester);

    expect(
      _txt('Impossible de charger les options de modification.'),
      findsOneWidget,
    );
    await tester.tap(submit('Réessayer'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(_txt('ARTICLES DE LA GRILLE DE MOUSSA'), findsOneWidget);
  });

  testWidgets('sheet_subtitle_showsTravelerAndCorridor', (tester) async {
    await open(tester);

    expect(_txt('Moussa · Paris → Dakar'), findsOneWidget);
  });

  testWidgets('sheet_card_confirmFails_retryReconfirms_noSecondCreate', (
    tester,
  ) async {
    when(
      () => repository.create(
        'bid-1',
        addedKg: 1,
        items: const {},
        method: BidPaymentMethod.stripe,
      ),
    ).thenAnswer((_) async => _cardCheckout);
    var confirms = 0;
    when(() => repository.confirmAuthorization('bid-1', 'am-1')).thenAnswer((
      _,
    ) async {
      confirms++;
      if (confirms == 1) throw const NetworkException('x');
      return _cashAmendment;
    });
    var authCalls = 0;
    await open(
      tester,
      authorize: (_) async {
        authCalls++;
        return true;
      },
    );
    await addKilos(tester, 2);
    await tester.tap(_txt('Carte'));
    await tester.pumpAndSettle();
    await tester.tap(submit('Bloquer 22,40 € et envoyer'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(submit('Bloquer 22,40 € et envoyer'));
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        any(),
        addedKg: any(named: 'addedKg'),
        items: any(named: 'items'),
        method: any(named: 'method'),
      ),
    ).called(1);
    expect(confirms, 2);
    expect(authCalls, 1);
    expect(presentCalls, 1);
    expect(result, isTrue);
  });
}
