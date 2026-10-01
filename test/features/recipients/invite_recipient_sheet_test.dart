import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/invite_recipient_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

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

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
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
}
