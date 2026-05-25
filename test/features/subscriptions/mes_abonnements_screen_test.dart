import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/mes_abonnements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubscriptionsBloc
    extends MockBloc<SubscriptionsEvent, SubscriptionsState>
    implements SubscriptionsBloc {}

SubscriptionItem _item(String name, {bool hasNew = false}) => SubscriptionItem(
      travelerId: 't-$name',
      travelerName: name,
      isProAccount: false,
      averageRating: 4.8,
      ongoingTripsCount: 2,
      pushEnabled: false,
      hasNew: hasNew,
      lastAnnouncement: null,
    );

void main() {
  late MockSubscriptionsBloc bloc;

  setUp(() {
    bloc = MockSubscriptionsBloc();
    registerFallbackValue(const LoadSubscriptions());
  });

  Widget pump() => MaterialApp(
        home: BlocProvider<SubscriptionsBloc>.value(
          value: bloc,
          child: const MesAbonnementsScreen(),
        ),
      );

  testWidgets('liste les abonnements', (tester) async {
    when(() => bloc.state).thenReturn(
      SubscriptionsState(
        status: SubscriptionsStatus.success,
        items: [_item('Awa'), _item('Moussa')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Moussa'), findsOneWidget);
  });

  testWidgets('état vide affiche le message', (tester) async {
    when(() => bloc.state).thenReturn(
      const SubscriptionsState(status: SubscriptionsStatus.success),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Aucun abonnement'), findsOneWidget);
  });

  testWidgets('recherche filtre par nom', (tester) async {
    when(() => bloc.state).thenReturn(
      SubscriptionsState(
        status: SubscriptionsStatus.success,
        items: [_item('Awa'), _item('Moussa')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pump();
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Moussa'), findsNothing);
  });
}
