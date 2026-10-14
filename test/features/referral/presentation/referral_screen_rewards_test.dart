import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/referral/presentation/screens/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class _MockRepo extends Mock implements ReferralRepository {}

class _FakeReferralEvent extends Fake implements ReferralEvent {}

const _info = ReferralInfo(
  code: 'ABOU1890',
  shareUrl: 'https://yadony.com/r/ABOU1890',
  totalInvited: 4,
  signedUp: 4,
  rewarded: 1,
  hasBeenReferred: false,
  activeVoucherCount: 0,
  firstDelivery: 2,
  pendingRewardCount: 1,
  rewardWalletAmount: 5,
  rewardWalletCurrency: 'EUR',
  rewardDiscountPercent: 5,
);

final _referees = [
  const Referee(
    invitationId: 'inv-fatou',
    displayName: 'Fatou D.',
    status: RefereeStatus.firstDelivery,
    rewardStatus: RewardStatus.available,
  ),
  const Referee(
    invitationId: 'inv-moussa',
    displayName: 'Moussa K.',
    status: RefereeStatus.rewarded,
    rewardStatus: RewardStatus.chosen,
    rewardChoice: RewardChoice.walletCredit,
    walletAmount: 5,
    walletCurrency: 'EUR',
  ),
  Referee(
    invitationId: 'inv-awa',
    displayName: 'Awa S.',
    status: RefereeStatus.rewarded,
    rewardStatus: RewardStatus.chosen,
    rewardChoice: RewardChoice.discountCode,
    discountCode: RefereeDiscountCode(
      code: 'MERCI-7K2F',
      percent: 5,
      expiresAt: DateTime(2027, 4, 14),
    ),
  ),
  Referee(
    invitationId: 'inv-ibrahima',
    displayName: 'Ibrahima T.',
    signedUpAt: DateTime(2026, 10, 12),
  ),
];

Finder _normalized(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.replaceAll(RegExp(r'\s'), ' ') == text,
);

void main() {
  late _MockReferralBloc bloc;

  setUpAll(() async {
    registerFallbackValue(_FakeReferralEvent());
    await initializeDateFormatting('fr_FR');
  });

  setUp(() {
    bloc = _MockReferralBloc();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 9000);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);
  });

  Widget wrap({String? prefillCode}) => BlocProvider<ReferralBloc>.value(
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

  ReferralLoaded loaded({
    ReferralInfo info = _info,
    List<Referee>? referees,
    RefereesStatus status = RefereesStatus.loaded,
    String? choosing,
  }) => ReferralLoaded(
    info,
    referees: referees ?? _referees,
    refereesStatus: status,
    choosingInvitationId: choosing,
  );

  testWidgets('demande le chargement avec les filleuls à l\'ouverture', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ReferralInitial());

    await tester.pumpWidget(wrap());
    await tester.pump();

    final event =
        verify(
              () => bloc.add(captureAny(that: isA<ReferralLoadRequested>())),
            ).captured.single
            as ReferralLoadRequested;
    expect(event.includeReferees, isTrue);
  });

  testWidgets('carte « Récompense disponible » pour le filleul à choisir', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded());

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Récompense disponible'), findsOneWidget);
    expect(find.text('Fatou D. a fait son premier envoi'), findsOneWidget);
    expect(find.text('Choisir ma récompense'), findsOneWidget);
  });

  testWidgets('pendant l\'envoi du choix, le bouton est désactivé', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded(choosing: 'inv-fatou'));

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Choisir ma récompense'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('compteurs : inscrits, 1er envoi fait, gains en euros', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded());

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Inscrits'), findsOneWidget);
    expect(find.text('1er envoi fait'), findsWidgets);
    // Seul Moussa a choisi le crédit wallet : 5 €.
    expect(_normalized('5 €'), findsOneWidget);
  });

  testWidgets('filleuls : badges, sous-textes et code copiable', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded());

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('VOS FILLEULS'), findsOneWidget);
    expect(find.text('FD'), findsOneWidget);
    expect(find.text('À choisir'), findsOneWidget);
    expect(find.text('Obtenue'), findsNWidgets(2));
    expect(find.text('Pas encore d\'envoi'), findsOneWidget);
    expect(_normalized('5 € ajoutés à votre solde'), findsOneWidget);
    expect(find.text('MERCI-7K2F'), findsOneWidget);
    expect(find.text('Valable jusqu\'au 14 avr. 2027'), findsOneWidget);
    expect(find.text('Inscription le 12 oct.'), findsOneWidget);
  });

  testWidgets('code utilisé : ni code copiable ni validité', (tester) async {
    when(() => bloc.state).thenReturn(
      loaded(
        referees: const [
          Referee(
            invitationId: 'inv-awa',
            displayName: 'Awa S.',
            status: RefereeStatus.rewarded,
            rewardStatus: RewardStatus.chosen,
            rewardChoice: RewardChoice.discountCode,
            discountCode: RefereeDiscountCode(
              code: 'MERCI-7K2F',
              percent: 5,
              used: true,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Code utilisé'), findsOneWidget);
    expect(find.text('MERCI-7K2F'), findsNothing);
  });

  testWidgets('liste vide : message d\'invitation', (tester) async {
    when(() => bloc.state).thenReturn(loaded(referees: const []));

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text(
        'Personne n\'a encore utilisé votre lien. '
        'Partagez-le pour inviter vos proches.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ancien back (filleuls indisponibles) : section masquée', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      loaded(referees: const [], status: RefereesStatus.unavailable),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('VOS FILLEULS'), findsNothing);
    expect(find.text('Récompense disponible'), findsNothing);
    expect(find.text('COMMENT ÇA MARCHE'), findsOneWidget);
  });

  testWidgets('erreur sur les filleuls : Réessayer relance la liste', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(loaded(referees: const [], status: RefereesStatus.error));

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Impossible de charger vos filleuls.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    final event =
        verify(
              () =>
                  bloc.add(captureAny(that: isA<ReferralRefereesRequested>())),
            ).captured.single
            as ReferralRefereesRequested;
    expect(event.reset, isTrue);
  });

  testWidgets('comment ça marche : trois étapes avec le barème', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded());

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('COMMENT ÇA MARCHE'), findsOneWidget);
    expect(find.text('Partagez votre lien'), findsOneWidget);
    expect(find.text('Votre proche envoie un colis'), findsOneWidget);
    expect(find.text('Vous choisissez'), findsOneWidget);
    expect(
      _normalized(
        '5 € sur votre solde Yadony, ou un code de -5 % sur votre '
        'prochain envoi (valable 6 mois).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lien « code parrain » visible tant que non parrainé', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(loaded());

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('Vous avez un code parrain ? Saisissez-le'),
      findsOneWidget,
    );
  });

  testWidgets('lien « code parrain » masqué une fois parrainé', (tester) async {
    const referred = ReferralInfo(
      code: 'ABOU1890',
      shareUrl: 'https://yadony.com/r/ABOU1890',
      totalInvited: 0,
      signedUp: 0,
      rewarded: 0,
      hasBeenReferred: true,
      activeVoucherCount: 0,
    );
    when(() => bloc.state).thenReturn(loaded(info: referred));

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Vous avez un code parrain ? Saisissez-le'), findsNothing);
  });

  group('lien d\'invitation (prefillCode)', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      if (getIt.isRegistered<ReferralRepository>()) {
        getIt.unregister<ReferralRepository>();
      }
      getIt.registerSingleton<ReferralRepository>(repo);
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      getIt.registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );
    });

    tearDown(() {
      getIt.unregister<ReferralRepository>();
      getIt.unregister<AnalyticsService>();
    });

    testWidgets('non parrainé : la saisie s\'ouvre pré-remplie, sans envoi', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream<ReferralState>.fromIterable([loaded()]),
        initialState: const ReferralLoading(),
      );

      await tester.pumpWidget(wrap(prefillCode: 'ABOU1890'));
      await tester.pumpAndSettle();

      expect(find.text('Entrer un code parrain'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ABOU1890'), findsOneWidget);
      verifyNever(() => repo.redeemCode(any()));
    });

    testWidgets('déjà parrainé : aucune saisie proposée', (tester) async {
      const referred = ReferralInfo(
        code: 'ABOU1890',
        shareUrl: 'https://yadony.com/r/ABOU1890',
        totalInvited: 0,
        signedUp: 0,
        rewarded: 0,
        hasBeenReferred: true,
        activeVoucherCount: 0,
      );
      whenListen(
        bloc,
        Stream<ReferralState>.fromIterable([loaded(info: referred)]),
        initialState: const ReferralLoading(),
      );

      await tester.pumpWidget(wrap(prefillCode: 'ABOU1890'));
      await tester.pumpAndSettle();

      expect(find.text('Entrer un code parrain'), findsNothing);
    });
  });
}
