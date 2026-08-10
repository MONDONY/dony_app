import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
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
  late MockConnectOnboardingBloc connectBloc;
  late MockStripeAccountBloc stripeBloc;

  setUpAll(() {
    registerFallbackValue(const ConnectOnboardingLinkRequested());
    registerFallbackValue(const StripeAccountStatusRefreshed());
  });

  setUp(() {
    connectBloc = MockConnectOnboardingBloc();
    whenListen<ConnectOnboardingState>(
      connectBloc,
      const Stream.empty(),
      initialState: const ConnectOnboardingInitial(),
    );

    stripeBloc = MockStripeAccountBloc();
    whenListen<StripeAccountState>(
      stripeBloc,
      const Stream.empty(),
      initialState: const StripeAccountReady(
        ConnectAccountStatus(status: 'DISABLED'),
      ),
    );
  });

  Widget buildWidget() => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ConnectOnboardingBloc>.value(value: connectBloc),
            BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          ],
          child: const AccountDisabledScreen(),
        ),
      );

  testWidgets('affiche le titre et le message', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('temporairement désactivé'), findsWidgets);
    expect(find.textContaining('réactivation automatique'), findsOneWidget);
  });

  testWidgets('affiche le bouton Stripe dès le premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Voir mon compte Stripe'), findsOneWidget);
  });

  testWidgets('bouton support absent au premier affichage', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Contacter le support Yadony'), findsNothing);
  });

  testWidgets('bouton support apparaît après 2 taps sur le bouton principal',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Yadony'), findsNothing);
    await tester.tap(find.text('Voir mon compte Stripe'));
    await tester.pump();
    expect(find.text('Contacter le support Yadony'), findsOneWidget);
  });

  testWidgets('affiche les informations Stripe encore requises quand connues',
      (tester) async {
    whenListen<StripeAccountState>(
      stripeBloc,
      const Stream.empty(),
      initialState: const StripeAccountReady(
        ConnectAccountStatus(
          status: 'DISABLED',
          requirementsCurrentlyDue: {'external_account', 'individual.id_number'},
        ),
      ),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('Informations à compléter'), findsOneWidget);
    expect(find.textContaining('external_account'), findsOneWidget);
    expect(find.textContaining('individual.id_number'), findsOneWidget);
  });

  testWidgets(
      'masque la section requirements quand aucune information n\'est due',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.text('Informations à compléter'), findsNothing);
  });

  testWidgets(
      'le bouton actualiser déclenche StripeAccountStatusRefreshed '
      '(regression: l\'écran n\'offrait aucun moyen de revérifier le statut '
      'sans quitter puis revenir)',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    await tester.tap(find.byTooltip('Actualiser le statut'));

    verify(() => stripeBloc.add(const StripeAccountStatusRefreshed()))
        .called(1);
  });

  testWidgets('affiche un indicateur de chargement pendant le refresh',
      (tester) async {
    whenListen<StripeAccountState>(
      stripeBloc,
      const Stream.empty(),
      initialState: const StripeAccountLoading(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      '« Compléter mes informations » déclenche ConnectOnboardingLinkRequested '
      '(regression: seul un lien externe vers le dashboard Stripe existait, '
      'sans action pour reprendre l\'onboarding interrompu depuis l\'app)',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    await tester.tap(find.text('Compléter mes informations'));

    verify(() => connectBloc.add(const ConnectOnboardingLinkRequested()))
        .called(1);
  });
}
