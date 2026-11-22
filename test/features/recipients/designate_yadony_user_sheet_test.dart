import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/designate_yadony_user_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _found = UsernameLookup(
  username: 'awa.diallo',
  initial: 'A',
  parcelDesignation: true,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  DesignatedUser? result;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.usernameChannelUnsupported).thenReturn(false);
    when(() => repo.parcelDesignationUnavailable).thenReturn(false);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    result = null;
  });

  Future<void> open(WidgetTester tester, {Locale locale = AppL10n.fr}) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DesignateYadonyUserSheet.show(
                  context,
                  createCubit: () => DesignateYadonyUserCubit(repo, analytics),
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

  Finder field() => find.byKey(const Key('designate-yadony-user-field'));
  Finder choose() => find.byKey(const Key('designate-yadony-user-choose'));
  DonyButton button(WidgetTester tester) => tester.widget<DonyButton>(choose());

  Future<void> typeAndSubmit(WidgetTester tester, String v) async {
    await tester.enterText(field(), v);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('la frappe seule ne cherche pas, Choisir est grisé', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field(), 'awa.diallo');
    await tester.pump();
    verifyNever(() => repo.lookupUsername(any()));
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('compte trouvé : aperçu, Choisir rend l\'identifiant', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    await open(tester);
    await typeAndSubmit(tester, 'awa.diallo');
    expect(find.text('@awa.diallo'), findsOneWidget);
    expect(find.text('Compte trouvé, prénom commençant par A'), findsOneWidget);
    expect(button(tester).onPressed, isNotNull);
    await tester.tap(choose());
    await tester.pumpAndSettle();
    expect(result?.username, 'awa.diallo');
  });

  testWidgets('back sans désignation de colis : message, pas de sélection', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenAnswer(
      (_) async => const UsernameLookup(username: 'awa.diallo', initial: 'A'),
    );
    await open(tester);
    await typeAndSubmit(tester, 'awa.diallo');
    expect(
      find.text('Cette désignation n\'est pas encore disponible.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('designate-yadony-user-preview')),
      findsNothing,
    );
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('introuvable et soi-même : messages de l\'étape 1', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const NotFoundException(apiCode: 'user-not-found'),
      ),
    );
    await open(tester);
    await typeAndSubmit(tester, 'awa.diallo');
    expect(
      find.text('Cet utilisateur n\'existe pas. Vérifiez l\'identifiant.'),
      findsOneWidget,
    );
    expect(button(tester).onPressed, isNull);
  });

  Future<void> failWith(WidgetTester tester, AppException e) async {
    when(() => repo.lookupUsername(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: e,
      ),
    );
    await open(tester);
    await typeAndSubmit(tester, 'awa.diallo');
  }

  testWidgets('quota : message d\'attente d\'une heure', (tester) async {
    await failWith(
      tester,
      const RateLimitException('x', 'recipient-lookup-quota'),
    );
    expect(
      find.text('Trop de recherches. Réessayez dans une heure.'),
      findsOneWidget,
    );
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('route absente : message dédié', (tester) async {
    await failWith(tester, const NetworkException('x', code: '405'));
    expect(
      find.text('La recherche par identifiant n\'est pas encore disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('échec technique : message de vérification impossible', (
    tester,
  ) async {
    await failWith(tester, const NetworkException('x', code: 'unknown'));
    expect(find.text('Vérification impossible. Réessayez.'), findsOneWidget);
  });

  testWidgets('format invalide après la perte de focus : message de format', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field(), 'ab');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    verifyNever(() => repo.lookupUsername(any()));
    expect(
      find.text(
        'Utilisez 3 à 20 caractères : minuscules, chiffres, point et tiret bas.',
      ),
      findsOneWidget,
    );
    expect(button(tester).onPressed, isNull);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      'libellé du bouton sur une ligne à 360 dp (${locale.languageCode})',
      (tester) async {
        await open(tester, locale: locale);
        expect(tester.takeException(), isNull);
        final h = tester.getSize(choose()).height;
        expect(h, lessThan(64));
        final label = locale == AppL10n.fr ? 'Choisir' : 'Choose';
        expect(
          find.descendant(of: choose(), matching: find.text(label)),
          findsOneWidget,
        );
      },
    );
  }
}
