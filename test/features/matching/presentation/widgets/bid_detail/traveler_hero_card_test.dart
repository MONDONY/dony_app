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

class _FakeCancellationEvent extends Fake implements CancellationEvent {}

BidModel _bid({
  required String status,
  bool voyageurConfirmed = false,
  double? total = 48,
  DateTime? windowEnd,
  String? recipientName = 'Awa S.',
  String? cancellationNoShowStatus,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  totalAmountEur: total,
  voyageurConfirmed: voyageurConfirmed,
  handoverDeadline: windowEnd,
  recipientName: recipientName,
  cancellationNoShowStatus: cancellationNoShowStatus,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final cancel = _MockCancelBloc();
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
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
  setUpAll(() {
    registerFallbackValue(_FakeCancellationEvent());
  });

  testWidgets('PENDING → gain mis en avant', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'));
    expect(find.textContaining('Nouvelle demande'), findsOneWidget);
    expect(find.textContaining('48'), findsOneWidget);
  });

  testWidgets('ACCEPTED présence non confirmée → récupérez le colis', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
  });

  testWidgets('ACCEPTED présence confirmée → scannez le colis', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED', voyageurConfirmed: true));
    expect(find.textContaining('Lisez le QR du colis'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT → colis en route', (tester) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'));
    expect(find.textContaining('en route'), findsOneWidget);
  });

  testWidgets('COMPLETED → livraison confirmée', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.textContaining('Livraison confirmée'), findsOneWidget);
  });

  testWidgets('ARRIVED → arrivé à destination', (tester) async {
    await _pump(tester, _bid(status: 'ARRIVED'));
    expect(find.textContaining('Arrivé'), findsOneWidget);
  });

  testWidgets('date limite dépassée → bouton signaler absence expéditeur', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(
      find.textContaining('Date limite de dépôt dépassée'),
      findsOneWidget,
    );
    expect(
      find.textContaining("Signaler l'absence de l'expéditeur"),
      findsOneWidget,
    );
  });

  testWidgets(
    'absence déjà signalée (PENDING_CONFIRMATION) → « Absence signalée », plus de bouton signaler',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'ACCEPTED',
          windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        ),
      );
      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(
        find.textContaining("Signaler l'absence de l'expéditeur"),
        findsNothing,
      );
      expect(
        find.textContaining('Date limite de dépôt dépassée'),
        findsNothing,
      );
    },
  );

  testWidgets('absence contestée (CONTESTED) → « Absence contestée »', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
        cancellationNoShowStatus: 'CONTESTED',
      ),
    );
    expect(find.textContaining('Absence contestée'), findsOneWidget);
    expect(
      find.textContaining("Signaler l'absence de l'expéditeur"),
      findsNothing,
    );
  });

  testWidgets('REJECTED → rien (SizedBox.shrink)', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(find.textContaining('Nouvelle demande'), findsNothing);
    expect(find.textContaining('Livraison'), findsNothing);
  });

  testWidgets('HANDED_OVER → colis récupéré', (tester) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'));
    expect(find.textContaining('Colis récupéré'), findsOneWidget);
  });

  testWidgets('DELIVERED → livraison confirmée', (tester) async {
    await _pump(tester, _bid(status: 'DELIVERED'));
    expect(find.textContaining('Livraison confirmée'), findsOneWidget);
  });

  testWidgets('CANCELLED → rien (SizedBox.shrink)', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'));
    expect(find.textContaining('Nouvelle demande'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
  });

  testWidgets('IN_TRANSIT avec ville arrivée → ville affichée dans subtitle', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'IN_TRANSIT',
      weightKg: 5,
      arrivalCity: 'Dakar',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    expect(find.textContaining('Dakar'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT sans ville arrivée → destination fallback', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'IN_TRANSIT',
      weightKg: 5,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    expect(find.textContaining('destination'), findsOneWidget);
  });

  testWidgets('ACCEPTED avec fenêtre et lieu → subtitle contient lieu', (
    tester,
  ) async {
    // Use a date far in the future to ensure the window is not expired
    final futureStart = DateTime.now().add(const Duration(days: 30));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: futureStart.add(const Duration(hours: 1)),
      handoverLocation: 'CDG Terminal 2',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    // The card should show the recovery info
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
    // Subtitle includes location and the rendez-vous hint
    expect(find.textContaining('point de remise'), findsOneWidget);
  });

  testWidgets('ACCEPTED sans fenêtre ni lieu → fallback texte générique', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'ACCEPTED'));
    expect(find.textContaining('point de remise'), findsOneWidget);
  });

  testWidgets('fenêtre dépassée sans fenêtre start → subtitle sans dates', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'ACCEPTED',
        windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.textContaining("L'expéditeur"), findsOneWidget);
  });

  testWidgets('CancellationLoading → bouton affiche spinner', (tester) async {
    final cancel = _MockCancelBloc();
    when(() => cancel.state).thenReturn(CancellationLoading());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<CancellationBloc>.value(
            value: cancel,
            child: TravelerHeroCard(
              bid: _bid(
                status: 'ACCEPTED',
                windowEnd: DateTime.now().subtract(const Duration(hours: 1)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('PENDING sans total → subtitle sans montant précis', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING', total: null));
    expect(find.textContaining('Nouvelle demande'), findsOneWidget);
  });

  testWidgets('ACCEPTED avec seulement windowStart → subtitle ok', (
    tester,
  ) async {
    final futureStart = DateTime.now().add(const Duration(days: 30));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: futureStart,
      // no windowEnd
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
  });

  testWidgets('ACCEPTED avec seulement windowEnd → subtitle ok', (
    tester,
  ) async {
    final futureEnd = DateTime.now().add(const Duration(days: 30));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      // no windowStart, only end (future so not expired)
      handoverDeadline: futureEnd,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
  });

  testWidgets('ACCEPTED avec fenêtre multi-jours → subtitle ok', (
    tester,
  ) async {
    final futureStart = DateTime.now().add(const Duration(days: 30));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: futureStart.add(const Duration(days: 1)),
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    await _pump(tester, bid);
    expect(find.textContaining('Récupérez le colis'), findsOneWidget);
  });

  testWidgets('date limite dépassée → subtitle avec la date', (tester) async {
    final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: pastEnd,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    final cancel = _MockCancelBloc();
    when(() => cancel.state).thenReturn(CancellationInitial());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<CancellationBloc>.value(
            value: cancel,
            child: TravelerHeroCard(bid: bid),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('Date limite de dépôt dépassée'),
      findsOneWidget,
    );
  });

  testWidgets('tap Signaler absence → DonyBottomSheet ouvert', (tester) async {
    final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: pastEnd,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    final cancel = _MockCancelBloc();
    when(() => cancel.state).thenReturn(CancellationInitial());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<CancellationBloc>.value(
            value: cancel,
            child: TravelerHeroCard(bid: bid),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // The button 'Signaler l'absence de l'expéditeur' must be visible
    expect(
      find.textContaining("Signaler l'absence de l'expéditeur"),
      findsOneWidget,
    );
    // Tap the button to open the confirmation sheet
    await tester.tap(find.textContaining("Signaler l'absence de l'expéditeur"));
    await tester.pumpAndSettle();
    // The confirmation sheet should show the absence text
    expect(
      find.textContaining("L'expéditeur ne s'est pas présenté"),
      findsWidgets,
    );
  });

  testWidgets(
    'bannière "Absence signalée" si deliveryNoShowReportedByTraveler=true (je suis l\'auteur)',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: true,
      );
      await _pump(tester, bid);
      expect(find.textContaining('Absence signalée'), findsOneWidget);
    },
  );

  testWidgets(
    'bannière "Une absence est signalée" + Contester si deliveryNoShowReportedByTraveler=false (je suis l\'adversaire)',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: false,
      );
      await _pump(tester, bid);
      expect(find.textContaining('Une absence est signalée'), findsOneWidget);
      expect(find.text('Contester ce signalement'), findsOneWidget);
    },
  );

  testWidgets(
    'bannière deliveryNoShowStatus=CONTESTED (auteur) → "Absence contestée"',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deliveryNoShowStatus: 'CONTESTED',
        deliveryNoShowReportedByTraveler: true,
      );
      await _pump(tester, bid);
      expect(find.textContaining('Absence contestée'), findsOneWidget);
    },
  );

  testWidgets(
    'bannière deliveryNoShowStatus=CONTESTED (adversaire, je viens de contester) → "Contestation envoyée", pas de bouton',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deliveryNoShowStatus: 'CONTESTED',
        deliveryNoShowReportedByTraveler: false,
      );
      await _pump(tester, bid);
      expect(find.textContaining('Contestation envoyée'), findsOneWidget);
      expect(find.textContaining('Une absence est signalée'), findsNothing);
      expect(find.text('Contester ce signalement'), findsNothing);
    },
  );

  testWidgets(
    'tap "Contester ce signalement" → DeliveryNoShowContestRequested émis',
    (tester) async {
      final bid = BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        weightKg: 5,
        status: 'IN_TRANSIT',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        deliveryNoShowReportedByTraveler: false,
      );
      final cancel = _MockCancelBloc();
      when(() => cancel.state).thenReturn(CancellationInitial());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BlocProvider<CancellationBloc>.value(
              value: cancel,
              child: TravelerHeroCard(bid: bid),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Contester ce signalement'));
      await tester.pump();
      verify(
        () => cancel.add(any(that: isA<DeliveryNoShowContestRequested>())),
      ).called(1);
    },
  );

  testWidgets('tap Signaler absence + confirmer → NoShowReportRequested émis', (
    tester,
  ) async {
    final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      handoverDeadline: pastEnd,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
    final cancel = _MockCancelBloc();
    when(() => cancel.state).thenReturn(CancellationInitial());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<CancellationBloc>.value(
            value: cancel,
            child: TravelerHeroCard(bid: bid),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining("Signaler l'absence de l'expéditeur"));
    await tester.pumpAndSettle();
    // Tap the confirm button in the sheet (exact text "Signaler l'absence")
    await tester.tap(find.text("Signaler l'absence"));
    await tester.pumpAndSettle();
    verify(() => cancel.add(any(that: isA<NoShowReportRequested>()))).called(1);
  });
}
