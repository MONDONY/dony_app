import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _bid(String status, {String? trackingToken}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  trackingToken: trackingToken,
  totalAmountEur: 48,
  senderName: 'Mariama D.',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final conv = _MockConvBloc();
  final cancel = _MockCancelBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ConversationOpenBloc>.value(value: conv),
            BlocProvider<CancellationBloc>.value(value: cancel),
          ],
          child: TravelerDetailBody(bid: bid),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('ACCEPTED → hero + contact + gain présents', (tester) async {
    await _pump(tester, _bid('ACCEPTED'));
    expect(find.byType(TravelerHeroCard), findsOneWidget);
    expect(find.byType(ExpediteurContactCard), findsOneWidget);
    expect(find.byType(TravelerGainCard), findsOneWidget);
  });

  testWidgets('PENDING → pas de carte contact (statut non actif)', (
    tester,
  ) async {
    await _pump(tester, _bid('PENDING'));
    expect(find.byType(ExpediteurContactCard), findsNothing);
    expect(find.byType(TravelerGainCard), findsOneWidget);
  });

  testWidgets('trackingToken présent → pas de lien ni action suivi voyageur', (
    tester,
  ) async {
    await _pump(tester, _bid('ACCEPTED', trackingToken: 'public-token'));

    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Plus de détails'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Plus de détails'));
    await tester.pumpAndSettle();

    expect(find.text('LIEN DE SUIVI'), findsNothing);
    expect(find.textContaining('public-token'), findsNothing);
  });
}
