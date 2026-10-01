import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _bid({
  bool pending = true,
  String status = 'ACCEPTED',
  String? note,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  reschedule: TripRescheduleInfo(
    id: 'r1',
    reason: 'FLIGHT_CANCELLED',
    note: note,
    previousDepartureDate: DateTime(2026, 10, 9),
    newDepartureDate: DateTime(2026, 10, 13),
    decisionPending: pending,
    decisionDeadline: DateTime(2026, 10, 12, 18),
  ),
);

void main() {
  late _MockCancellationBloc bloc;

  setUpAll(
    () => registerFallbackValue(RescheduleDecisionRequested('x', keep: true)),
  );

  setUp(() {
    bloc = _MockCancellationBloc();
    whenListen(
      bloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
  });

  Widget host(BidModel bid, {bool isSender = true}) => MaterialApp(
    theme: AppTheme.light(),
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<CancellationBloc>.value(
        value: bloc,
        child: SingleChildScrollView(
          child: TripRescheduleCard(bid: bid, isSender: isSender),
        ),
      ),
    ),
  );

  testWidgets('expéditeur : nouvelle date, motif, message et ses deux choix', (
    tester,
  ) async {
    await tester.pumpWidget(host(_bid(note: 'Vol Air Sénégal annulé')));

    expect(find.text('Trajet reporté'), findsOneWidget);
    expect(find.textContaining('(vol annulé)'), findsOneWidget);
    expect(find.textContaining('9 oct.'), findsOneWidget);
    expect(find.textContaining('13 oct.'), findsOneWidget);
    expect(
      find.text('Message du voyageur : Vol Air Sénégal annulé'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sans réponse, votre colis reste sur le trajet.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reschedule-keep')));
    await tester.pump();

    final event =
        verify(() => bloc.add(captureAny())).captured.single
            as RescheduleDecisionRequested;
    expect(event.bidId, 'b1');
    expect(event.keep, isTrue);
  });

  testWidgets('se retirer demande une confirmation avant d\'envoyer', (
    tester,
  ) async {
    await tester.pumpWidget(host(_bid()));

    await tester.tap(find.byKey(const Key('reschedule-withdraw')));
    await tester.pumpAndSettle();
    expect(find.text('Annuler votre envoi ?'), findsOneWidget);
    expect(find.textContaining("d'autres trajets"), findsOneWidget);
    verifyNever(() => bloc.add(any()));

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Annuler sans frais'),
      ),
    );
    await tester.pumpAndSettle();

    final event =
        verify(() => bloc.add(captureAny())).captured.single
            as RescheduleDecisionRequested;
    expect(event.keep, isFalse);
  });

  testWidgets('colis déjà remis : la confirmation parle du code de retour', (
    tester,
  ) async {
    await tester.pumpWidget(host(_bid(status: 'HANDED_OVER')));

    await tester.tap(find.byKey(const Key('reschedule-withdraw')));
    await tester.pumpAndSettle();

    expect(find.textContaining('code de retour'), findsOneWidget);
  });

  testWidgets('voyageur : délai laissé à l\'expéditeur, aucun bouton', (
    tester,
  ) async {
    await tester.pumpWidget(host(_bid(), isSender: false));

    expect(find.textContaining("L'expéditeur a jusqu'au"), findsOneWidget);
    expect(find.byKey(const Key('reschedule-keep')), findsNothing);
  });

  testWidgets('décision close : information seule', (tester) async {
    await tester.pumpWidget(host(_bid(pending: false)));

    expect(find.text('Trajet reporté'), findsOneWidget);
    expect(find.byKey(const Key('reschedule-keep')), findsNothing);
    expect(find.textContaining('Répondez avant'), findsNothing);
  });
}
