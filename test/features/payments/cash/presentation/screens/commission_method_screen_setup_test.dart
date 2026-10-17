import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _MockLocalAuth extends Mock implements LocalAuthService {}

class _MockHive extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockErrorReporting extends Mock implements ErrorReportingService {}

class _FakeEvent extends Fake implements CommissionMethodEvent {}

final _l = lookupAppLocalizations(AppL10n.fr);

const _card = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2030,
  expirationStatus: ExpirationStatus.valid,
);

const _stripeChannel = MethodChannel(
  'flutter.stripe/payments',
  JSONMethodCodec(),
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  late _MockBloc bloc;
  late _MockLocalAuth auth;
  late _MockHive hive;
  late _MockBox prefs;
  late _MockErrorReporting reporting;
  late List<String> stripeCalls;

  setUp(() {
    bloc = _MockBloc();
    auth = _MockLocalAuth();
    hive = _MockHive();
    prefs = _MockBox();
    reporting = _MockErrorReporting();
    stripeCalls = [];
    when(() => hive.userPrefs).thenReturn(prefs);
    when(
      () => prefs.get(HiveService.kBiometricEnabled, defaultValue: false),
    ).thenReturn(false);
    when(
      () => prefs.get(HiveService.kCurrencyCode, defaultValue: null),
    ).thenReturn(null);
    when(() => auth.isPinSet()).thenAnswer((_) async => false);
    when(
      () => reporting.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
        statusCode: any(named: 'statusCode'),
        context: any(named: 'context'),
      ),
    ).thenAnswer((_) async {});
    getIt
      ..registerSingleton<LocalAuthService>(auth)
      ..registerSingleton<HiveService>(hive)
      ..registerSingleton<ErrorReportingService>(reporting);
    Stripe.publishableKey = 'pk_test_fake';
    // Le singleton Stripe garde le Future de ses réglages : chaque test
    // (zone FakeAsync distincte) doit le recréer.
    Stripe.instance.markNeedsSettings();
  });

  tearDown(() async {
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_stripeChannel, null);
    await bloc.close();
  });

  /// Simule le canal natif Stripe. [present] décide de la réponse de
  /// `presentPaymentSheet` (`{}` = succès) ; [initError] fait échouer
  /// `initPaymentSheet`.
  void mockStripe({
    Map<String, dynamic> present = const {},
    Map<String, dynamic>? initError,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_stripeChannel, (call) async {
          stripeCalls.add(call.method);
          return switch (call.method) {
            'initPaymentSheet' => initError ?? <dynamic>[],
            'presentPaymentSheet' => present,
            _ => null,
          };
        });
  }

  Map<String, dynamic> stripeError({
    String code = 'Failed',
    String? stripeErrorCode,
    String? type,
  }) => {
    'error': {
      'code': code,
      'message': 'raw sdk message',
      'stripeErrorCode': ?stripeErrorCode,
      'type': ?type,
    },
  };

  Widget host() => MaterialApp.router(
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<CommissionMethodBloc>.value(
            value: bloc,
            child: const CommissionMethodScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (context, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(false);
            });
            return const SizedBox.shrink();
          },
        ),
      ],
    ),
  );

  void startSetup() => whenListen(
    bloc,
    Stream.fromIterable([
      CommissionMethodSetupInProgress('seti_123_secret_abc'),
    ]),
    initialState: CommissionMethodLoaded(_card),
  );

  testWidgets('erreur de chargement : message et « Réessayer » relance', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<CommissionMethodState>.empty(),
      initialState: CommissionMethodError('x'),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text(_l.commissionCardLoadError), findsOneWidget);
    await tester.tap(find.text(_l.commonRetry));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodLoadRequested>())),
    ).called(1);
  });

  testWidgets('état initial : rien n\'est affiché', (tester) async {
    whenListen(
      bloc,
      const Stream<CommissionMethodState>.empty(),
      initialState: CommissionMethodInitial(),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text(_l.commissionCardReplaceButton), findsNothing);
    expect(find.text(_l.commissionCardScreenTitle), findsOneWidget);
  });

  testWidgets('devise hors euro : avis de débit sans plancher de 1 €', (
    tester,
  ) async {
    when(
      () => prefs.get(HiveService.kCurrencyCode, defaultValue: null),
    ).thenReturn('XOF');
    whenListen(
      bloc,
      const Stream<CommissionMethodState>.empty(),
      initialState: CommissionMethodLoaded(_card),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text(_l.commissionCardDebitNotice), findsOneWidget);
  });

  testWidgets(
    'mise en place réussie : feuille Stripe puis SetupCompleted avec l\'id',
    (tester) async {
      mockStripe();
      startSetup();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        stripeCalls,
        containsAllInOrder(['initPaymentSheet', 'presentPaymentSheet']),
      );
      verify(
        () => bloc.add(
          any(
            that: isA<CommissionMethodSetupCompleted>().having(
              (e) => e.paymentMethodId,
              'paymentMethodId',
              'seti_123',
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('PIN refusé : avertissement et SetupCancelled, sans Stripe', (
    tester,
  ) async {
    mockStripe();
    when(() => auth.isPinSet()).thenAnswer((_) async => true);
    startSetup();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(_l.paymentNotConfirmedSnackbar), findsOneWidget);
    expect(stripeCalls, isNot(contains('initPaymentSheet')));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupCancelled>())),
    ).called(1);
  });

  testWidgets('annulation par l\'utilisateur : SetupCancelled sans message', (
    tester,
  ) async {
    mockStripe(present: stripeError(code: 'Canceled'));
    startSetup();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupCancelled>())),
    ).called(1);
    verifyNever(
      () => reporting.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
        statusCode: any(named: 'statusCode'),
        context: any(named: 'context'),
      ),
    );
    expect(find.text(_l.commissionCardAddErrorMessage), findsNothing);
  });

  testWidgets('échec à la présentation : message générique et rapport Sentry', (
    tester,
  ) async {
    mockStripe(present: stripeError(type: 'api_error'));
    startSetup();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(_l.commissionCardAddErrorMessage), findsOneWidget);
    verify(
      () => reporting.report(
        any(),
        operation: 'commission.stripe_setup',
        stackTrace: any(named: 'stackTrace'),
        statusCode: any(named: 'statusCode'),
        context: any(named: 'context'),
      ),
    ).called(1);
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupCancelled>())),
    ).called(1);
  });

  testWidgets('échec à l\'ouverture : feuille indisponible (stripe_init)', (
    tester,
  ) async {
    mockStripe(initError: stripeError());
    startSetup();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(_l.paymentSheetOpenFailed), findsOneWidget);
    expect(stripeCalls, isNot(contains('presentPaymentSheet')));
    verify(
      () => reporting.report(
        any(),
        operation: 'commission.stripe_init',
        stackTrace: any(named: 'stackTrace'),
        statusCode: any(named: 'statusCode'),
        context: any(named: 'context'),
      ),
    ).called(1);
  });
}
