import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/presentation/widgets/pin_confirm_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

Widget _wrap(LocalAuthService authService) => MaterialApp(
  home: Scaffold(body: PinConfirmBottomSheet(authService: authService)),
);

void main() {
  late MockLocalAuthService svc;

  setUp(() {
    svc = MockLocalAuthService();
  });

  testWidgets('affiche le titre et le sous-titre', (tester) async {
    await tester.pumpWidget(_wrap(svc));
    await tester.pumpAndSettle();
    expect(find.text('Confirmez votre code PIN'), findsOneWidget);
    expect(find.text('Saisissez votre code pour confirmer'), findsOneWidget);
  });

  testWidgets('affiche les tentatives restantes après un code erroné', (
    tester,
  ) async {
    when(() => svc.validatePin(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(_wrap(svc));

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('2 tentatives restantes'), findsOneWidget);
  });

  testWidgets('affiche « 1 tentative restante » au dernier essai (accord)', (
    tester,
  ) async {
    when(() => svc.validatePin(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(_wrap(svc));

    for (var attempt = 0; attempt < 2; attempt++) {
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(digit).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }

    expect(find.text('1 tentative restante'), findsOneWidget);
    expect(find.text('1 tentative(s) restante(s)'), findsNothing);
  });

  testWidgets('anglais : titre, sous-titre et tentatives traduits', (
    tester,
  ) async {
    useEnglish();
    when(() => svc.validatePin(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(_wrap(svc));
    await tester.pump();

    expect(find.text('Confirm your PIN'), findsOneWidget);
    expect(find.text('Enter your code to confirm'), findsOneWidget);

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('2 attempts left'), findsOneWidget);
    expect(find.text('Confirmez votre code PIN'), findsNothing);
  });
}
