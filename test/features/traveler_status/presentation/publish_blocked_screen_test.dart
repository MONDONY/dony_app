import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/publish_blocked_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements TravelerStatusRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _user = UserModel(
  id: 'u1',
  firstName: 'Moussa',
  lastName: 'Koné',
  email: 'moussa@test.com',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

PublishingEligibility _eligibility(
  PublishingReason reason, {
  int? limit = 4,
  DateTime? resetsOn,
  TravelerStatus? status,
}) => PublishingEligibility(
  allowed: false,
  reason: reason,
  limit: limit,
  used: limit ?? 0,
  resetsOn: resetsOn ?? DateTime(2026, 12),
  travelerStatus: status,
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  late _MockAuthBloc authBloc;
  bool? popped;
  var poppedSet = false;

  setUpAll(() async {
    registerFallbackValue(_FakeAuthEvent());
    await initializeDateFormatting();
  });

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    authBloc = _MockAuthBloc();
    popped = null;
    poppedSet = false;
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_user));
    when(() => authBloc.isClosed).thenReturn(false);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerSingleton<TravelerStatusRepository>(repository)
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerFactory<TravelerStatusCubit>(
        () => TravelerStatusCubit(repository, analytics),
      );
    when(() => repository.declareIndividual()).thenAnswer(
      (_) async => TravelerStatusDeclaration(
        status: TravelerStatus.individual,
        declaredAt: DateTime.utc(2026, 11),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> open(
    WidgetTester tester,
    PublishingEligibility eligibility, {
    Locale locale = AppL10n.fr,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped = await context.push<bool>(
                    '/blocked',
                    extra: eligibility,
                  );
                  poppedSet = true;
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/blocked',
          builder: (context, state) => PublishBlockedScreen(
            eligibility: state.extra! as PublishingEligibility,
          ),
        ),
        GoRoute(
          path: '/profile/gp-pro',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: context.pop,
                child: const Text('formulaire GP Pro'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('statut requis (limite atteinte, aucune réponse)', () {
    testWidgets('titre avec la limite, deux choix, pas de « Plus tard »', (
      tester,
    ) async {
      await open(tester, _eligibility(PublishingReason.statusRequired));

      expect(find.text(fr.publishBlockedAppBarTitle), findsOneWidget);
      expect(find.text(fr.publishBlockedStatusTitle(4)), findsOneWidget);
      expect(
        find.text('Limite de 4 trajets atteinte ce mois-ci'),
        findsOneWidget,
      );
      expect(find.text(fr.publishBlockedStatusBody), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionIndividual), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionGpPro), findsOneWidget);
      expect(find.text(fr.commonLater), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('limite inconnue (403 sans chiffre) : titre sans nombre', (
      tester,
    ) async {
      await open(
        tester,
        _eligibility(PublishingReason.statusRequired, limit: null),
      );
      expect(find.text(fr.publishBlockedStatusTitleNoLimit), findsOneWidget);
    });

    testWidgets('Particulier : déclaré, puis « vous ne pouvez plus créer de '
        'trajet »', (tester) async {
      await open(tester, _eligibility(PublishingReason.statusRequired));

      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pumpAndSettle();

      verify(() => repository.declareIndividual()).called(1);
      expect(find.text(fr.publishBlockedLimitTitle), findsOneWidget);
      expect(find.text(fr.publishBlockedStatusTitle(4)), findsNothing);
      verify(() => authBloc.add(any(that: isA<AuthUserSynced>()))).called(1);
    });

    testWidgets('refus du back : on reste sur le choix', (tester) async {
      when(() => repository.declareIndividual()).thenThrow(Exception('boom'));
      await open(tester, _eligibility(PublishingReason.statusRequired));

      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(fr.publishBlockedStatusTitle(4)), findsOneWidget);
      expect(find.text(fr.publishBlockedLimitTitle), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    });

    testWidgets(
      'GP Pro : ouvre le formulaire, puis lit « en cours d\'examen »',
      (tester) async {
        when(() => repository.checkEligibility()).thenAnswer(
          (_) async => (
            eligibility: _eligibility(PublishingReason.gpProPending),
            failureCode: null,
          ),
        );
        await open(tester, _eligibility(PublishingReason.statusRequired));

        await tester.tap(find.text(fr.travelerStatusOptionGpPro));
        await tester.pumpAndSettle();
        expect(find.text('formulaire GP Pro'), findsOneWidget);
        verifyNever(() => repository.declareIndividual());

        await tester.tap(find.text('formulaire GP Pro'));
        await tester.pumpAndSettle();

        expect(find.text(fr.publishBlockedPendingTitle), findsOneWidget);
      },
    );
  });

  group('limite atteinte (particulier)', () {
    testWidgets('texte, date de reprise, « Devenir GP Pro » et « Fermer »', (
      tester,
    ) async {
      await open(
        tester,
        _eligibility(
          PublishingReason.limitReached,
          status: TravelerStatus.individual,
        ),
      );

      expect(find.text(fr.publishBlockedLimitTitle), findsOneWidget);
      expect(find.text(fr.publishBlockedLimitBody(4)), findsOneWidget);
      expect(find.textContaining('décembre'), findsOneWidget);
      expect(find.text(fr.publishBlockedBecomeGpPro), findsOneWidget);
      expect(
        find.widgetWithText(DonyButton, fr.publishBlockedBecomeGpProCta),
        findsOneWidget,
      );
      expect(find.widgetWithText(DonyButton, fr.commonClose), findsOneWidget);
    });

    testWidgets('le premier du mois s\'écrit « 1er décembre » en français', (
      tester,
    ) async {
      await open(tester, _eligibility(PublishingReason.limitReached));
      expect(
        find.text('Vous pourrez de nouveau publier à partir du 1er décembre.'),
        findsOneWidget,
      );
      expect(find.textContaining('du 1 décembre'), findsNothing);
    });

    testWidgets('le premier du mois s\'écrit « December 1st » en anglais', (
      tester,
    ) async {
      await open(
        tester,
        _eligibility(PublishingReason.limitReached),
        locale: AppL10n.en,
      );
      expect(
        find.text('You will be able to publish again from December 1st.'),
        findsOneWidget,
      );
    });

    testWidgets('un autre jour garde le format courant', (tester) async {
      await open(
        tester,
        _eligibility(
          PublishingReason.limitReached,
          resetsOn: DateTime(2026, 12, 15),
        ),
      );
      expect(
        find.text('Vous pourrez de nouveau publier à partir du 15 décembre.'),
        findsOneWidget,
      );
    });

    testWidgets('sans limite ni date (403 seul) : phrases de repli', (
      tester,
    ) async {
      await open(
        tester,
        const PublishingEligibility(
          allowed: false,
          reason: PublishingReason.limitReached,
        ),
      );

      expect(find.text(fr.publishBlockedLimitTitle), findsOneWidget);
      expect(find.text(fr.publishBlockedResumeNextMonth), findsOneWidget);
    });

    testWidgets('« Fermer » revient sans autorisation', (tester) async {
      await open(tester, _eligibility(PublishingReason.limitReached));

      await tester.tap(find.widgetWithText(DonyButton, fr.commonClose));
      await tester.pumpAndSettle();

      expect(poppedSet, isTrue);
      expect(popped, isNot(true));
    });

    testWidgets('« Devenir GP Pro » ouvre le formulaire', (tester) async {
      when(() => repository.checkEligibility()).thenAnswer(
        (_) async => (
          eligibility: _eligibility(PublishingReason.limitReached),
          failureCode: null,
        ),
      );
      await open(tester, _eligibility(PublishingReason.limitReached));

      await tester.tap(
        find.widgetWithText(DonyButton, fr.publishBlockedBecomeGpProCta),
      );
      await tester.pumpAndSettle();

      expect(find.text('formulaire GP Pro'), findsOneWidget);
    });
  });

  group('demande GP Pro en cours d\'examen', () {
    testWidgets('texte et boutons', (tester) async {
      await open(tester, _eligibility(PublishingReason.gpProPending));

      expect(find.text(fr.publishBlockedPendingTitle), findsOneWidget);
      expect(find.text(fr.publishBlockedPendingBody), findsOneWidget);
      expect(
        find.widgetWithText(DonyButton, fr.publishBlockedPendingCta),
        findsOneWidget,
      );
      expect(find.widgetWithText(DonyButton, fr.commonClose), findsOneWidget);
    });

    testWidgets('validation entre-temps : l\'écran rend la main (vrai)', (
      tester,
    ) async {
      when(() => repository.checkEligibility()).thenAnswer(
        (_) async => (eligibility: PublishingEligibility.ok, failureCode: null),
      );
      await open(tester, _eligibility(PublishingReason.gpProPending));

      await tester.tap(
        find.widgetWithText(DonyButton, fr.publishBlockedPendingCta),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();

      expect(poppedSet, isTrue);
      expect(popped, isTrue);
    });
  });

  group('plus rien ne bloque', () {
    testWidgets('la face « en cours d\'examen » ne se dessine pas', (
      tester,
    ) async {
      await open(
        tester,
        const PublishingEligibility(allowed: true, reason: PublishingReason.ok),
      );

      expect(find.text(fr.publishBlockedPendingTitle), findsNothing);
      expect(find.text(fr.publishBlockedLimitTitle), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('360 dp, français et anglais, sans exception', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      final l = locale == AppL10n.fr ? fr : en;
      final code = locale.languageCode;
      for (final reason in [
        PublishingReason.statusRequired,
        PublishingReason.limitReached,
        PublishingReason.gpProPending,
      ]) {
        testWidgets('[$code] ${reason.wire}', (tester) async {
          await open(tester, _eligibility(reason), locale: locale);

          expect(tester.takeException(), isNull);
          expect(find.text(l.publishBlockedAppBarTitle), findsOneWidget);
          // Les libellés de boutons tiennent sur une ligne.
          for (final button in tester.widgetList<DonyButton>(
            find.byType(DonyButton),
          )) {
            final size = tester.getSize(find.byWidget(button));
            expect(size.height, lessThan(64), reason: button.label);
          }
        });
      }
    }
  });
}
