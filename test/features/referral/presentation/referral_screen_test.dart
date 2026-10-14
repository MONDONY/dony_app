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

import '../../../helpers/l10n_test_helpers.dart';

class MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class FakeReferralEvent extends Fake implements ReferralEvent {}

/// Texte affiché, espaces insécables (montants formatés) ramenés à des
/// espaces simples.
Finder _normalized(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.replaceAll(RegExp(r'\s'), ' ') == text,
);

Widget _wrap(ReferralBloc bloc, {String? prefillCode}) =>
    BlocProvider<ReferralBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => ReferralScreen(prefillCode: prefillCode),
            ),
          ],
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

  setUp(() {
    // Toujours un écran haut : la liste est paresseuse (ListView).
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      9000,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    addTearDown(binding.platformDispatcher.views.first.reset);
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

    expect(find.text('Code : DONY-XYZ42', findRichText: true), findsOneWidget);
    // Le lien s'affiche sans son schéma.
    expect(find.text('dony.app/invite/DONY-XYZ42'), findsOneWidget);
  });

  // 4. Boutons WhatsApp et Partager
  testWidgets('shows WhatsApp and Partager buttons when ReferralLoaded', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
  });

  // 5. Affiche les stats (inscrits / 1er envoi fait / gagnés)
  testWidgets('shows stats labels when ReferralLoaded', (tester) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Inscrits'), findsOneWidget);
    expect(find.text('1er envoi fait'), findsOneWidget);
    expect(find.text('Gagnés'), findsOneWidget);
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

    // signedUp = 2, firstDelivery absent → rewarded = 1, aucun crédit choisi.
    // « 2 » et « 1 » servent aussi aux numéros d'étape de « Comment ça
    // marche » : on vérifie qu'ils apparaissent, le montant est unique.
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(_normalized('0 €'), findsOneWidget);
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
      find.text('🎁 Vous avez un bon de -50% sur votre prochaine commission'),
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
      find.text('🎁 Vous avez 2 bons de -50% sur vos prochaines commissions'),
      findsOneWidget,
    );
  });

  testWidgets('aucun bandeau si aucun bon actif', (tester) async {
    const infoNoVoucher = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 0,
      hasBeenReferred: false,
      activeVoucherCount: 0,
      voucherFactor: 0.5,
    );
    when(() => bloc.state).thenReturn(const ReferralLoaded(infoNoVoucher));

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

    // Ancien back sans barème : repli sur 5 € / -5 %.
    expect(find.text('Invitez vos proches'), findsOneWidget);
    expect(
      _normalized('5 € offerts ou -5 % sur votre prochain envoi'),
      findsOneWidget,
    );
  });

  testWidgets('hero : barème servi par le back', (tester) async {
    const info = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 1,
      hasBeenReferred: false,
      activeVoucherCount: 0,
      rewardWalletAmount: 10,
      rewardWalletCurrency: 'EUR',
      rewardDiscountPercent: 8,
    );
    when(() => bloc.state).thenReturn(const ReferralLoaded(info));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      _normalized('10 € offerts ou -8 % sur votre prochain envoi'),
      findsOneWidget,
    );
  });

  // 9 bis. Sans barème serveur, aucun pourcentage de bon inventé.
  testWidgets('hides the voucher percent when voucherFactor is missing', (
    tester,
  ) async {
    const info = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 1,
      hasBeenReferred: false,
      activeVoucherCount: 0,
    );
    when(() => bloc.state).thenReturn(const ReferralLoaded(info));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Invitez vos proches'), findsOneWidget);
    expect(find.textContaining('-50%'), findsNothing);
    expect(find.textContaining('-null'), findsNothing);
  });

  // 9 ter. Bon(s) actif(s) sans pourcentage connu (repli défensif) : le
  // bandeau doit rester affiché (activeVoucherCount > 0) mais sans inventer
  // de pourcentage — jamais de « -0% ».
  testWidgets(
    'shows the voucher banner without a percent when voucherFactor is '
    'missing but a voucher is active',
    (tester) async {
      const info = ReferralInfo(
        code: 'DONY-XYZ42',
        shareUrl: 'https://dony.app/invite/DONY-XYZ42',
        totalInvited: 4,
        signedUp: 2,
        rewarded: 1,
        hasBeenReferred: false,
        activeVoucherCount: 1,
      );
      when(() => bloc.state).thenReturn(const ReferralLoaded(info));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text(
          '🎁 Vous avez un bon de réduction sur votre prochaine commission',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('commission -'), findsNothing);
      expect(find.textContaining('-0'), findsNothing);
    },
  );

  testWidgets(
    'en anglais : bandeau sans pourcentage quand voucherFactor est absent',
    (tester) async {
      useEnglish();
      const info = ReferralInfo(
        code: 'DONY-XYZ42',
        shareUrl: 'https://dony.app/invite/DONY-XYZ42',
        totalInvited: 4,
        signedUp: 2,
        rewarded: 1,
        hasBeenReferred: false,
        activeVoucherCount: 1,
      );
      when(() => bloc.state).thenReturn(const ReferralLoaded(info));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('🎁 You have a discount voucher on your next service fee'),
        findsOneWidget,
      );
      expect(find.textContaining('commission -'), findsNothing);
      expect(find.textContaining('-0'), findsNothing);
    },
  );

  // 10. Message d'erreur affiché dans l'error view
  testWidgets('shows error message text when ReferralError', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const ReferralError(NetworkException('Erreur réseau')));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Une erreur est survenue'), findsOneWidget);
  });

  // 11. Trois bons actifs : le pluriel ICU reste identique à l'ancien texte.
  testWidgets('affiche le décompte avec trois bons actifs', (tester) async {
    final infoThreeVouchers = ReferralInfo(
      code: 'DONY-XYZ42',
      shareUrl: 'https://dony.app/invite/DONY-XYZ42',
      totalInvited: 4,
      signedUp: 2,
      rewarded: 3,
      hasBeenReferred: false,
      activeVoucherCount: 3,
      voucherFactor: 0.5,
      nextVoucherExpiresAt: DateTime(2027, 1, 15),
    );
    when(() => bloc.state).thenReturn(ReferralLoaded(infoThreeVouchers));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('🎁 Vous avez 3 bons de -50% sur vos prochaines commissions'),
      findsOneWidget,
    );
  });

  // 12. « Partager » dispatche ReferralShared (feuille système) avec le
  // texte réellement partagé, qui ne promet rien au filleul.
  testWidgets(
    'le bouton Partager dispatche ReferralShared avec le message fr',
    (tester) async {
      when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Partager'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ReferralShared>())),
      ).captured.cast<ReferralShared>();
      expect(captured, hasLength(1));
      expect(captured.single.channel, ReferralShareChannel.shareSheet);
      expect(
        captured.single.message,
        "Rejoignez-moi sur Yadony pour envoyer vos colis vers l'Afrique avec "
        'des voyageurs vérifiés. Mon code parrain : ${_testInfo.code} '
        '${_testInfo.shareUrl}',
      );
    },
  );

  testWidgets('WhatsApp dispatche ReferralShared canal whatsapp', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('WhatsApp'));
    await tester.pump();

    final captured = verify(
      () => bloc.add(captureAny(that: isA<ReferralShared>())),
    ).captured.cast<ReferralShared>();
    expect(captured.single.channel, ReferralShareChannel.whatsapp);
  });

  testWidgets('Copier dispatche ReferralLinkCopied', (tester) async {
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Copier'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<ReferralLinkCopied>()))).called(1);
    await tester.pump(const Duration(seconds: 5));
  });

  // ── Anglais ──────────────────────────────────────────────────────────────

  testWidgets('en anglais : titre, stats et hero card traduits', (
    tester,
  ) async {
    useEnglish();
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Referral'), findsOneWidget);
    expect(find.text('Signed up'), findsOneWidget);
    expect(find.text('First shipment done'), findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    expect(
      _normalized('€5 credit or 5% off your next shipment'),
      findsOneWidget,
    );
    expect(find.text('Share'), findsOneWidget);
    expect(
      find.text('🎁 You have a 50% voucher on your next service fee'),
      findsOneWidget,
    );
  });

  testWidgets('en anglais : date d\'expiration du bon (yMMMMd)', (
    tester,
  ) async {
    useEnglish();
    when(() => bloc.state).thenReturn(ReferralLoaded(_testInfo));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    // DateTime(2027, 1, 15) -> "January 15, 2027" (DateFormat.yMMMMd('en')).
    expect(find.text('Valid until January 15, 2027'), findsOneWidget);
  });

  // K3 : `state.error.message` (detail brut du serveur) remplacé par
  // ErrorPresenter.resolve, qui résout via ErrorCatalog selon la langue.
  testWidgets(
    'en anglais : ReferralError affiche le texte anglais du catalogue',
    (tester) async {
      useEnglish();
      when(
        () => bloc.state,
      ).thenReturn(const ReferralError(NetworkException('Erreur réseau')));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Erreur réseau'), findsNothing);
      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
    },
  );

  // 13. Non-régression du remplacement DateFormat('d MMMM yyyy') ->
  // DateFormat.yMMMMd(locale) : même rendu fr, plus le cas en, sur la date
  // canonique du chantier i18n.
  testWidgets(
    'date canonique 6 oct. 2026 : rendu fr identique à l\'ancien motif',
    (tester) async {
      final infoCanonicalDate = ReferralInfo(
        code: _testInfo.code,
        shareUrl: _testInfo.shareUrl,
        totalInvited: _testInfo.totalInvited,
        signedUp: _testInfo.signedUp,
        rewarded: _testInfo.rewarded,
        hasBeenReferred: _testInfo.hasBeenReferred,
        activeVoucherCount: _testInfo.activeVoucherCount,
        voucherFactor: _testInfo.voucherFactor,
        nextVoucherExpiresAt: DateTime(2026, 10, 6, 14, 5),
      );
      when(() => bloc.state).thenReturn(ReferralLoaded(infoCanonicalDate));

      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Valable jusqu\'au 6 octobre 2026'), findsOneWidget);
    },
  );

  testWidgets('date canonique 6 oct. 2026 : rendu en', (tester) async {
    useEnglish();
    final infoCanonicalDate = ReferralInfo(
      code: _testInfo.code,
      shareUrl: _testInfo.shareUrl,
      totalInvited: _testInfo.totalInvited,
      signedUp: _testInfo.signedUp,
      rewarded: _testInfo.rewarded,
      hasBeenReferred: _testInfo.hasBeenReferred,
      activeVoucherCount: _testInfo.activeVoucherCount,
      voucherFactor: _testInfo.voucherFactor,
      nextVoucherExpiresAt: DateTime(2026, 10, 6, 14, 5),
    );
    when(() => bloc.state).thenReturn(ReferralLoaded(infoCanonicalDate));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Valid until October 6, 2026'), findsOneWidget);
  });
}
