import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _bid({
  required String status,
  bool voyageurConfirmed = false,
  double? total = 48,
  DateTime? windowEnd,
  String? recipientName = 'Awa S.',
}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      weightKg: 5,
      totalAmountEur: total,
      voyageurConfirmed: voyageurConfirmed,
      handoverWindowEnd: windowEnd,
      recipientName: recipientName,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final cancel = _MockCancelBloc();
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BlocProvider<CancellationBloc>.value(
          value: cancel,
          child: TravelerHeroCard(bid: bid),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('PENDING → gain mis en avant', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'));
    expect(find.textContaining('Nouvelle demande'), findsOneWidget);
    expect(find.textContaining('48.00'), findsOneWidget);
  });

  testWidgets('ACCEPTED présence non confirmée → récupérez le colis',
      (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
  });

  testWidgets('ACCEPTED présence confirmée → scannez le colis',
      (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED', voyageurConfirmed: true));
    expect(find.textContaining('Scannez le colis'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT → colis en route', (tester) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.textContaining('en route'), findsOneWidget);
  });

  testWidgets('COMPLETED → livraison confirmée', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.textContaining('Livraison confirmée'), findsOneWidget);
  });

  testWidgets('fenêtre dépassée → bouton signaler absence expéditeur',
      (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.textContaining('Fenêtre de remise dépassée'), findsOneWidget);
    expect(
      find.textContaining("Signaler l'absence de l'expéditeur"),
      findsOneWidget,
    );
  });

  testWidgets('REJECTED → rien (SizedBox.shrink)', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(find.textContaining('Nouvelle demande'), findsNothing);
    expect(find.textContaining('Livraison'), findsNothing);
  });
}
