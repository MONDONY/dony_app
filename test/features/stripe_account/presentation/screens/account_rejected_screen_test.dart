import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_rejected_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

void main() {
  late MockConnectOnboardingBloc mockOnboardingBloc;
  late MockStripeAccountBloc mockStripeBloc;

  setUp(() {
    mockOnboardingBloc = MockConnectOnboardingBloc();
    mockStripeBloc = MockStripeAccountBloc();
    when(
      () => mockOnboardingBloc.state,
    ).thenReturn(const ConnectOnboardingInitial());
    when(() => mockStripeBloc.state).thenReturn(
      const StripeAccountReady(
        ConnectAccountStatus(status: 'REJECTED', reason: 'Documents invalides'),
      ),
    );
  });

  Widget buildWidget() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ConnectOnboardingBloc>.value(value: mockOnboardingBloc),
        BlocProvider<StripeAccountBloc>.value(value: mockStripeBloc),
      ],
      child: const AccountRejectedScreen(),
    ),
  );

  testWidgets('affiche le titre et le message', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('rejeté'), findsWidgets);
  });

  testWidgets('affiche la raison du rejet si disponible', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Documents invalides'), findsOneWidget);
  });

  testWidgets('affiche le bouton Reconfigurer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Reconfigurer mon compte'), findsOneWidget);
  });

  testWidgets('bouton support absent au premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Contacter le support Yadony'), findsNothing);
  });

  testWidgets('bouton support apparaît après 2 taps sur Reconfigurer', (
    tester,
  ) async {
    when(
      () => mockOnboardingBloc.state,
    ).thenReturn(const ConnectOnboardingInitial());
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Reconfigurer mon compte'));
    await tester.pump();
    await tester.tap(find.text('Reconfigurer mon compte'));
    await tester.pump();
    expect(find.text('Contacter le support Yadony'), findsOneWidget);
  });

  testWidgets('affiche un SnackBar quand ConnectOnboardingError est émis', (
    tester,
  ) async {
    const errorMessage = 'Impossible de générer le lien';
    whenListen(
      mockOnboardingBloc,
      Stream.fromIterable([
        const ConnectOnboardingInitial(),
        const ConnectOnboardingError(
          NetworkException(errorMessage, code: 'link-failed'),
        ),
      ]),
      initialState: const ConnectOnboardingInitial(),
    );
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text(errorMessage), findsOneWidget);
  });
}
