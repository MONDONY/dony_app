import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/presentation/widgets/referral_reward_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class _FakeReferralEvent extends Fake implements ReferralEvent {}

const _info = ReferralInfo(
  code: 'ABOU1890',
  shareUrl: 'https://yadony.com/r/ABOU1890',
  totalInvited: 1,
  signedUp: 1,
  rewarded: 0,
  hasBeenReferred: false,
  activeVoucherCount: 0,
);

const _referee = Referee(
  invitationId: 'inv-1',
  displayName: 'Fatou D.',
  status: RefereeStatus.firstDelivery,
  rewardStatus: RewardStatus.available,
);

Finder _normalized(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.replaceAll(RegExp(r'\s'), ' ') == text,
);

void main() {
  late _MockReferralBloc bloc;
  late StreamController<ReferralState> states;

  setUpAll(() async {
    registerFallbackValue(_FakeReferralEvent());
    await initializeDateFormatting('fr_FR');
  });

  setUp(() {
    bloc = _MockReferralBloc();
    states = StreamController<ReferralState>.broadcast();
    whenListen(
      bloc,
      states.stream,
      initialState: const ReferralLoaded(_info, referees: [_referee]),
    );
  });

  tearDown(() => states.close());

  Future<Referee?> Function()? opener;

  Future<void> openChoice(WidgetTester tester) async {
    Referee? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await ReferralRewardChoiceSheet.show(
                    context,
                    bloc: bloc,
                    referee: _referee,
                    info: _info,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    opener = () async => result;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('feuille de choix', () {
    testWidgets('titre, nom du filleul, deux options et la mention', (
      tester,
    ) async {
      await openChoice(tester);

      expect(find.text('Choisissez votre récompense'), findsOneWidget);
      expect(
        find.text("Merci d'avoir invité Fatou D. Ce choix est définitif."),
        findsOneWidget,
      );
      expect(_normalized('5 € sur mon solde'), findsOneWidget);
      expect(_normalized('-5 % sur mon prochain envoi'), findsOneWidget);
      expect(
        find.text(
          'Le solde Yadony sert à régler la commission Yadony des demandes '
          "payées en espèces. Il n'est pas retirable en espèces.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('le libellé du bouton suit l\'option choisie', (tester) async {
      await openChoice(tester);

      expect(_normalized('Recevoir 5 €'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('referral-choice-code')));
      await tester.pumpAndSettle();
      expect(_normalized('Recevoir mon code -5 %'), findsOneWidget);
      expect(_normalized('Recevoir 5 €'), findsNothing);
    });

    testWidgets('le bouton envoie le choix sélectionné', (tester) async {
      await openChoice(tester);

      await tester.tap(find.byKey(const ValueKey('referral-choice-code')));
      await tester.pumpAndSettle();
      await tester.tap(_normalized('Recevoir mon code -5 %'));
      await tester.pump();

      final event =
          verify(
                () => bloc.add(captureAny(that: isA<ReferralRewardChosen>())),
              ).captured.single
              as ReferralRewardChosen;
      expect(event.invitationId, 'inv-1');
      expect(event.choice, RewardChoice.discountCode);
    });

    testWidgets('pendant l\'envoi : bouton en chargement, aucun second envoi', (
      tester,
    ) async {
      await openChoice(tester);

      states.add(
        const ReferralLoaded(
          _info,
          referees: [_referee],
          choosingInvitationId: 'inv-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.byType(CircularProgressIndicator),
        warnIfMissed: false,
      );
      await tester.pump();
      verifyNever(() => bloc.add(any(that: isA<ReferralRewardChosen>())));
    });

    testWidgets('choix accepté : la feuille se ferme avec le filleul', (
      tester,
    ) async {
      await openChoice(tester);
      const updated = Referee(
        invitationId: 'inv-1',
        rewardStatus: RewardStatus.chosen,
        rewardChoice: RewardChoice.walletCredit,
        walletAmount: 5,
      );

      states.add(
        const ReferralLoaded(_info, referees: [updated], rewardResult: updated),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choisissez votre récompense'), findsNothing);
      expect(await opener!(), updated);
    });

    testWidgets('409 déjà choisie : la feuille se ferme', (tester) async {
      await openChoice(tester);

      states.add(
        const ReferralLoaded(
          _info,
          rewardError: ConflictException(
            'x',
            code: 'referral-reward-already-chosen',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choisissez votre récompense'), findsNothing);
      expect(await opener!(), isNull);
    });

    testWidgets('en anglais : options et bouton traduits', (tester) async {
      useEnglish();
      await openChoice(tester);

      expect(find.text('Choose your reward'), findsOneWidget);
      expect(_normalized('€5 on my balance'), findsOneWidget);
      expect(_normalized('Get €5'), findsOneWidget);
    });
  });

  group('confirmation', () {
    Future<void> pumpConfirmation(WidgetTester tester, Referee referee) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReferralRewardConfirmation(referee: referee, info: _info),
            ),
          ),
        );

    testWidgets('code : le code, sa validité et une seule utilisation', (
      tester,
    ) async {
      await pumpConfirmation(
        tester,
        Referee(
          invitationId: 'inv-1',
          rewardStatus: RewardStatus.chosen,
          rewardChoice: RewardChoice.discountCode,
          discountCode: RefereeDiscountCode(
            code: 'MERCI-ABOU-7K2F',
            percent: 5,
            expiresAt: DateTime(2027, 4, 14),
          ),
        ),
      );

      expect(_normalized('Votre code -5 % est prêt'), findsOneWidget);
      expect(find.text('MERCI-ABOU-7K2F'), findsOneWidget);
      expect(find.text('Valable jusqu\'au 14 avr. 2027'), findsOneWidget);
      expect(find.text('1 utilisation'), findsOneWidget);
      expect(find.text('Copier'), findsOneWidget);
    });

    testWidgets('crédit : le montant ajouté au solde, aucun code', (
      tester,
    ) async {
      await pumpConfirmation(
        tester,
        const Referee(
          invitationId: 'inv-1',
          rewardStatus: RewardStatus.chosen,
          rewardChoice: RewardChoice.walletCredit,
          walletAmount: 5,
          walletCurrency: 'EUR',
        ),
      );

      expect(_normalized('5 € ajoutés à votre solde'), findsOneWidget);
      expect(find.text('1 utilisation'), findsNothing);
      expect(find.text('Copier'), findsNothing);
    });
  });
}
