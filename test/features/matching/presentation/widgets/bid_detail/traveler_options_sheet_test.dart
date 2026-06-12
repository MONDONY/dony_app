import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_options_sheet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

BidModel _bid({String status = 'ACCEPTED', String? token = 'tok'}) => BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      weightKg: 5,
      trackingToken: token,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

Future<void> _open(WidgetTester tester, BidModel bid) async {
  final bidBloc = _MockBidBloc();
  final conv = _MockConvBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<ConversationOpenBloc>.value(value: conv),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTravelerOptionsSheet(context, bid),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ACCEPTED → contacter / détails / partager / signaler / annuler',
      (tester) async {
    await _open(tester, _bid(status: 'ACCEPTED'));
    expect(find.text("Contacter l'expéditeur"), findsOneWidget);
    expect(find.text('Détails du colis'), findsOneWidget);
    expect(find.text('Partager le suivi'), findsOneWidget);
    expect(find.text("Signaler l'expéditeur"), findsOneWidget);
    expect(find.text('Annuler le trajet'), findsOneWidget);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets("REJECTED → supprimer, pas d'annuler", (tester) async {
    await _open(tester, _bid(status: 'REJECTED', token: null));
    expect(find.text('Supprimer cette demande'), findsOneWidget);
    expect(find.text('Annuler le trajet'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);
  });
}
