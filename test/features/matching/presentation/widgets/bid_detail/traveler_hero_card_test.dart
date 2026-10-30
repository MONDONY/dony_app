import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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
  DateTime? contestationDeadline,
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
  contestationDeadline: contestationDeadline,
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
    expect(
      find.textContaining('vous demande de transporter son colis'),
      findsOneWidget,
    );
    expect(find.textContaining('48'), findsOneWidget);
  });

  // Les cartes « prochaine étape » d'information ont été retirées (décision
  // du propriétaire) : le footer et le billet disent déjà l'étape. Seules
  // restent la demande à décider, l'attente du paiement et les alertes.
  group('étapes du transport : plus de carte d\'information', () {
    final future = DateTime.now().add(const Duration(days: 30));
    final cases = <String, BidModel>{
      'ACCEPTED, présence à confirmer': _bid(status: 'ACCEPTED'),
      'ACCEPTED, présence confirmée': _bid(
        status: 'ACCEPTED',
        voyageurConfirmed: true,
      ),
      'ACCEPTED, date limite à venir et lieu': BidModel(
        id: 'b1',
        announcementId: 'a1',
        senderId: 's1',
        status: 'ACCEPTED',
        weightKg: 5,
        handoverDeadline: future,
        handoverLocation: 'CDG Terminal 2',
        createdAt: DateTime(2026, 5),
        updatedAt: DateTime(2026, 5),
      ),
      'HANDED_OVER': _bid(status: 'HANDED_OVER'),
      'IN_TRANSIT': _bid(status: 'IN_TRANSIT'),
      'ARRIVED': _bid(status: 'ARRIVED'),
      'COMPLETED': _bid(status: 'COMPLETED'),
      'DELIVERED': _bid(status: 'DELIVERED'),
    };
    for (final MapEntry(key: label, value: bid) in cases.entries) {
      testWidgets('$label → rien', (tester) async {
        await _pump(tester, bid);
        expect(TravelerHeroCard.isShown(bid), isFalse);
        expect(TravelerHeroCard.hasAction(bid), isFalse);
        expect(find.byType(Text), findsNothing);
        expect(tester.getSize(find.byType(TravelerHeroCard)).height, 0);
      });
    }
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

  testWidgets(
    'absence signalée sans échéance serveur → délai fixe de 24 h (aligné sur le back)',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'ACCEPTED',
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        ),
      );
      expect(
        find.textContaining("L'expéditeur a 24 h pour confirmer ou contester"),
        findsOneWidget,
      );
      expect(find.textContaining('48 h'), findsNothing);
    },
  );

  testWidgets(
    'absence signalée avec contestationDeadline → échéance réelle affichée',
    (tester) async {
      final deadline = DateTime.now().add(const Duration(hours: 20));
      await _pump(
        tester,
        _bid(
          status: 'ACCEPTED',
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
          contestationDeadline: deadline,
        ),
      );
      expect(find.textContaining("L'expéditeur a jusqu'au "), findsOneWidget);
      expect(
        find.textContaining('pour confirmer ou contester'),
        findsOneWidget,
      );
      expect(find.textContaining('24 h'), findsNothing);
      expect(find.textContaining('48 h'), findsNothing);
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

  // Le scan de départ lève une déclaration encore en attente : le back la
  // passe en RESOLVED et le colis, relu au retour du scan, n'affiche plus
  // l'alerte.
  testWidgets('absence levée par le scan (RESOLVED) → plus d\'alerte', (
    tester,
  ) async {
    for (final status in ['HANDED_OVER', 'IN_TRANSIT', 'ACCEPTED']) {
      final bid = _bid(
        status: status,
        voyageurConfirmed: true,
        cancellationNoShowStatus: 'RESOLVED',
      );
      await _pump(tester, bid);
      expect(find.textContaining('Absence signalée'), findsNothing);
      expect(find.textContaining('Absence contestée'), findsNothing);
      expect(TravelerHeroCard.senderNoShowOpen(bid), isFalse, reason: status);
      expect(TravelerHeroCard.isShown(bid), isFalse, reason: status);
    }
  });

  testWidgets('REJECTED → rien (SizedBox.shrink)', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'));
    expect(
      find.textContaining('vous demande de transporter son colis'),
      findsNothing,
    );
    expect(find.textContaining('Livraison'), findsNothing);
  });

  testWidgets('CANCELLED → rien (SizedBox.shrink)', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'));
    expect(
      find.textContaining('vous demande de transporter son colis'),
      findsNothing,
    );
    expect(find.textContaining('Colis'), findsNothing);
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

  // FLUTTER-4T : ces statuts n'avaient aucun hero côté voyageur.
  testWidgets('PAYMENT_ESCROWED → même explication que PENDING', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PAYMENT_ESCROWED'));
    expect(
      find.textContaining('vous demande de transporter son colis'),
      findsOneWidget,
    );
    expect(find.textContaining('puis acceptez ou refusez'), findsOneWidget);
  });

  testWidgets('AWAITING_PAYMENT → paiement attendu, rien à faire', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'AWAITING_PAYMENT'));
    expect(
      find.textContaining("Paiement de l'expéditeur en attente"),
      findsOneWidget,
    );
    expect(find.textContaining('Rien à faire'), findsOneWidget);
  });

  testWidgets('PENDING sans total → subtitle sans montant précis', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING', total: null));
    expect(
      find.textContaining('vous demande de transporter son colis'),
      findsOneWidget,
    );
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
    // Délai de contestation aligné sur le serveur (24 h, pas 48 h).
    expect(
      find.textContaining("L'expéditeur aura 24 h pour contester"),
      findsOneWidget,
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

  // Délai de contestation de l'absence à la livraison : quand le serveur le
  // sert, le héros « Une absence est signalée » le dit ; sinon texte d'avant.
  group('absence à la livraison : délai de contestation', () {
    BidModel deliveryBid({
      DateTime? deadline,
      String status = 'PENDING_CONFIRMATION',
      bool reportedByTraveler = false,
    }) => BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      weightKg: 5,
      status: 'IN_TRANSIT',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      deliveryNoShowStatus: status,
      deliveryNoShowReportedByTraveler: reportedByTraveler,
      deliveryNoShowContestationDeadline: deadline,
    );

    // Échéance en UTC : l'affichage doit se faire en heure locale.
    final deadlineUtc = DateTime.utc(2026, 10, 30, 14, 30);

    testWidgets('adversaire + échéance → date et heure locales exactes', (
      tester,
    ) async {
      await _pump(tester, deliveryBid(deadline: deadlineUtc));
      final local = deadlineUtc.toLocal();
      final date = DateFormat.MMMEd('fr').format(local);
      final time = DateFormat.jm('fr').format(local);
      expect(find.textContaining('Une absence est signalée'), findsOneWidget);
      expect(
        find.text(
          'Une absence à la livraison a été signalée sur cet envoi. Vous '
          "pouvez contester jusqu'au $date à $time si ce signalement est "
          'erroné.',
        ),
        findsOneWidget,
      );
      expect(find.text('Contester ce signalement'), findsOneWidget);
    });

    testWidgets('adversaire sans échéance → texte d\'avant', (tester) async {
      await _pump(tester, deliveryBid());
      expect(
        find.textContaining('Vous pouvez contester si ce signalement est'),
        findsOneWidget,
      );
      expect(find.textContaining('jusqu\'au'), findsNothing);
    });

    testWidgets('contestation déjà envoyée : pas de délai', (tester) async {
      await _pump(
        tester,
        deliveryBid(
          status: 'CONTESTED',
          deadline: DateTime.now().add(const Duration(hours: 20)),
        ),
      );
      expect(find.textContaining('Contestation envoyée'), findsOneWidget);
      expect(find.textContaining('jusqu\'au'), findsNothing);
    });

    testWidgets('auteur du signalement : texte inchangé', (tester) async {
      await _pump(
        tester,
        deliveryBid(
          reportedByTraveler: true,
          deadline: DateTime.now().add(const Duration(hours: 20)),
        ),
      );
      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(find.textContaining('jusqu\'au'), findsNothing);
    });

    testWidgets('en anglais : « contest until … at … »', (tester) async {
      final cancel = _MockCancelBloc();
      when(() => cancel.state).thenReturn(CancellationInitial());
      await initializeDateFormatting('en');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: AppL10n.en,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<CancellationBloc>.value(
              value: cancel,
              child: TravelerHeroCard(bid: deliveryBid(deadline: deadlineUtc)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final local = deadlineUtc.toLocal();
      final date = DateFormat.MMMEd('en').format(local);
      final time = DateFormat.jm('en').format(local);
      expect(
        find.text(
          'A delivery no-show has been reported on this shipment. You can '
          'contest it until $date at $time if this report is wrong.',
        ),
        findsOneWidget,
      );
      expect(find.text('Contest this report'), findsOneWidget);
    });
  });

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

  // ── Place du hero dans le corps : sous le billet ou dans « À traiter » ────
  group('hasAction / isShown', () {
    BidModel heroBid(
      String status, {
      DateTime? windowEnd,
      String? cancellationNoShowStatus,
      String? deliveryNoShowStatus,
      bool? reportedByTraveler,
    }) => BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      handoverDeadline: windowEnd,
      cancellationNoShowStatus: cancellationNoShowStatus,
      deliveryNoShowStatus: deliveryNoShowStatus,
      deliveryNoShowReportedByTraveler: reportedByTraveler,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

    final past = DateTime.now().subtract(const Duration(hours: 2));
    final future = DateTime.now().add(const Duration(days: 1));

    // Prédicats lus aussi par le footer (`TravelerStickyBar`).
    test('senderNoShowOpen : absence de l\'expéditeur en attente ou '
        'contestée', () {
      for (final status in ['PENDING_CONFIRMATION', 'CONTESTED']) {
        expect(
          TravelerHeroCard.senderNoShowOpen(
            heroBid('ACCEPTED', cancellationNoShowStatus: status),
          ),
          isTrue,
          reason: status,
        );
      }
      for (final status in [null, 'CONFIRMED', 'REJECTED', 'RESOLVED']) {
        expect(
          TravelerHeroCard.senderNoShowOpen(
            heroBid('ACCEPTED', cancellationNoShowStatus: status),
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('windowExpired : colis accepté, date limite passée', () {
      expect(
        TravelerHeroCard.windowExpired(heroBid('ACCEPTED', windowEnd: past)),
        isTrue,
      );
      expect(
        TravelerHeroCard.windowExpired(heroBid('ACCEPTED', windowEnd: future)),
        isFalse,
      );
      expect(TravelerHeroCard.windowExpired(heroBid('ACCEPTED')), isFalse);
      expect(
        TravelerHeroCard.windowExpired(heroBid('HANDED_OVER', windowEnd: past)),
        isFalse,
      );
    });

    // `isShown` et le contenu de priorité 3 lisent la même fonction : ce test
    // compare, pour chaque statut de l'inventaire et chaque signalement, à ce
    // que la carte rend réellement (hauteur nulle = SizedBox.shrink).
    const everyStatus = [
      'PENDING',
      'PAYMENT_ESCROWED',
      'AWAITING_PAYMENT',
      'ACCEPTED',
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
      'NEGOTIATING',
      'NEGOTIATION_CLOSED',
      'UNKNOWN_FUTURE_STATUS',
      '',
    ];
    final variants = <String, BidModel Function(String)>{
      'sans signalement': (status) => heroBid(status),
      'date limite dépassée': (status) => heroBid(status, windowEnd: past),
      'date limite à venir': (status) => heroBid(status, windowEnd: future),
      'absence de l\'expéditeur signalée': (status) =>
          heroBid(status, cancellationNoShowStatus: 'PENDING_CONFIRMATION'),
      'absence de l\'expéditeur contestée': (status) =>
          heroBid(status, cancellationNoShowStatus: 'CONTESTED'),
      'absence de l\'expéditeur confirmée (non lue)': (status) =>
          heroBid(status, cancellationNoShowStatus: 'CONFIRMED'),
      'absence à la livraison signalée par le voyageur': (status) => heroBid(
        status,
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        reportedByTraveler: true,
      ),
      'absence à la livraison signalée contre le voyageur': (status) => heroBid(
        status,
        deliveryNoShowStatus: 'PENDING_CONFIRMATION',
        reportedByTraveler: false,
      ),
      'absence à la livraison contestée': (status) => heroBid(
        status,
        deliveryNoShowStatus: 'CONTESTED',
        reportedByTraveler: false,
      ),
    };
    for (final MapEntry(key: variant, value: make) in variants.entries) {
      for (final status in everyStatus) {
        testWidgets('isShown = la carte rend quelque chose : $status, '
            '$variant', (tester) async {
          final bid = make(status);
          await _pump(tester, bid);
          final rendered = tester.getSize(find.byType(TravelerHeroCard));
          expect(
            TravelerHeroCard.isShown(bid),
            rendered.height > 0,
            reason: 'isShown et le rendu de la carte divergent',
          );
          // Une carte à bouton est forcément une carte affichée.
          if (TravelerHeroCard.hasAction(bid)) {
            expect(TravelerHeroCard.isShown(bid), isTrue);
          }
        });
      }
    }

    test('date limite de dépôt dépassée (ACCEPTED) : action', () {
      expect(
        TravelerHeroCard.hasAction(heroBid('ACCEPTED', windowEnd: past)),
        isTrue,
      );
      expect(
        TravelerHeroCard.hasAction(heroBid('ACCEPTED', windowEnd: future)),
        isFalse,
      );
      // Hors ACCEPTED, la date limite ne fait rien au hero.
      expect(
        TravelerHeroCard.hasAction(heroBid('HANDED_OVER', windowEnd: past)),
        isFalse,
      );
    });

    test('absence à la livraison signalée contre le voyageur : bouton '
        '« Contester ce signalement »', () {
      for (final reported in [false, null]) {
        expect(
          TravelerHeroCard.hasAction(
            heroBid(
              'ARRIVED',
              deliveryNoShowStatus: 'PENDING_CONFIRMATION',
              reportedByTraveler: reported,
            ),
          ),
          isTrue,
          reason: '$reported',
        );
        // Contestation envoyée : alerte rouge, mais plus de bouton.
        expect(
          TravelerHeroCard.hasAction(
            heroBid(
              'ARRIVED',
              deliveryNoShowStatus: 'CONTESTED',
              reportedByTraveler: reported,
            ),
          ),
          isFalse,
          reason: '$reported',
        );
      }
    });

    test('absence à la livraison signalée par le voyageur : information', () {
      for (final dns in ['PENDING_CONFIRMATION', 'CONTESTED']) {
        expect(
          TravelerHeroCard.hasAction(
            heroBid(
              'ARRIVED',
              deliveryNoShowStatus: dns,
              reportedByTraveler: true,
            ),
          ),
          isFalse,
          reason: dns,
        );
      }
    });

    test("absence de l'expéditeur déjà signalée : information, même date "
        'limite passée (priorité 1)', () {
      for (final ns in ['PENDING_CONFIRMATION', 'CONTESTED']) {
        expect(
          TravelerHeroCard.hasAction(
            heroBid('ACCEPTED', windowEnd: past, cancellationNoShowStatus: ns),
          ),
          isFalse,
          reason: ns,
        );
        // La priorité 1 passe aussi devant un signalement à la livraison.
        expect(
          TravelerHeroCard.hasAction(
            heroBid(
              'ARRIVED',
              cancellationNoShowStatus: ns,
              deliveryNoShowStatus: 'PENDING_CONFIRMATION',
              reportedByTraveler: false,
            ),
          ),
          isFalse,
          reason: ns,
        );
      }
    });

    test('statut seul : jamais une action', () {
      for (final status in [
        'PENDING',
        'PAYMENT_ESCROWED',
        'AWAITING_PAYMENT',
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
        'COMPLETED',
        'DELIVERED',
        'REJECTED',
        'CANCELLED',
        'NO_SHOW',
        'EXPIRED',
        'PARCEL_REFUSED',
      ]) {
        expect(
          TravelerHeroCard.hasAction(heroBid(status)),
          isFalse,
          reason: status,
        );
      }
    });

    test('isShown : la demande à décider et l\'attente du paiement, rien '
        'pour les étapes du transport ni les clos', () {
      for (final status in [
        'PENDING',
        'PAYMENT_ESCROWED',
        'AWAITING_PAYMENT',
      ]) {
        expect(
          TravelerHeroCard.isShown(heroBid(status)),
          isTrue,
          reason: status,
        );
      }
      for (final status in [
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
        'COMPLETED',
        'DELIVERED',
        'REJECTED',
        'CANCELLED',
        'NO_SHOW',
        'EXPIRED',
        'PARCEL_REFUSED',
        'NEGOTIATING',
        '',
      ]) {
        expect(
          TravelerHeroCard.isShown(heroBid(status)),
          isFalse,
          reason: status,
        );
      }
      // Un signalement en cours montre le hero quel que soit le statut.
      expect(
        TravelerHeroCard.isShown(
          heroBid('CANCELLED', cancellationNoShowStatus: 'CONTESTED'),
        ),
        isTrue,
      );
      expect(
        TravelerHeroCard.isShown(
          heroBid('NO_SHOW', deliveryNoShowStatus: 'PENDING_CONFIRMATION'),
        ),
        isTrue,
      );
    });

    testWidgets('isShown faux : la carte ne rend rien', (tester) async {
      for (final status in ['REJECTED', 'PARCEL_REFUSED', 'ARRIVED']) {
        await _pump(tester, heroBid(status));
        expect(find.byType(Text), findsNothing, reason: status);
      }
    });
  });
}
