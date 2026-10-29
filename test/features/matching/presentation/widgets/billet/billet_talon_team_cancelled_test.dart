import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_rejection_reason.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// FLUTTER-R4 : colis annulé par l'équipe Yadony depuis l'admin. yadony-back
// #567 pose TEAM_TRAVELER_UNAVAILABLE ou TEAM_CANCELLED dans rejectionReason.

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

const _title = "Annulé par l'équipe Yadony";
const _unreachable = 'Le voyageur est injoignable.';
const _refund =
    "Si vous avez payé dans l'app, votre paiement vous est remboursé.";
const _hint = 'Pour en savoir plus, contactez le support.';
const _button = 'Contacter le support';

BidModel _bid({
  String id = 'bid-1',
  String? rejectionReason,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  String? trackingNumber,
  String? returnCode,
  DateTime? returnDeadline,
}) => BidModel(
  id: id,
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: 'CANCELLED',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  rejectionReason: rejectionReason,
  paymentMethod: paymentMethod,
  trackingNumber: trackingNumber,
  returnCode: returnCode,
  returnDeadline: returnDeadline,
);

Widget _talon(BidModel bid, bool isSender) {
  final t = _MockTrackingBloc();
  final b = _MockBidBloc();
  when(() => t.state).thenReturn(TrackingInitial());
  when(() => b.state).thenReturn(BidInitial());
  return MultiBlocProvider(
    providers: [
      BlocProvider<TrackingBloc>.value(value: t),
      BlocProvider<BidBloc>.value(value: b),
    ],
    child: SingleChildScrollView(
      child: BilletTalon(bid: bid, isSender: isSender),
    ),
  );
}

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: _talon(bid, isSender)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

String _detail(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('billet-team-cancelled-detail')))
    .data!;

void main() {
  group('TeamCancellationReason.fromCode', () {
    test('reconnaît les deux marqueurs du back', () {
      expect(
        TeamCancellationReason.fromCode('TEAM_TRAVELER_UNAVAILABLE'),
        TeamCancellationReason.travelerUnavailable,
      );
      expect(
        TeamCancellationReason.fromCode('TEAM_CANCELLED'),
        TeamCancellationReason.cancelled,
      );
    });

    test('null pour un motif absent, inconnu ou de refus', () {
      expect(TeamCancellationReason.fromCode(null), isNull);
      expect(TeamCancellationReason.fromCode('TEAM_SOMETHING_ELSE'), isNull);
      expect(TeamCancellationReason.fromCode('NO_CAPACITY'), isNull);
    });

    test('les marqueurs de l’équipe ne sont pas des motifs de refus', () {
      // BidRejectionReason.values alimente le choix du voyageur au refus.
      expect(BidRejectionReason.fromCode('TEAM_CANCELLED'), isNull);
      expect(BidRejectionReason.fromCode('TEAM_TRAVELER_UNAVAILABLE'), isNull);
      expect(BidRejectionReason.fromCode('NO_CAPACITY'), isNotNull);
    });
  });

  group('expéditeur', () {
    testWidgets('voyageur injoignable, carte : motif, remboursement, bouton', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE'),
        true,
      );
      expect(find.text(_title), findsOneWidget);
      expect(_detail(tester), '$_unreachable $_refund');
      expect(find.text(_button), findsOneWidget);
      // Le titre remplace le message terminal générique.
      expect(find.text('Cette demande est terminée.'), findsNothing);
    });

    testWidgets('voyageur injoignable, espèces : pas de remboursement promis', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE',
          paymentMethod: BidPaymentMethod.cash,
        ),
        true,
      );
      expect(_detail(tester), _unreachable);
      expect(find.text(_button), findsOneWidget);
    });

    testWidgets('autre motif, carte : ligne neutre sans motif, bouton', (
      tester,
    ) async {
      await _pump(tester, _bid(rejectionReason: 'TEAM_CANCELLED'), true);
      expect(find.text(_title), findsOneWidget);
      expect(_detail(tester), _refund);
      expect(find.textContaining('injoignable'), findsNothing);
      expect(find.text(_button), findsOneWidget);
    });

    testWidgets(
      'autre motif : mobile money remboursé, espèces invité au support',
      (tester) async {
        await _pump(
          tester,
          _bid(
            rejectionReason: 'TEAM_CANCELLED',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
          true,
        );
        // Mobile money se paie dans l'app : le remboursement reste annoncé.
        expect(_detail(tester), _refund);

        await _pump(
          tester,
          _bid(
            rejectionReason: 'TEAM_CANCELLED',
            paymentMethod: BidPaymentMethod.cash,
          ),
          true,
        );
        expect(_detail(tester), _hint);
      },
    );

    testWidgets('rejectionReason nul : affichage inchangé (ancien back)', (
      tester,
    ) async {
      await _pump(tester, _bid(), true);
      expect(find.text('Cette demande est terminée.'), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(find.text(_button), findsNothing);
    });

    testWidgets('marqueur inconnu : affichage inchangé', (tester) async {
      await _pump(tester, _bid(rejectionReason: 'TEAM_NEW_CODE'), true);
      expect(find.text('Cette demande est terminée.'), findsOneWidget);
      expect(find.text(_title), findsNothing);
    });

    testWidgets('colis à restituer : bloc équipe puis code de retour', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE',
          returnCode: '123456',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
        true,
      );
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_button), findsOneWidget);
      expect(find.text('Code de retour'), findsOneWidget);
    });
  });

  group('voyageur', () {
    testWidgets('voyageur injoignable : motif à la deuxième personne', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE'),
        false,
      );
      expect(find.text(_title), findsOneWidget);
      expect(_detail(tester), "L'équipe n'a pas réussi à vous joindre.");
      expect(find.textContaining('rembours'), findsNothing);
      expect(find.text(_button), findsOneWidget);
    });

    testWidgets('autre motif : ligne neutre, bouton', (tester) async {
      await _pump(tester, _bid(rejectionReason: 'TEAM_CANCELLED'), false);
      expect(_detail(tester), _hint);
      expect(find.text(_button), findsOneWidget);
    });
  });

  group('« Contacter le support »', () {
    Future<List<GoRouterState>> pumpRouter(
      WidgetTester tester,
      BidModel bid, {
      bool isSender = true,
    }) async {
      final visited = <GoRouterState>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: _talon(bid, isSender)),
          ),
          GoRoute(
            path: '/support',
            builder: (_, state) {
              visited.add(state);
              return const Scaffold(body: Text('support'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(_button));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      return visited;
    }

    testWidgets('ouvre /support avec une demande Colis préremplie', (
      tester,
    ) async {
      final visited = await pumpRouter(
        tester,
        _bid(
          rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE',
          trackingNumber: 'YAD-0042',
        ),
      );
      expect(visited, hasLength(1));
      expect(visited.single.uri.toString(), '/support');
      expect(
        visited.single.extra,
        const SupportTicketDraft(
          category: 'PACKAGE',
          subject: "Colis YAD-0042 annulé par l'équipe",
          message:
              "Bonjour, mon colis a été annulé par l'équipe Yadony. "
              "J'aimerais en savoir plus.",
          origin: 'team_cancelled_parcel',
        ),
      );
      expect(find.text('support'), findsOneWidget);
    });

    testWidgets('sans numéro de suivi : début de l’identifiant', (
      tester,
    ) async {
      final visited = await pumpRouter(
        tester,
        _bid(id: 'abcdef12-3456-7890', rejectionReason: 'TEAM_CANCELLED'),
      );
      final draft = visited.single.extra! as SupportTicketDraft;
      expect(draft.subject, "Colis ABCDEF12 annulé par l'équipe");
    });

    // Le voyageur ne reçoit pas le numéro de suivi d'un colis annulé : le
    // sujet du ticket ne le contient pas, même si le champ est présent.
    testWidgets('voyageur : jamais le numéro de suivi, début de '
        'l’identifiant', (tester) async {
      final visited = await pumpRouter(
        tester,
        _bid(
          id: 'abcdef12-3456-7890',
          rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE',
          trackingNumber: 'YAD-0042',
        ),
        isSender: false,
      );
      final draft = visited.single.extra! as SupportTicketDraft;
      expect(draft.subject, "Colis ABCDEF12 annulé par l'équipe");
      expect(draft.subject, isNot(contains('YAD-0042')));
    });

    testWidgets('voyageur sans numéro : début de l’identifiant', (
      tester,
    ) async {
      final visited = await pumpRouter(
        tester,
        _bid(id: 'abcdef12-3456-7890', rejectionReason: 'TEAM_CANCELLED'),
        isSender: false,
      );
      final draft = visited.single.extra! as SupportTicketDraft;
      expect(draft.subject, "Colis ABCDEF12 annulé par l'équipe");
    });
  });

  testWidgets('en anglais : titre, motif et bouton traduits', (tester) async {
    useEnglish();
    await _pump(
      tester,
      _bid(rejectionReason: 'TEAM_TRAVELER_UNAVAILABLE'),
      true,
    );
    expect(find.text('Cancelled by the Yadony team'), findsOneWidget);
    expect(
      _detail(tester),
      'The traveler cannot be reached. '
      'If you paid in the app, your payment is refunded.',
    );
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });
}
