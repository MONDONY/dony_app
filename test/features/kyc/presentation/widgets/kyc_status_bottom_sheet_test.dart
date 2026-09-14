import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockKycBloc kycBloc;
  late StreamController<KycState> kycStates;

  setUp(() async {
    await GetIt.I.reset();
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(
        UserModel(id: 'u1', roles: [], kycStatus: 'PENDING', status: 'ACTIVE'),
      ),
    );
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    kycStates = StreamController<KycState>.broadcast();
    kycBloc = _MockKycBloc();
    when(() => kycBloc.state).thenReturn(const KycInitial());
    when(() => kycBloc.stream).thenAnswer((_) => kycStates.stream);
    when(() => kycBloc.close()).thenAnswer((_) async {});
    GetIt.I.registerFactory<KycBloc>(() => kycBloc);
  });

  tearDown(() async {
    await kycStates.close();
    await GetIt.I.reset();
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => KycStatusBottomSheet.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  // Pas de pumpAndSettle : la sheet arme un timeout de 5 min que
  // pumpAndSettle ferait tirer (vue « Retour à l'app »).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('KycStatusBottomSheet', () {
    testWidgets(
      'affiche le statut PENDING et le bouton « Continuer plus tard »',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text('Open'));
        await settle(tester);

        expect(find.text('Vérification d\'identité'), findsOneWidget);
        expect(find.text('Continuer plus tard'), findsOneWidget);
      },
    );

    // Sentry FLUTTER-1C : un état KYC reçu après le pop rebâtit le contenu,
    // qui écrit dans le notifier du bouton collant pendant l'animation de
    // sortie.
    testWidgets(
      'un état KYC reçu pendant l\'animation de fermeture ne plante pas',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text('Open'));
        await settle(tester);

        await tester.tap(find.text('Continuer plus tard'));
        // Un seul frame : la route est retirée de la pile mais la sheet est
        // encore affichée par son animation de sortie.
        await tester.pump();

        kycStates.add(
          const KycStatusLoaded(
            kycStatus: 'PENDING',
            verificationStatus: 'PENDING',
          ),
        );
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Vérification d\'identité'), findsNothing);
      },
    );
  });
}
