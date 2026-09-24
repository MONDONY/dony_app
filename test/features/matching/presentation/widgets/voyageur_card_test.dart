import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/voyageur_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

BidModel _bid({
  String? travelerName,
  int? travelerTotalTrips,
  bool travelerKycVerified = false,
  bool travelerKiloPro = false,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: 'ACCEPTED',
  travelerId: 't1',
  travelerName: travelerName,
  travelerTotalTrips: travelerTotalTrips,
  travelerKycVerified: travelerKycVerified,
  travelerKiloPro: travelerKiloPro,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: BlocProvider<ConversationOpenBloc>.value(
          value: conv,
          child: VoyageurCard(bid: bid),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('repli traduit quand le voyageur n a pas de nom', (tester) async {
    await _pump(tester, _bid());

    expect(find.text('Voyageur'), findsOneWidget);
    expect(find.text('VOYAGEUR'), findsOneWidget);
  });

  testWidgets('nombre de trajets composé via travelerTripsCount', (
    tester,
  ) async {
    await _pump(tester, _bid(travelerName: 'Moussa D.', travelerTotalTrips: 3));

    expect(find.textContaining('· 3 trajets'), findsOneWidget);
  });

  testWidgets('badges identité et Kilo Pro réutilisent les clés listing', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        travelerName: 'Moussa D.',
        travelerKycVerified: true,
        travelerKiloPro: true,
      ),
    );

    expect(find.text('Identité'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
  });

  testWidgets('en anglais : étiquette de rôle et repli traduits', (
    tester,
  ) async {
    useEnglish();
    await _pump(tester, _bid(travelerTotalTrips: 1));

    expect(find.text('TRAVELER'), findsOneWidget);
    expect(find.text('Traveler'), findsOneWidget);
    expect(find.textContaining('· 1 trip'), findsOneWidget);
  });
}
