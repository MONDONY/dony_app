// FLUTTER-E9 : un voyageur remplissait les 3 étapes de « Créer le trajet pour
// cette demande » et n'apprenait qu'à l'envoi (422
// `payment-method/card-capability-required`) que le colis n'acceptait que la
// carte, qu'il ne pouvait pas encaisser. La fiche le prévient désormais en
// amont, et son CTA ouvre la feuille d'explication au lieu du formulaire.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/currency_test_doubles.dart';
import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/stripe_account_test_doubles.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockPriceEstimationRepository extends Mock
    implements PriceEstimationRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

const _cardOnly = {PaymentMethod.stripe};
const _cardOrCash = {PaymentMethod.stripe, PaymentMethod.cash};

PackageRequest _req({
  bool negotiable = true,
  Set<PaymentMethod> methods = _cardOnly,
  String? viewerThreadId,
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: PackageRequestStatus.open,
  createdAt: DateTime(2026, 6),
  negotiable: negotiable,
  targetPriceEur: 35,
  acceptedPaymentMethods: methods,
  viewerThreadId: viewerThreadId,
);

void main() {
  late _MockNegotiationBloc negoBloc;
  late _MockPriceEstimationRepository priceRepo;
  late _MockAnnouncementRepository announcementRepo;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    negoBloc = _MockNegotiationBloc();
    priceRepo = _MockPriceEstimationRepository();
    announcementRepo = _MockAnnouncementRepository();
    when(() => negoBloc.state).thenReturn(const NegotiationInitial());
    when(
      () => negoBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
    when(
      () => priceRepo.estimate(
        from: any(named: 'from'),
        to: any(named: 'to'),
        weight: any(named: 'weight'),
        currency: any(named: 'currency'),
      ),
    ).thenThrow(Exception('no estimate'));
    when(() => announcementRepo.getMyAnnouncements()).thenAnswer(
      (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
    );
    getIt
      ..registerFactory<NegotiationBloc>(() => negoBloc)
      ..registerLazySingleton<PriceEstimationRepository>(() => priceRepo)
      ..registerLazySingleton<AnnouncementRepository>(() => announcementRepo);
  });

  tearDown(() {
    getIt
      ..unregister<NegotiationBloc>()
      ..unregister<PriceEstimationRepository>()
      ..unregister<AnnouncementRepository>();
  });

  Future<void> pump(
    WidgetTester tester,
    PackageRequest request, {
    CardCapabilityGap? gap,
    StripeAccountState? stripeState,
    String? profileCountry,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PackageRequestPublicDetailBody(
              request: request,
              currentUserId: 'traveler-1',
              cardCapabilityGap: gap,
              profileCountry: profileCountry,
            ),
          ),
        ),
        GoRoute(
          path: '/connect/onboarding/intro',
          builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/settings/preferences',
          builder: (_, _) => const Scaffold(body: Text('PREFS')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<StripeAccountBloc>.value(
            value: stubStripeAccountBloc(
              state:
                  stripeState ??
                  const StripeAccountReady(
                    ConnectAccountStatus(status: 'NOT_CREATED'),
                  ),
            ),
          ),
          BlocProvider<BusinessPrefsBloc>.value(
            value: stubBusinessPrefsBloc(
              state: const BusinessPrefsState(country: 'FR'),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('colis carte seule, voyageur sans carte', () {
    testWidgets('négociable : avertissement visible, CTA → feuille, pas le '
        'formulaire', (tester) async {
      await pump(tester, _req(), gap: CardCapabilityGap.activatable);

      expect(find.byKey(const Key('card-only-warning')), findsOneWidget);
      expect(
        find.text(
          'Ce colis n\'accepte que la carte : active le paiement carte pour '
          'le proposer.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('propose-trip')));
      await tester.pumpAndSettle();

      expect(find.text('Paiement carte requis'), findsOneWidget);
      expect(find.text('Faire une offre'), findsNothing);

      await tester.tap(find.byKey(const Key('activate-card-payment-cta')));
      await tester.pumpAndSettle();
      expect(find.text('ONBOARDING'), findsOneWidget);
    });

    testWidgets('prix ferme : CTA → feuille, pas le formulaire', (
      tester,
    ) async {
      await pump(
        tester,
        _req(negotiable: false),
        gap: CardCapabilityGap.activatable,
      );

      expect(find.byKey(const Key('card-only-warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('take-firm-price')));
      await tester.pumpAndSettle();

      expect(find.text('Paiement carte requis'), findsOneWidget);
      expect(find.text('Prendre ce colis'), findsNothing);
    });

    testWidgets('pays non renseigné : avertissement « renseigne ton pays »', (
      tester,
    ) async {
      await pump(tester, _req(), gap: CardCapabilityGap.countryMissing);

      expect(
        find.textContaining('renseigne ton pays de résidence'),
        findsOneWidget,
      );
    });

    testWidgets(
      'pays non couvert : avertissement sans consigne d\'activation',
      (tester) async {
        await pump(
          tester,
          _req(),
          gap: CardCapabilityGap.countryUnsupported,
          stripeState: stripeCountryUnavailableState,
        );

        expect(
          find.textContaining('dépend du pays de résidence'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('propose-trip')));
        await tester.pumpAndSettle();
        expect(
          find.text('Votre pays de résidence (profil) : France'),
          findsOneWidget,
        );
      },
    );

    testWidgets('pays de résidence non couvert : nommé, lien vers son réglage '
        '(FLUTTER-EE)', (tester) async {
      await pump(
        tester,
        _req(),
        gap: CardCapabilityGap.countryUnsupported,
        stripeState: stripeCountryUnavailableState,
        profileCountry: 'CI',
      );

      expect(
        find.text(
          'Ce colis n\'accepte que la carte. L\'encaissement par carte '
          'dépend du pays de résidence indiqué dans votre profil (Côte '
          'd\'Ivoire), et non du pays où vous vous trouvez. Stripe ne le '
          'permet pas encore depuis ce pays.',
        ),
        findsOneWidget,
      );
      final link = find.byKey(const Key('card-only-warning-country-link'));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('PREFS'), findsOneWidget);
    });

    testWidgets('pays non renseigné : lien « Renseigner mon pays »', (
      tester,
    ) async {
      await pump(tester, _req(), gap: CardCapabilityGap.countryMissing);

      expect(find.text('Renseigner mon pays'), findsOneWidget);
    });

    testWidgets('activation possible : pas de lien vers le pays', (
      tester,
    ) async {
      await pump(tester, _req(), gap: CardCapabilityGap.activatable);

      expect(
        find.byKey(const Key('card-only-warning-country-link')),
        findsNothing,
      );
    });

    testWidgets('offre déjà en cours : pas d\'avertissement', (tester) async {
      await pump(
        tester,
        _req(viewerThreadId: 't-1'),
        gap: CardCapabilityGap.activatable,
      );

      expect(find.byKey(const Key('card-only-warning')), findsNothing);
    });
  });

  testWidgets(
    'voyageur qui encaisse par carte (gap null) → formulaire normal',
    (tester) async {
      await pump(tester, _req());

      expect(find.byKey(const Key('card-only-warning')), findsNothing);
      await tester.tap(find.byKey(const Key('propose-trip')));
      await tester.pumpAndSettle();

      expect(find.text('Faire une offre'), findsOneWidget);
      expect(find.text('Paiement carte requis'), findsNothing);
    },
  );

  testWidgets('colis acceptant aussi les espèces → formulaire normal', (
    tester,
  ) async {
    await pump(
      tester,
      _req(methods: _cardOrCash),
      gap: CardCapabilityGap.activatable,
    );

    expect(find.byKey(const Key('card-only-warning')), findsNothing);
    await tester.tap(find.byKey(const Key('propose-trip')));
    await tester.pumpAndSettle();

    expect(find.text('Faire une offre'), findsOneWidget);
    expect(find.text('Paiement carte requis'), findsNothing);
  });

  testWidgets('anglais : avertissement traduit', (tester) async {
    useEnglish();
    await pump(tester, _req(), gap: CardCapabilityGap.activatable);

    expect(
      find.text(
        'This parcel only accepts card payment: activate card payments to '
        'offer your trip.',
      ),
      findsOneWidget,
    );
  });
}
