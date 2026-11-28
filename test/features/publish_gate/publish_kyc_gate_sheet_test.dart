import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/features/publish_gate/bloc/publish_kyc_gate_cubit.dart';
import 'package:dony/features/publish_gate/presentation/publish_kyc_gate_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockKycBloc kycBloc;
  late _MockAuthBloc authBloc;
  late _MockAnalytics analytics;
  late StreamController<KycState> states;

  setUp(() async {
    DonySnackbar.clearDedup();
    await GetIt.I.reset();
    states = StreamController<KycState>.broadcast();
    kycBloc = _MockKycBloc();
    whenListen(kycBloc, states.stream, initialState: const KycInitial());
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );
    // La feuille de statut (PENDING) prend son propre bloc.
    final statusBloc = _MockKycBloc();
    whenListen(
      statusBloc,
      const Stream<KycState>.empty(),
      initialState: const KycLoading(),
    );
    GetIt.I.registerFactory<KycBloc>(() => statusBloc);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await states.close();
    await GetIt.I.reset();
  });

  Future<PublishKycGateCubit> gateFor({
    KycGateSubject subject = KycGateSubject.trip,
    String kycStatus = 'NOT_STARTED',
    bool saved = true,
  }) async {
    final gate = PublishKycGateCubit(subject: subject, analytics: analytics);
    addTearDown(gate.close);
    await gate.open(kycStatus: kycStatus, saveDraft: () async => saved);
    return gate;
  }

  Future<void> pump(
    WidgetTester tester,
    PublishKycGateCubit gate, {
    Locale locale = AppL10n.fr,
    String? returnTo = kycResumeTripRoute,
    double width = 1170,
    double ratio = 3,
    Future<void> Function(String url)? onVerificationReady,
  }) async {
    tester.view.physicalSize = Size(width, 2532);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<KycBloc>.value(value: kycBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => PublishKycGateSheet.show(
                      ctx,
                      gate: gate,
                      returnTo: returnTo,
                      onVerificationReady: onVerificationReady,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/kyc/verify',
          builder: (_, s) => Scaffold(body: Text('verify ${s.uri} ${s.extra}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('identité à vérifier', () {
    testWidgets('trajet gardé : titre, texte, Vérifier et Plus tard', (
      tester,
    ) async {
      await pump(tester, await gateFor());
      expect(find.text('Dernière étape : vérifiez votre identité'), findsOne);
      expect(
        find.text(
          'Votre trajet est enregistré. Vérifiez votre identité (environ 2 '
          'minutes) puis publiez-le. Les expéditeurs voient que vous êtes '
          'vérifié : c\'est ce qui les met en confiance.',
        ),
        findsOne,
      );
      expect(
        find.widgetWithText(DonyButton, 'Vérifier mon identité'),
        findsOne,
      );
      expect(find.widgetWithText(DonyButton, 'Plus tard'), findsOne);
    });

    testWidgets('demande gardée : texte au féminin', (tester) async {
      await pump(
        tester,
        await gateFor(subject: KycGateSubject.packageRequest),
        returnTo: kycResumeParcelRoute,
      );
      expect(
        find.text(
          'Votre demande est enregistrée. Vérifiez votre identité (environ 2 '
          'minutes) puis publiez-la. Les voyageurs voient que vous êtes '
          'vérifié : c\'est ce qui les met en confiance.',
        ),
        findsOne,
      );
    });

    testWidgets('saisie non gardée : texte sans « enregistré »', (
      tester,
    ) async {
      await pump(tester, await gateFor(saved: false));
      expect(
        find.text(
          'Vérifiez votre identité (environ 2 minutes) puis publiez. Les '
          'autres membres voient que vous êtes vérifié : c\'est ce qui les '
          'met en confiance.',
        ),
        findsOne,
      );
    });

    testWidgets('REJECTED : ligne sur la vérification précédente', (
      tester,
    ) async {
      await pump(tester, await gateFor(kycStatus: 'REJECTED'));
      expect(find.textContaining('précédente vérification'), findsOne);
    });

    testWidgets('Vérifier : session demandée, tracé, puis /kyc/verify avec '
        'le retour vers le formulaire rempli', (tester) async {
      await pump(tester, await gateFor());
      verify(() => kycBloc.add(const KycReset())).called(1);

      await tester.tap(find.text('Vérifier mon identité'));
      await tester.pump();
      verify(() => kycBloc.add(const KycSessionRequested())).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.publishKycGateVerifyTapped,
          properties: {'role': 'traveler'},
        ),
      ).called(1);

      states.add(
        const KycSessionCreated(
          stripeUrl: 'https://verify.didit.me/s',
          sessionId: 's1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final page = tester.widget<Text>(find.textContaining('verify /kyc'));
      final uri = Uri.parse(page.data!.split(' ')[1]);
      expect(uri.queryParameters[kycReturnParam], kycResumeTripRoute);
      expect(page.data, endsWith(' https://verify.didit.me/s'));
    });

    testWidgets('session en cours : bouton bloqué', (tester) async {
      await pump(tester, await gateFor());
      states.add(const KycLoading());
      await tester.pump();
      final button = tester.widget<DonyButton>(
        find.byKey(const Key('publish-kyc-gate-verify')),
      );
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
    });

    testWidgets('503 session-creation-failed : message d\'indisponibilité, '
        'saisie enregistrée, feuille gardée', (tester) async {
      await pump(tester, await gateFor());
      states.add(
        const KycError(
          ServiceUnavailableException(
            'Impossible de créer la session de vérification',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(
          'La vérification d\'identité est momentanément indisponible. '
          'Votre saisie est enregistrée : réessayez dans quelques minutes.',
        ),
        findsOne,
      );
      expect(find.textContaining('Impossible de créer'), findsNothing);
      expect(find.text('Dernière étape : vérifiez votre identité'), findsOne);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('Plus tard : referme, rien ne part', (tester) async {
      await pump(tester, await gateFor());
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(
        find.text('Dernière étape : vérifiez votre identité'),
        findsNothing,
      );
      verifyNever(() => kycBloc.add(const KycSessionRequested()));
    });
  });

  group('vérification en cours (PENDING)', () {
    testWidgets('explique qu\'on préviendra et que le trajet attend', (
      tester,
    ) async {
      await pump(tester, await gateFor(kycStatus: 'PENDING'));
      expect(find.text('Vérification en cours'), findsOne);
      expect(
        find.text(
          'Nous vérifions votre identité et vous préviendrons dès que c\'est '
          'fait. Votre trajet est enregistré : il vous attend pour être '
          'publié.',
        ),
        findsOne,
      );
      verifyNever(() => kycBloc.add(const KycReset()));
    });

    testWidgets('demande, sans brouillon : textes adaptés', (tester) async {
      await pump(
        tester,
        await gateFor(
          subject: KycGateSubject.packageRequest,
          kycStatus: 'PENDING',
        ),
      );
      expect(find.textContaining('Votre demande est enregistrée'), findsOne);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      await pump(tester, await gateFor(kycStatus: 'PENDING', saved: false));
      expect(
        find.text(
          'Nous vérifions votre identité et vous préviendrons dès que c\'est '
          'fait.',
        ),
        findsOne,
      );
    });

    testWidgets('« Voir ma vérification » ouvre le statut et trace', (
      tester,
    ) async {
      await pump(tester, await gateFor(kycStatus: 'PENDING'));
      await tester.tap(find.text('Voir ma vérification'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Vérification en cours'), findsNothing);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.publishKycGateVerifyTapped,
          properties: {'role': 'traveler'},
        ),
      ).called(1);
      await tester.pump(const Duration(minutes: 6));
    });
  });

  group('demande sur un trajet (sender_bid)', () {
    testWidgets('texte « demande prête », envoi plutôt que publication', (
      tester,
    ) async {
      await pump(
        tester,
        await gateFor(subject: KycGateSubject.bid),
        returnTo: null,
      );
      expect(find.text('Dernière étape : vérifiez votre identité'), findsOne);
      expect(
        find.text(
          'Votre demande est prête. Vérifiez votre identité (environ 2 '
          'minutes) puis envoyez-la.',
        ),
        findsOne,
      );
    });

    testWidgets('anglais', (tester) async {
      await pump(
        tester,
        await gateFor(subject: KycGateSubject.bid),
        returnTo: null,
        locale: AppL10n.en,
      );
      expect(
        find.text(
          'Your request is ready. Verify your identity (about 2 minutes), '
          'then send it.',
        ),
        findsOne,
      );
    });

    testWidgets('PENDING : la demande reste prête sur l\'écran', (
      tester,
    ) async {
      await pump(
        tester,
        await gateFor(subject: KycGateSubject.bid, kycStatus: 'PENDING'),
        returnTo: null,
      );
      expect(find.text('Vérification en cours'), findsOne);
      expect(
        find.text(
          'Nous vérifions votre identité et vous préviendrons dès que c\'est '
          'fait. Votre demande reste prête sur cet écran : vous l\'enverrez '
          'dès que votre identité sera vérifiée.',
        ),
        findsOne,
      );
    });

    testWidgets('session créée : l\'appelant ouvre la vérification, pas de '
        'go qui viderait la pile', (tester) async {
      String? opened;
      await pump(
        tester,
        await gateFor(subject: KycGateSubject.bid),
        returnTo: null,
        onVerificationReady: (url) async => opened = url,
      );
      await tester.tap(find.text('Vérifier mon identité'));
      await tester.pump();
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.publishKycGateVerifyTapped,
          properties: {'role': 'sender_bid'},
        ),
      ).called(1);
      states.add(
        const KycSessionCreated(
          stripeUrl: 'https://verify.didit.me/b',
          sessionId: 's2',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opened, 'https://verify.didit.me/b');
      expect(find.textContaining('verify /kyc'), findsNothing);
    });
  });

  group('libellés sur une ligne à 360 dp', () {
    // Vraies polices de l'app : la police de test par défaut donne à chaque
    // caractère la largeur d'un cadratin et ne dit rien de la largeur réelle.
    setUpAll(() async {
      for (final (family, files) in [
        ('PlusJakartaSans', ['Regular', 'Medium', 'SemiBold', 'Bold']),
        ('HankenGrotesk', ['SemiBold', 'Bold', 'ExtraBold']),
      ]) {
        final loader = FontLoader(family);
        for (final f in files) {
          final bytes = File('assets/fonts/$family-$f.ttf').readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
        await loader.load();
      }
    });

    /// Rapport largeur disponible / largeur du libellé : 1 ou plus, le texte
    /// n'est pas rétréci par le FittedBox de DonyButton.
    double scaleOf(WidgetTester tester, Key key, String label) {
      final button = find.byKey(key);
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final (locale, verify, status, later) in [
      (
        AppL10n.fr,
        'Vérifier mon identité',
        'Voir ma vérification',
        'Plus tard',
      ),
      (AppL10n.en, 'Verify my identity', 'View my verification', 'Later'),
    ]) {
      testWidgets('${locale.languageCode} : Vérifier / Plus tard', (
        tester,
      ) async {
        await pump(
          tester,
          await gateFor(),
          locale: locale,
          width: 360,
          ratio: 1,
        );
        expect(tester.takeException(), isNull);
        expect(
          scaleOf(tester, const Key('publish-kyc-gate-verify'), verify),
          greaterThanOrEqualTo(1),
        );
        expect(
          scaleOf(tester, const Key('publish-kyc-gate-later'), later),
          greaterThanOrEqualTo(1),
        );
      });

      testWidgets('${locale.languageCode} : Voir ma vérification', (
        tester,
      ) async {
        await pump(
          tester,
          await gateFor(kycStatus: 'PENDING'),
          locale: locale,
          width: 360,
          ratio: 1,
        );
        expect(tester.takeException(), isNull);
        expect(
          scaleOf(tester, const Key('publish-kyc-gate-status'), status),
          greaterThanOrEqualTo(1),
        );
      });
    }
  });
}
