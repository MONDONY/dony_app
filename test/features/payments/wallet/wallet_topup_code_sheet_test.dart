import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_code_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_topup_code_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository repo;
  WalletTopupCodeRedemptionModel? result;

  setUp(() {
    repo = _MockWalletRepository();
    result = null;
    if (getIt.isRegistered<WalletTopupCodeCubit>()) {
      getIt.unregister<WalletTopupCodeCubit>();
    }
    getIt.registerFactory<WalletTopupCodeCubit>(
      () => WalletTopupCodeCubit(repo),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<WalletTopupCodeCubit>()) {
      getIt.unregister<WalletTopupCodeCubit>();
    }
  });

  Widget testApp() => localizedApp(
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () async =>
                result = await WalletTopupCodeSheet.show(ctx),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche titre, champ et mention non remboursable', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('Code de recharge'), findsOneWidget);
    expect(find.textContaining('ni remboursable ni retirable'), findsOneWidget);
    expect(find.text('Valider le code'), findsOneWidget);
  });

  testWidgets('bouton inactif tant que le champ est vide', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();
    verifyNever(() => repo.redeemTopupCode(any()));
  });

  testWidgets('succès : envoie le texte saisi et renvoie le crédit', (
    tester,
  ) async {
    when(() => repo.redeemTopupCode('dakar 2000')).thenAnswer(
      (_) async => const WalletTopupCodeRedemptionModel(
        amount: 2000,
        currency: 'XOF',
        balance: 3500,
      ),
    );
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'dakar 2000');
    await tester.pump();
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();
    expect(result?.currency, 'XOF');
    expect(find.text('Valider le code'), findsNothing);
  });

  testWidgets('échec : la sheet reste ouverte et affiche le titre d’erreur', (
    tester,
  ) async {
    when(() => repo.redeemTopupCode(any())).thenThrow(
      const ValidationException('x', code: 'topup-code-already-redeemed'),
    );
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'DAKAR2000');
    await tester.pump();
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();
    expect(find.text('Valider le code'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WalletTopupCodeSheet),
        matching: find.text('Code déjà utilisé'),
      ),
      findsOneWidget,
    );
    expect(result, isNull);

    // L'erreur disparaît dès que l'utilisateur modifie le champ.
    await tester.enterText(find.byType(TextField), 'DAKAR20001');
    await tester.pump();
    expect(find.text('Code déjà utilisé'), findsNothing);
  });

  testWidgets('route absente (404) : message service indisponible', (
    tester,
  ) async {
    when(
      () => repo.redeemTopupCode(any()),
    ).thenThrow(const NotFoundException());
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'DAKAR2000');
    await tester.pump();
    await tester.tap(find.text('Valider le code'));
    await tester.pumpAndSettle();
    expect(find.text('Service indisponible'), findsWidgets);
    expect(find.text('Introuvable'), findsNothing);
    expect(find.text('Valider le code'), findsOneWidget);
  });

  testWidgets('clavier « terminé » valide le code', (tester) async {
    when(() => repo.redeemTopupCode('dakar 2000')).thenAnswer(
      (_) async => const WalletTopupCodeRedemptionModel(
        amount: 2000,
        currency: 'XOF',
        balance: 3500,
      ),
    );
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'dakar 2000');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result?.currency, 'XOF');
  });

  testWidgets('pendant l’envoi, le retour système est bloqué', (tester) async {
    final completer = Completer<WalletTopupCodeRedemptionModel>();
    when(() => repo.redeemTopupCode(any())).thenAnswer((_) => completer.future);
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'DAKAR2000');
    await tester.pump();
    await tester.tap(find.text('Valider le code'));
    await tester.pump();
    final pop = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(WalletTopupCodeSheet),
        matching: find.byType(PopScope),
      ),
    );
    expect(pop.canPop, isFalse);
    completer.complete(
      const WalletTopupCodeRedemptionModel(
        amount: 2000,
        currency: 'XOF',
        balance: 3500,
      ),
    );
    await tester.pumpAndSettle();
  });
}
