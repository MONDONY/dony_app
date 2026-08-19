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
import 'package:intl/date_symbol_data_local.dart';
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

// Lot 3 (2026-08-19/20) : le parrainage n'est plus un montant crédité mais un
// bon de réduction de commission — plus aucune devise n'entre en jeu.
final _testInfo = ReferralInfo(
  code: 'DONY-XYZ42',
  shareUrl: 'https://dony.app/invite/DONY-XYZ42',
  totalInvited: 4,
  signedUp: 2,
  rewarded: 1,
  hasBeenReferred: false,
  activeVoucherCount: 1,
  voucherFactor: 0.5,
  nextVoucherExpiresAt: DateTime(2027, 1, 15),
);

void main() {
  late MockReferralBloc bloc;

  setUpAll(() async {
    registerFallbackValue(FakeReferralEvent());
    await initializeDateFormatting('fr_FR');
  });

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
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('DONY-XYZ42'), findsOneWidget);
  });

  // 4. Affiche le bouton "Partager mon code"
  testWidgets('shows "Partager mon code" button when ReferralLoaded', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Partager mon code'), findsOneWidget);
  });

  // 5. Affiche les stats (invités / inscrits / récompensés)
  testWidgets('shows stats labels when ReferralLoaded', (tester) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

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
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // totalInvited = 4, signedUp = 2, rewarded = 1
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // 8. Affiche le bandeau du bon si activeVoucherCount > 0
  testWidgets('shows voucher banner when activeVoucherCount > 0', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Ce n'est plus un montant crédité (aucune devise) mais un pourcentage de
    // réduction, calculé depuis voucherFactor (0.5 → -50 %). Le préfixe 🎁
    // distingue ce bandeau du sous-titre de la hero card, qui répète la même
    // formulation générique.
    expect(
      find.text('🎁 Tu as un bon de -50% sur ta prochaine commission'),
      findsOneWidget,
    );
  });

  testWidgets('affiche le décompte au pluriel avec plusieurs bons actifs', (
    tester,
  ) async {
    final infoTwoVouchers = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 2,
      hasBeenReferred: false,
      activeVoucherCount: 2,
      voucherFactor: 0.5,
      nextVoucherExpiresAt: DateTime(2027, 1, 15),
    );
    when(() => bloc.state).thenReturn(ReferralLoaded(infoTwoVouchers));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('🎁 Tu as 2 bons de -50% sur tes prochaines commissions'),
      findsOneWidget,
    );
  });

  testWidgets('aucun bandeau si aucun bon actif', (tester) async {
    final infoNoVoucher = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 0,
      hasBeenReferred: false,
      activeVoucherCount: 0,
      voucherFactor: 0.5,
    );
    when(() => bloc.state).thenReturn(ReferralLoaded(infoNoVoucher));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('🎁'), findsNothing);
  });

  // 9. Hero card affiche le texte d'invite
  testWidgets('shows hero card invite text when ReferralLoaded', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // Le pourcentage promis vient du serveur (voucherFactor) : plus aucun
    // montant ni devise écrits en dur dans l'écran.
    expect(find.text('Invite et gagne -50%'), findsOneWidget);
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
