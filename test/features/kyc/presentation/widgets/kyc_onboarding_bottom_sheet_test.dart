import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _FakeKycEvent extends Fake implements KycEvent {}

Widget _wrap(KycBloc kycBloc) {
  return MaterialApp(
    home: BlocProvider<KycBloc>.value(
      value: kycBloc,
      child: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => KycOnboardingBottomSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKycEvent());
  });

  late _MockKycBloc kycBloc;

  setUp(() {
    kycBloc = _MockKycBloc();
    when(() => kycBloc.state).thenReturn(const KycInitial());
    when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('KycOnboardingBottomSheet', () {
    testWidgets('affiche le titre, le sous-titre et les infos', (tester) async {
      await tester.pumpWidget(_wrap(kycBloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifiez votre identité'), findsOneWidget);
      expect(
        find.text('Requis pour publier des annonces sur Yadony'),
        findsOneWidget,
      );
      expect(find.text('Processus de vérification sécurisé'), findsOneWidget);
      expect(find.text("Pièce d'identité + selfie requis"), findsOneWidget);
      expect(find.text('Vérification en 2 à 5 minutes'), findsOneWidget);
    });

    testWidgets('affiche les deux boutons d\'action', (tester) async {
      await tester.pumpWidget(_wrap(kycBloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Démarrer la vérification'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
    });

    testWidgets('"Plus tard" ferme le sheet', (tester) async {
      await tester.pumpWidget(_wrap(kycBloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Vérifiez votre identité'), findsOneWidget);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Vérifiez votre identité'), findsNothing);
    });

    testWidgets('affiche le titre et les infos en anglais', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(kycBloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your identity'), findsOneWidget);
      expect(find.text('Required to post listings on Yadony'), findsOneWidget);
      expect(find.text('Secure verification process'), findsOneWidget);
      expect(find.text('ID document + selfie required'), findsOneWidget);
      expect(find.text('Verification takes 2 to 5 minutes'), findsOneWidget);
      expect(find.text('Start verification'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });
  });
}
