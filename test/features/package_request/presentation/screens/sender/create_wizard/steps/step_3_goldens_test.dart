// Captures de l'étape 3 « Le prix » à 360 x 800, en français puis en anglais,
// pour chacun des 10 états de la maquette
// `sorties/maquettes/demande_etape3.html`.
//
// Génération (les images de référence sont celles du rendu courant) :
//   flutter test --update-goldens \
//     test/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_goldens_test.dart
//
// Tagués `golden` : exclus de la CI (rendu dépendant de la plateforme).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

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

const _base = PackageRequestFormState(
  currentStep: 2,
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  weightKg: 4,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: ['Vêtements & tissus'],
  currency: SupportedCurrency.eur,
);

void main() {
  late _MockRepo repo;

  setUpAll(() async {
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
  });

  setUp(() {
    repo = _MockRepo();
    useTestCommissionGrid();
    when(
      () => repo.quote(
        any(),
        promoCode: any(named: 'promoCode'),
        currency: any(named: 'currency'),
        transportMode: any(named: 'transportMode'),
      ),
    ).thenAnswer((_) => Future.error(Exception('pas de devis')));
    getIt.registerSingleton<PackageRequestRepository>(repo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Coque de substitution : barre du haut, barre de progression et barre
  /// d'action dessinées comme sur la maquette (la vraie coque vit dans
  /// l'assistant et dépend de ses injections).
  Widget shell({
    required Widget body,
    required String title,
    bool primary = false,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: cs.surfaceContainerLowest,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  color: cs.surface,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 9),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          title,
                          style: tt.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: cs.primary, width: 1.5),
                        ),
                        child: Text(
                          '3 / 3',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline),
              Expanded(child: body),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.primary, width: 1.5),
                        ),
                        child: Text(
                          context.l10n.commonBack,
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primary ? cs.primary : const Color(0xFFBFD2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${context.l10n.requestCreatePreviewButton} →',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<PackageRequestFormBloc> pumpState(
    WidgetTester tester,
    PackageRequestFormState seed, {
    bool? mobileMoneyAccountActive,
    String? title,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(720, 1600)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final bloc = PackageRequestFormBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
    )..add(FormDraftRestored(seed));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<PackageRequestFormBloc>.value(value: bloc),
            BlocProvider(
              create: (_) => PackageRequestPhotosCubit(
                repo,
                makeDisabledAnalytics(MockAnalyticsBackend()),
              ),
            ),
          ],
          child: Builder(
            builder: (context) => shell(
              title: title ?? context.l10n.requestCreateStepTitleBudget,
              body: Step3RecapBudget(
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
    return bloc;
  }

  Future<void> golden(WidgetTester tester, String name, bool english) async {
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/etape3_${name}_${english ? 'en' : 'fr'}.png'),
    );
  }

  for (final english in [false, true]) {
    final lang = english ? 'en' : 'fr';

    group('étape 3 ($lang)', () {
      setUp(() {
        if (english) {
          final previous = Intl.defaultLocale;
          Intl.defaultLocale = 'en';
          addTearDown(() => Intl.defaultLocale = previous);
        }
      });

      testWidgets('1 ouverture (euro)', (tester) async {
        await pumpState(tester, _base);
        await golden(tester, '1_ouverture', english);
      });

      testWidgets('2 changer la devise', (tester) async {
        await pumpState(tester, _base);
        await tester.tap(
          find.byKey(const Key('package-request-currency-selector-row')),
        );
        await tester.pumpAndSettle();
        await golden(tester, '2_changer_devise', english);
      });

      testWidgets('3 devise F CFA', (tester) async {
        await pumpState(
          tester,
          _base.copyWith(
            currency: SupportedCurrency.xof,
            acceptedPaymentMethods: {PaymentMethod.mobileMoney},
            totalBudgetEur: 15000,
          ),
          mobileMoneyAccountActive: true,
        );
        await golden(tester, '3_cfa', english);
      });

      testWidgets('4 prix au kilo', (tester) async {
        await pumpState(tester, _base.copyWith(totalBudgetEur: 20));
        await tester.tap(find.byKey(const Key('price-basis-per-kilo')));
        await tester.pumpAndSettle();
        await golden(tester, '4_prix_au_kilo', english);
      });

      testWidgets('5 je fixe mon prix', (tester) async {
        await pumpState(
          tester,
          _base.copyWith(negotiable: false, totalBudgetEur: 45),
        );
        await golden(tester, '5_prix_ferme', english);
      });

      testWidgets('6 prix trop bas', (tester) async {
        await pumpState(tester, _base);
        await tester.enterText(
          find.byKey(const Key('total-budget-input')),
          '0,50',
        );
        await tester.pumpAndSettle();
        await golden(tester, '6_prix_trop_bas', english);
      });

      testWidgets('7 mobile money à configurer', (tester) async {
        await pumpState(
          tester,
          _base.copyWith(
            currency: SupportedCurrency.xof,
            acceptedPaymentMethods: {PaymentMethod.mobileMoney},
          ),
          mobileMoneyAccountActive: false,
        );
        await golden(tester, '7_mobile_money', english);
      });

      testWidgets('8 bas de page : promo', (tester) async {
        await pumpState(tester, _base.copyWith(totalBudgetEur: 20));
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        await golden(tester, '8_promo', english);
      });

      testWidgets('9 demande publiée', (tester) async {
        tester.view
          ..physicalSize = const Size(720, 1600)
          ..devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => DonySuccessScreen(
                mascotteType: DonyMascotteType.succes,
                title: context.l10n.requestCreatePublishedTitle,
                subtitle: context.l10n.requestCreatePublishedSubtitle,
                ctaLabel: context.l10n.requestCreateViewRequestCta,
                onCta: () {},
                secondaryLabel: context.l10n.tripPublishSuccessShareCta,
                onSecondary: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await golden(tester, '9_publiee', english);
      });

      testWidgets('10 modification', (tester) async {
        await pumpState(
          tester,
          _base.copyWith(editingRequestId: 'pr-1', totalBudgetEur: 20),
          title: english ? 'Edit the request' : 'Modifier la demande',
        );
        await golden(tester, '10_modification', english);
      });
    });
  }
}
