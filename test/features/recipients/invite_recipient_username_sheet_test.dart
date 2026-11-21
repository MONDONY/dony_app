import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/invite_recipient_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

DioException _dio(AppException e) => DioException(
  requestOptions: RequestOptions(path: '/recipient-invitations/lookup'),
  error: e,
);

const _found = UsernameLookup(username: 'awa.diallo', initial: 'A');

/// Vraies polices de l'app : la police de test (Ahem) rend chaque lettre aussi
/// large qu'haute et fausserait la mesure des libellés à 360 dp.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadAppFonts);

  late _MockRepo repo;
  late _MockAnalytics analytics;
  bool? result;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
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
                result = await InviteRecipientSheet.show(
                  context,
                  createCubit: () => InviteRecipientCubit(repo, analytics),
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

  Finder usernameField() => find.byKey(const Key('invite-recipient-username'));
  Finder submit() => find.byKey(const Key('invite-recipient-submit'));
  DonyButton submitButton(WidgetTester tester) =>
      tester.widget<DonyButton>(submit());

  Future<void> selectUsernameTab(
    WidgetTester tester, {
    String label = 'Identifiant',
  }) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> blur(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('trois segments dans l\'ordre Numéro, E-mail, Identifiant', (
    tester,
  ) async {
    await open(tester);
    final phone = tester.getTopLeft(find.text('Numéro')).dx;
    final email = tester.getTopLeft(find.text('E-mail')).dx;
    final username = tester.getTopLeft(find.text('Identifiant')).dx;
    expect(phone, lessThan(email));
    expect(email, lessThan(username));
  });

  testWidgets('la frappe n\'appelle pas la recherche, la perte de focus oui', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    await open(tester);
    await selectUsernameTab(tester);
    expect(find.text('Identifiant Yadony'), findsOneWidget);
    expect(
      find.text('Il le trouve dans son profil, sous son nom.'),
      findsOneWidget,
    );

    await tester.enterText(usernameField(), 'awa.dia');
    await tester.pump();
    await tester.enterText(usernameField(), 'Awa.Diallo');
    await tester.pump(const Duration(seconds: 2));
    verifyNever(() => repo.lookupUsername(any()));
    expect(submitButton(tester).onPressed, isNull);

    await blur(tester);
    verify(() => repo.lookupUsername('awa.diallo')).called(1);
    expect(find.text('@awa.diallo'), findsWidgets);
    expect(find.text('Compte trouvé, prénom commençant par A'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('la validation du clavier lance la recherche', (tester) async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    await open(tester);
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), 'awa.diallo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // Puis la perte de focus : pas de seconde recherche.
    await blur(tester);
    verify(() => repo.lookupUsername('awa.diallo')).called(1);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('format invalide : aucune recherche, astuce de format', (
    tester,
  ) async {
    await open(tester);
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), 'ab');
    await blur(tester);
    verifyNever(() => repo.lookupUsername(any()));
    expect(
      find.text(
        'Utilisez 3 à 20 caractères : minuscules, chiffres, point et tiret bas.',
      ),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('modifier l\'identifiant retire l\'aperçu et l\'envoi', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    await open(tester);
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), 'awa.diallo');
    await blur(tester);
    expect(submitButton(tester).onPressed, isNotNull);
    await tester.enterText(usernameField(), 'awa.diallo2');
    await tester.pump();
    expect(find.textContaining('Compte trouvé'), findsNothing);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets(
    'introuvable : message, et le lien bascule sur Numéro avec le nom',
    (tester) async {
      when(
        () => repo.lookupUsername(any()),
      ).thenThrow(_dio(const NotFoundException(apiCode: 'user-not-found')));
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('invite-recipient-name')),
        'Awa',
      );
      await selectUsernameTab(tester);
      await tester.enterText(usernameField(), 'awa.diallo');
      await blur(tester);

      expect(
        find.text("Cet utilisateur n'existe pas. Vérifiez l'identifiant."),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);
      await tester.tap(
        find.byKey(const Key('invite-recipient-username-by-phone')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-recipient-phone')), findsOneWidget);
      expect(find.text('Awa'), findsOneWidget);
    },
  );

  testWidgets('c\'est son propre identifiant', (tester) async {
    when(() => repo.lookupUsername(any())).thenThrow(
      _dio(
        const ValidationException(
          'x',
          code: 'recipient-invitation-self',
          extensions: {'type': 'recipient-invitation-self'},
        ),
      ),
    );
    await open(tester);
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), 'awa.diallo');
    await blur(tester);
    expect(find.text("C'est votre identifiant."), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('quota de recherche', (tester) async {
    when(
      () => repo.lookupUsername(any()),
    ).thenThrow(_dio(const RateLimitException('x', 'recipient-lookup-quota')));
    await open(tester);
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), 'awa.diallo');
    await blur(tester);
    expect(
      find.text('Trop de recherches. Réessayez dans une heure.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'route absente : l\'onglet Identifiant disparaît, retour au numéro',
    (tester) async {
      when(
        () => repo.lookupUsername(any()),
      ).thenThrow(_dio(const NotFoundException()));
      await open(tester);
      await selectUsernameTab(tester);
      await tester.enterText(usernameField(), 'awa.diallo');
      await blur(tester);

      expect(find.text('Identifiant'), findsNothing);
      expect(find.byKey(const Key('invite-recipient-phone')), findsOneWidget);
      expect(find.text('Numéro'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
    },
  );

  testWidgets('envoi : POST avec l\'identifiant et le nom, feuille fermée', (
    tester,
  ) async {
    when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
    when(
      () => repo.sendToUsername(any(), name: any(named: 'name')),
    ).thenAnswer((_) async {});
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-name')),
      'Awa',
    );
    await selectUsernameTab(tester);
    await tester.enterText(usernameField(), '@awa.diallo');
    await blur(tester);
    await tester.tap(submit());
    await tester.pumpAndSettle();
    verify(() => repo.sendToUsername('awa.diallo', name: 'Awa')).called(1);
    expect(result, isTrue);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      '360 dp ${locale.languageCode} : segments et bouton sur une ligne',
      (tester) async {
        if (locale == AppL10n.en) enableEnglish();
        when(() => repo.lookupUsername(any())).thenAnswer((_) async => _found);
        await open(tester, locale: locale);
        final fr = locale == AppL10n.fr;
        final labels = fr
            ? ['Numéro', 'E-mail', 'Identifiant']
            : ['Phone number', 'Email', 'Username'];
        await tester.tap(find.text(labels[2]));
        await tester.pumpAndSettle();
        await tester.enterText(usernameField(), 'awa.diallo');
        await blur(tester);
        expect(tester.takeException(), isNull);

        for (final label in labels) {
          final text = find.descendant(
            of: find.byKey(const Key('invite-recipient-channel')),
            matching: find.text(label),
          );
          expect(text, findsOneWidget);
          final style = tester.widget<Text>(text).style;
          expect(
            tester.getSize(text).height,
            lessThan((style?.fontSize ?? 16) * 2.2),
            reason: label,
          );
        }
        final send = fr ? "Envoyer l'invitation" : 'Send invitation';
        final text = find.descendant(of: submit(), matching: find.text(send));
        expect(text, findsOneWidget);
        expect(tester.getSize(text).height, lessThan(32));
      },
    );
  }
}
