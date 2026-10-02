import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/invite_recipient_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockContactPicker extends Mock implements ContactPickerService {}

void main() {
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

  Future<void> open(
    WidgetTester tester, {
    String? userCountry,
    VoidCallback? onSent,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await InviteRecipientSheet.show(
                  context,
                  userCountry: userCountry,
                  onSent: onSent,
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

  Finder submit() => find.byKey(const Key('invite-recipient-submit'));

  DonyButton submitButton(WidgetTester tester) =>
      tester.widget<DonyButton>(submit());

  testWidgets('le bouton vit dans la barre fixe, désactivé tant que vide', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Ajouter un destinataire Yadony'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: submit(),
      ),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('numéro invalide : erreur après la perte de focus', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '77 12',
    );
    await tester.pump();
    const error = "Saisissez le numéro avec l'indicatif du pays (ex. +221).";
    expect(find.text(error), findsNothing);
    expect(submitButton(tester).onPressed, isNull);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text(error), findsOneWidget);
  });

  testWidgets('numéro valide : envoi, feuille fermée, rend true', (
    tester,
  ) async {
    when(() => repo.sendToPhone(any())).thenAnswer((_) async {});
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '+221 77 123 45 67',
    );
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(submit());
    await tester.pumpAndSettle();

    verify(() => repo.sendToPhone('+221771234567')).called(1);
    expect(submit(), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('FLUTTER-88 : onSent prévient l\'appelant dès le succès', (
    tester,
  ) async {
    when(() => repo.sendToPhone(any())).thenAnswer((_) async {});
    var sentCalls = 0;
    bool? resultWhenSent;
    await open(
      tester,
      onSent: () {
        sentCalls++;
        resultWhenSent = result;
      },
    );
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '+221 77 123 45 67',
    );
    await tester.pump();
    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(sentCalls, 1);
    // Appelé avant la fermeture : le résultat n'était pas encore rendu.
    expect(resultWhenSent, isNull);
    expect(result, isTrue);
  });

  testWidgets('envoi raté : onSent n\'est pas appelé', (tester) async {
    when(() => repo.sendToPhone(any())).thenThrow(Exception('boom'));
    var sentCalls = 0;
    await open(tester, onSent: () => sentCalls++);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '+221 77 123 45 67',
    );
    await tester.pump();
    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(sentCalls, 0);
  });

  testWidgets('bascule e-mail : champ dédié, validation e-mail', (
    tester,
  ) async {
    when(() => repo.sendToEmail(any())).thenAnswer((_) async {});
    await open(tester);
    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-recipient-phone')), findsNothing);
    final email = find.byKey(const Key('invite-recipient-email'));
    expect(email, findsOneWidget);

    await tester.enterText(email, 'awa@');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(email, 'Awa@Example.com');
    await tester.pump();
    await tester.tap(submit());
    await tester.pumpAndSettle();
    verify(() => repo.sendToEmail('awa@example.com')).called(1);
    expect(result, isTrue);
  });

  testWidgets('retour au numéro : la saisie précédente est reprise', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '+221771234567',
    );
    await tester.pump();
    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull);
    await tester.tap(find.text('Numéro'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('429 : message de quota, la feuille reste ouverte', (
    tester,
  ) async {
    when(() => repo.sendToPhone(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/recipient-invitations'),
        error: const RateLimitException(),
      ),
    );
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('invite-recipient-phone')),
      '+221771234567',
    );
    await tester.pump();
    await tester.tap(submit());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
        "Vous avez envoyé beaucoup d'invitations aujourd'hui. "
        'Réessayez demain.',
      ),
      findsOneWidget,
    );
    expect(submit(), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('fermée sans envoyer : rend false', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  group('nom et contacts (FLUTTER-7V)', () {
    late _MockContactPicker picker;

    setUp(() {
      picker = _MockContactPicker();
      if (getIt.isRegistered<ContactPickerService>()) {
        getIt.unregister<ContactPickerService>();
      }
      getIt.registerSingleton<ContactPickerService>(picker);
    });

    tearDown(() {
      if (getIt.isRegistered<ContactPickerService>()) {
        getIt.unregister<ContactPickerService>();
      }
    });

    testWidgets('choisir un contact : numéro internationalisé et nom repris', (
      tester,
    ) async {
      when(() => picker.pick()).thenAnswer(
        (_) async =>
            const PickedContact(fullName: 'Awa Diallo', phone: '0612345678'),
      );
      when(
        () => repo.sendToPhone(any(), name: any(named: 'name')),
      ).thenAnswer((_) async {});
      await open(tester, userCountry: 'FR');

      await tester.tap(find.byKey(const Key('invite-recipient-pick-contact')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('invite-recipient-phone')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '+33612345678',
      );
      expect(find.text('Awa Diallo'), findsOneWidget);

      await tester.tap(submit());
      await tester.pumpAndSettle();
      verify(
        () => repo.sendToPhone('+33612345678', name: 'Awa Diallo'),
      ).called(1);
      expect(result, isTrue);
    });

    testWidgets('contact annulé : formulaire inchangé', (tester) async {
      when(() => picker.pick()).thenAnswer((_) async => null);
      await open(tester, userCountry: 'FR');

      await tester.tap(find.byKey(const Key('invite-recipient-pick-contact')));
      await tester.pumpAndSettle();
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets("le lien contacts n'existe qu'en mode numéro", (tester) async {
      await open(tester);
      expect(
        find.byKey(const Key('invite-recipient-pick-contact')),
        findsOneWidget,
      );
      await tester.tap(find.text('E-mail'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('invite-recipient-pick-contact')),
        findsNothing,
      );
    });

    testWidgets('nom saisi : envoyé avec le numéro', (tester) async {
      when(
        () => repo.sendToPhone(any(), name: any(named: 'name')),
      ).thenAnswer((_) async {});
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('invite-recipient-phone')),
        '+221771234567',
      );
      await tester.enterText(
        find.byKey(const Key('invite-recipient-name')),
        'Fatou',
      );
      await tester.pump();
      await tester.tap(submit());
      await tester.pumpAndSettle();
      verify(() => repo.sendToPhone('+221771234567', name: 'Fatou')).called(1);
    });

    testWidgets('nom trop long : erreur et envoi bloqué', (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('invite-recipient-phone')),
        '+221771234567',
      );
      await tester.enterText(
        find.byKey(const Key('invite-recipient-name')),
        'a' * 101,
      );
      await tester.pump();
      expect(find.text('100 caractères au maximum.'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });
  });
}
