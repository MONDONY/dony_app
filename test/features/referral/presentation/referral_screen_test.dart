import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/presentation/screens/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class FakeReferralEvent extends Fake implements ReferralEvent {}

Widget _wrap(ReferralBloc bloc) => BlocProvider<ReferralBloc>.value(
  value: bloc,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ReferralScreen())],
    ),
  ),
);

const _testInfo = ReferralInfo(
  code: 'DONY-XYZ42',
  shareUrl: 'https://dony.app/invite/DONY-XYZ42',
  totalInvited: 4,
  signedUp: 2,
  rewarded: 1,
  totalEarnedCents: 500,
  hasBeenReferred: false,
  currency: 'EUR',
  rewardAmountCents: 500,
);

void main() {
  late MockReferralBloc bloc;

  setUpAll(() => registerFallbackValue(FakeReferralEvent()));

  setUp(() {
    bloc = MockReferralBloc();
    when(() => bloc.state).thenReturn(const ReferralInitial());
  });

  // 1. Affiche CircularProgressIndicator quand ReferralLoading
  testWidgets('shows skeleton when ReferralLoading', (tester) async {
    when(() => bloc.state).thenReturn(const ReferralLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  // 2. Affiche "Parrainage" comme titre AppBar
  testWidgets('shows "Parrainage" as AppBar title', (tester) async {
    when(() => bloc.state).thenReturn(const ReferralLoading());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Parrainage'), findsOneWidget);
  });

  // 3. Affiche le code quand ReferralLoaded
  testWidgets('shows referral code when ReferralLoaded', (tester) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('DONY-XYZ42'), findsOneWidget);
  });

  // 4. Affiche le bouton "Partager mon code"
  testWidgets('shows "Partager mon code" button when ReferralLoaded', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Partager mon code'), findsOneWidget);
  });

  // 5. Affiche les stats (invités / inscrits / récompensés)
  testWidgets('shows stats labels when ReferralLoaded', (tester) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Invités'), findsOneWidget);
    expect(find.text('Inscrits'), findsOneWidget);
    expect(find.text('Récompensés'), findsOneWidget);
  });

  // 6. Affiche "Réessayer" quand ReferralError
  testWidgets('shows Réessayer button when ReferralError', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const ReferralError(NetworkException('Erreur réseau')));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Réessayer'), findsOneWidget);
  });

  // 7. Affiche les valeurs numériques des stats
  testWidgets('shows numeric stat values when ReferralLoaded', (tester) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // totalInvited = 4, signedUp = 2, rewarded = 1
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // 8. Affiche le message de gains si totalEarnedCents > 0
  testWidgets('shows earnings banner when totalEarnedCents > 0', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // totalEarnedCents = 500 avec currency EUR → « 5,00 € ». Le montant garde
    // ses décimales : c'est une somme créditée, pas un arrondi d'affichage.
    expect(
      find.textContaining('5,00\u00A0€ grâce au parrainage'),
      findsOneWidget,
    );
  });

  testWidgets('le gain suit la devise renvoyée par le serveur', (tester) async {
    // La récompense est versée dans la devise active du parrain au moment du
    // versement : afficher « € » en dur aurait annoncé un montant faux à un
    // parrain travaillant en dollar.
    const infoUsd = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 1,
      totalEarnedCents: 500,
      hasBeenReferred: false,
      currency: 'USD',
      rewardAmountCents: 500,
    );
    when(() => bloc.state).thenReturn(const ReferralLoaded(infoUsd));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Le montant apparaît sur la carte, dans le sous-titre et dans le message
    // de partage : ce qui compte est qu'aucun euro ne subsiste.
    expect(find.textContaining(r'$5.00'), findsWidgets);
    expect(find.textContaining('€'), findsNothing);
  });

  // 9. Hero card affiche le texte d'invite
  testWidgets('shows hero card invite text when ReferralLoaded', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Le montant promis vient du serveur (rewardAmountCents) et suit la devise
    // du parrain : il n'est plus écrit en dur dans l'écran.
    expect(find.text('Invite et gagne 5,00\u00A0€'), findsOneWidget);
  });

  // 10. Message d'erreur affiché dans l'error view
  testWidgets('shows error message text when ReferralError', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const ReferralError(NetworkException('Erreur réseau')));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Une erreur est survenue'), findsOneWidget);
  });
}
