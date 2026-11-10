import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements TravelerStatusRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  late _MockAuthBloc authBloc;
  bool? result;
  var resultSet = false;

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(TravelerStatus.individual);
  });

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    authBloc = _MockAuthBloc();
    result = null;
    resultSet = false;
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.isClosed).thenReturn(false);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<TravelerStatusCubit>(
      () => TravelerStatusCubit(repository, analytics),
    );
    when(
      () => repository.declare(
        status: any(named: 'status'),
        personalUseConfirmed: any(named: 'personalUseConfirmed'),
        businessName: any(named: 'businessName'),
        registrationNumber: any(named: 'registrationNumber'),
        country: any(named: 'country'),
      ),
    ).thenAnswer(
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
    bool required = false,
    Locale locale = AppL10n.fr,
    double width = 360,
    bool allowLater = true,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await TravelerStatusSheet.show(
                    context,
                    required: required,
                    allowLater: allowLater,
                  );
                  resultSet = true;
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  DonyButton button(WidgetTester tester, String label) =>
      tester.widget<DonyButton>(find.widgetWithText(DonyButton, label));

  group('étape 1 : le choix', () {
    testWidgets('rien de présélectionné, « Continuer » grisé', (tester) async {
      await open(tester);

      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionIndividual), findsOneWidget);
      expect(find.text(fr.travelerStatusOptionProfessional), findsOneWidget);
      final group = tester.widget<DonyRadioGroup<TravelerStatus>>(
        find.byType(DonyRadioGroup<TravelerStatus>),
      );
      expect(group.value, isNull);
      expect(button(tester, fr.commonContinue).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Plus tard » visible quand la déclaration est facultative', (
      tester,
    ) async {
      await open(tester);
      expect(find.widgetWithText(DonyButton, fr.commonLater), findsOneWidget);
    });

    testWidgets('« Plus tard » absent quand la déclaration est obligatoire', (
      tester,
    ) async {
      await open(tester, required: true);
      expect(find.widgetWithText(DonyButton, fr.commonLater), findsNothing);
      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
    });

    testWidgets('« Plus tard » ferme la feuille sans déclarer (faux)', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(DonyButton, fr.commonLater));
      await tester.pumpAndSettle();

      expect(resultSet, isTrue);
      expect(result, isFalse);
      expect(find.text(fr.travelerStatusSheetTitle), findsNothing);
      verifyNever(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      );
    });

    testWidgets('allowLater: false (profil) : pas de « Plus tard », sous-titre '
        'inchangé', (tester) async {
      await open(tester, allowLater: false);
      expect(find.widgetWithText(DonyButton, fr.commonLater), findsNothing);
      expect(find.text(fr.travelerStatusSheetSubtitle), findsOneWidget);
      expect(find.text(fr.travelerStatusSheetSubtitleRequired), findsNothing);
    });

    testWidgets('allowLater par défaut : « Plus tard » présent (publication)', (
      tester,
    ) async {
      await open(tester);
      expect(find.widgetWithText(DonyButton, fr.commonLater), findsOneWidget);
    });

    testWidgets('aucun bouton dans le contenu défilant', (tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(DonyButton),
        ),
        findsNothing,
      );
      expect(find.byType(DonyButton), findsWidgets);
    });
  });

  group('particulier', () {
    testWidgets(
      'case à cocher puis « Enregistrer » : déclare et renvoie vrai',
      (tester) async {
        await open(tester);
        await tester.tap(find.text(fr.travelerStatusOptionIndividual));
        await tester.pumpAndSettle();
        expect(button(tester, fr.commonContinue).onPressed, isNotNull);
        await tester.tap(find.widgetWithText(DonyButton, fr.commonContinue));
        await tester.pumpAndSettle();

        expect(find.text(fr.travelerStatusIndividualTitle), findsOneWidget);
        expect(find.text(fr.travelerStatusIndividualConfirm), findsOneWidget);
        expect(button(tester, fr.commonSave).onPressed, isNull);

        await tester.tap(find.text(fr.travelerStatusIndividualConfirm));
        await tester.pumpAndSettle();
        expect(button(tester, fr.commonSave).onPressed, isNotNull);

        await tester.tap(find.widgetWithText(DonyButton, fr.commonSave));
        await tester.pumpAndSettle();

        verify(
          () => repository.declare(
            status: TravelerStatus.individual,
            personalUseConfirmed: true,
          ),
        ).called(1);
        expect(result, isTrue);
        verify(
          () => authBloc.add(any(that: isA<AuthProfileRefreshRequested>())),
        ).called(1);
      },
    );

    testWidgets('« Retour » revient au choix en gardant la sélection', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, fr.commonContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, fr.commonBack));
      await tester.pumpAndSettle();

      expect(find.text(fr.travelerStatusSheetTitle), findsOneWidget);
      final group = tester.widget<DonyRadioGroup<TravelerStatus>>(
        find.byType(DonyRadioGroup<TravelerStatus>),
      );
      expect(group.value, TravelerStatus.individual);
    });
  });

  group('professionnel', () {
    Future<void> toProfessional(WidgetTester tester) async {
      await tester.tap(find.text(fr.travelerStatusOptionProfessional));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, fr.commonContinue));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'trois champs, bouton grisé tant que le numéro est trop court',
      (tester) async {
        await open(tester);
        await toProfessional(tester);

        expect(find.text(fr.travelerStatusProfessionalTitle), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text(fr.travelerStatusCountryLabel), findsWidgets);

        await tester.enterText(find.byType(TextField).at(0), 'Diallo Express');
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.pump();
        expect(button(tester, fr.commonSave).onPressed, isNull);
      },
    );

    testWidgets(
      'formulaire complet : déclare avec raison sociale, numéro, pays',
      (tester) async {
        when(
          () => repository.declare(
            status: TravelerStatus.professional,
            businessName: 'Diallo Express SARL',
            registrationNumber: 'CI-ABJ-2021-B-12345',
            country: 'CI',
          ),
        ).thenAnswer(
          (_) async => TravelerStatusDeclaration(
            status: TravelerStatus.professional,
            declaredAt: DateTime.utc(2026, 11),
          ),
        );
        await open(tester);
        await toProfessional(tester);

        await tester.enterText(
          find.byType(TextField).at(0),
          'Diallo Express SARL',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'CI-ABJ-2021-B-12345',
        );
        await tester.pump();
        // Pays : feuille de sélection.
        await tester.tap(find.text(fr.travelerStatusCountryLabel).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Côte d\'Ivoire').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Côte d\'Ivoire').first);
        await tester.pumpAndSettle();

        expect(button(tester, fr.commonSave).onPressed, isNotNull);
        await tester.tap(find.widgetWithText(DonyButton, fr.commonSave));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      },
    );

    testWidgets(
      'les champs gardent leur texte après « Retour » puis « Continuer »',
      (tester) async {
        await open(tester);
        await toProfessional(tester);
        await tester.enterText(find.byType(TextField).at(0), 'Diallo Express');
        await tester.tap(find.widgetWithText(DonyButton, fr.commonBack));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DonyButton, fr.commonContinue));
        await tester.pumpAndSettle();

        expect(find.text('Diallo Express'), findsOneWidget);
      },
    );
  });

  group('aide sur le numéro d\'entreprise invalide', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      final l = locale == AppL10n.fr ? fr : en;
      final code = locale.languageCode;

      testWidgets('[$code] 360 dp : message d\'erreur dès que le champ est '
          'non vide et invalide, aide neutre sinon', (tester) async {
        await open(tester, locale: locale);
        await tester.tap(find.text(l.travelerStatusOptionProfessional));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DonyButton, l.commonContinue));
        await tester.pumpAndSettle();

        // Champ vide : l'aide neutre, pas d'erreur.
        expect(find.text(l.travelerStatusRegistrationHint), findsOneWidget);
        expect(find.text(l.travelerStatusRegistrationInvalid), findsNothing);

        // 1 à 3 caractères : erreur à la place de l'aide.
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.pump();
        expect(find.text(l.travelerStatusRegistrationInvalid), findsOneWidget);
        expect(find.text(l.travelerStatusRegistrationHint), findsNothing);

        // Caractère interdit, même assez long.
        await tester.enterText(find.byType(TextField).at(1), '12345<script>');
        await tester.pump();
        expect(find.text(l.travelerStatusRegistrationInvalid), findsOneWidget);

        // Valide : l'aide neutre revient.
        await tester.enterText(find.byType(TextField).at(1), 'CI-ABJ 2021/1.2');
        await tester.pump();
        expect(find.text(l.travelerStatusRegistrationInvalid), findsNothing);
        expect(find.text(l.travelerStatusRegistrationHint), findsOneWidget);

        // Vidé à nouveau : aide neutre.
        await tester.enterText(find.byType(TextField).at(1), '');
        await tester.pump();
        expect(find.text(l.travelerStatusRegistrationHint), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('textes exacts, sans tiret cadratin', (tester) async {
      expect(
        fr.travelerStatusRegistrationInvalid,
        '4 caractères minimum : lettres, chiffres, espace, point, barre '
        'oblique ou tiret.',
      );
      expect(
        en.travelerStatusRegistrationInvalid,
        'At least 4 characters: letters, digits, space, dot, slash or hyphen.',
      );
      expect(fr.travelerStatusRegistrationInvalid, isNot(contains('—')));
      expect(en.travelerStatusRegistrationInvalid, isNot(contains('—')));
    });
  });

  group('échec du back', () {
    testWidgets('la feuille reste ouverte et le bouton se réactive', (
      tester,
    ) async {
      when(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      ).thenThrow(Exception('boom'));
      await open(tester);
      await tester.tap(find.text(fr.travelerStatusOptionIndividual));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, fr.commonContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.travelerStatusIndividualConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DonyButton, fr.commonSave));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(resultSet, isFalse);
      expect(find.text(fr.travelerStatusIndividualTitle), findsOneWidget);
      expect(button(tester, fr.commonSave).onPressed, isNotNull);
      // Laisser les animations de la snackbar d'erreur se terminer.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  });

  group('360 dp, français et anglais', () {
    for (final locale in [AppL10n.fr, AppL10n.en]) {
      final l = locale == AppL10n.fr ? fr : en;
      final code = locale.languageCode;

      testWidgets(
        '[$code] les trois étapes sans exception, boutons sur une ligne',
        (tester) async {
          await open(tester, locale: locale);
          final h = tester
              .getSize(find.widgetWithText(DonyButton, l.commonContinue))
              .height;

          await tester.tap(find.text(l.travelerStatusOptionProfessional));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(DonyButton, l.commonContinue));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getSize(find.widgetWithText(DonyButton, l.commonSave))
                .height,
            h,
          );
          expect(
            tester
                .getSize(find.widgetWithText(DonyButton, l.commonBack))
                .height,
            h,
          );

          await tester.tap(find.widgetWithText(DonyButton, l.commonBack));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.travelerStatusOptionIndividual));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(DonyButton, l.commonContinue));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(l.travelerStatusIndividualConfirm), findsOneWidget);
        },
      );
    }

    testWidgets('anglais : textes traduits', (tester) async {
      await open(tester, locale: AppL10n.en);
      expect(find.text(en.travelerStatusSheetTitle), findsOneWidget);
      expect(en.travelerStatusSheetTitle, isNot(fr.travelerStatusSheetTitle));
      expect(find.widgetWithText(DonyButton, en.commonLater), findsOneWidget);
    });
  });
}
