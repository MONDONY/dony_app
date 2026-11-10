import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  late _MockAuthBloc authBloc;
  TravelerStatusOutcome? result;
  var resultSet = false;

  setUpAll(() => registerFallbackValue(_FakeAuthEvent()));

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    authBloc = _MockAuthBloc();
    result = null;
    resultSet = false;
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_user));
    when(() => authBloc.isClosed).thenReturn(false);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<TravelerStatusCubit>(
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
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    double width = 360,
    bool allowLater = true,
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
                  result = await TravelerStatusSheet.show(
                    context,
                    allowLater: allowLater,
                  );
                  resultSet = true;
                },
                child: const Text('ouvrir'),
              ),
            ),
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

  group('la feuille', () {
    testWidgets('deux choix sans clavier ni présélection', (tester) async {
      await open(tester);

      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
      expect(find.text(fr.travelerStatusSheetSubtitle), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionIndividual), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionIndividualBody), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionGpPro), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionGpProBody), findsOneWidget);
      expect(
        find.text(fr.travelerStatusIndividualConfirmation),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DonyRadioGroup<TravelerStatus>), findsNothing);
      verifyNever(() => repository.declareIndividual());
    });

    testWidgets('« Plus tard » dans le pied, jamais dans le contenu défilant', (
      tester,
    ) async {
      await open(tester);

      expect(find.widgetWithText(DonyButton, fr.commonLater), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(DonyButton),
        ),
        findsNothing,
      );
    });

    testWidgets('allowLater: false : pas de « Plus tard »', (tester) async {
      await open(tester, allowLater: false);

      expect(find.widgetWithText(DonyButton, fr.commonLater), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
    });

    testWidgets('« Plus tard » ferme la feuille : résultat « later »', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.widgetWithText(DonyButton, fr.commonLater));
      await tester.pumpAndSettle();

      expect(result, TravelerStatusOutcome.later);
      verifyNever(() => repository.declareIndividual());
      verifyNever(() => authBloc.add(any()));
    });

    testWidgets('fermée d\'un geste : résultat nul', (tester) async {
      await open(tester);

      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      expect(resultSet, isTrue);
      expect(result, isNull);
    });
  });

  group('Particulier', () {
    testWidgets('un tap déclare, ferme la feuille et met le profil à jour', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pumpAndSettle();

      verify(() => repository.declareIndividual()).called(1);
      expect(result, TravelerStatusOutcome.individual);
      // La réponse du PUT est appliquée tout de suite au profil local, puis le
      // profil est rechargé (dans cet ordre).
      final events = verify(() => authBloc.add(captureAny())).captured;
      expect(events, hasLength(2));
      expect(events[0], isA<AuthUserSynced>());
      expect(events[1], isA<AuthProfileRefreshRequested>());
      final synced = events[0] as AuthUserSynced;
      expect(synced.user.travelerStatus, TravelerStatus.individual);
    });

    testWidgets('refus du back : la feuille reste ouverte et se réactive', (
      tester,
    ) async {
      when(() => repository.declareIndividual()).thenThrow(Exception('boom'));
      await open(tester);

      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(resultSet, isFalse);
      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'traveler_status_declare_failed',
          properties: {'status': 'INDIVIDUAL', 'error_code': 'unknown'},
        ),
      ).called(1);

      // Un nouvel essai part.
      when(() => repository.declareIndividual()).thenAnswer(
        (_) async => TravelerStatusDeclaration(
          status: TravelerStatus.individual,
          declaredAt: DateTime.utc(2026, 11),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pumpAndSettle();
      expect(result, TravelerStatusOutcome.individual);
    });
  });

  group('GP Pro', () {
    testWidgets('un tap ouvre le formulaire GP Pro, rien n\'est déclaré', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text(fr.travelerStatusOptionGpPro));
      await tester.pumpAndSettle();

      expect(find.text('formulaire GP Pro'), findsOneWidget);
      verifyNever(() => repository.declareIndividual());

      // Retour du formulaire : résultat « gpPro », profil rechargé.
      await tester.tap(find.text('formulaire GP Pro'));
      await tester.pumpAndSettle();
      expect(result, TravelerStatusOutcome.gpPro);
      verify(
        () => authBloc.add(any(that: isA<AuthProfileRefreshRequested>())),
      ).called(1);
    });
  });

  group('360 dp, français et anglais', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      final l = locale == AppL10n.fr ? fr : en;
      final code = locale.languageCode;

      testWidgets('[$code] sans exception, « Plus tard » sur une ligne', (
        tester,
      ) async {
        await open(tester, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.text(l.travelerStatusSheetTitle), findsOneWidget);
        final later = find.widgetWithText(DonyButton, l.commonLater);
        expect(later, findsOneWidget);
        expect(tester.getSize(later).height, lessThan(64));
      });
    }

    testWidgets('anglais : textes traduits', (tester) async {
      await open(tester, locale: AppL10n.en);
      expect(find.text(en.travelerStatusSheetTitle), findsOneWidget);
      expect(en.travelerStatusSheetTitle, isNot(fr.travelerStatusSheetTitle));
      expect(find.text(en.travelerStatusOptionGpPro), findsOneWidget);
    });

    testWidgets('aucun tiret cadratin dans les textes de la feuille', (
      tester,
    ) async {
      for (final l in [fr, en]) {
        for (final text in [
          l.travelerStatusSheetTitle,
          l.travelerStatusSheetSubtitle,
          l.travelerStatusOptionIndividualBody,
          l.travelerStatusOptionGpProBody,
          l.travelerStatusIndividualConfirmation,
        ]) {
          expect(text.contains('—'), isFalse, reason: text);
        }
      }
    });
  });
}
