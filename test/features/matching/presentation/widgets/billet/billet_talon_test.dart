import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({
  required String status,
  String? trackingNumber,
  String? confirmationCode,
  String? contentCategory,
  double weightKg = 5,
  String? returnCode,
  DateTime? returnDeadline,
  DateTime? returnedAt,
  String? tripCancellationId,
  String? tripCancellationRematchStatus,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: weightKg,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  trackingNumber: trackingNumber,
  confirmationCode: confirmationCode,
  contentCategory: contentCategory,
  returnCode: returnCode,
  returnDeadline: returnDeadline,
  returnedAt: returnedAt,
  tripCancellationId: tripCancellationId,
  tripCancellationRematchStatus: tripCancellationRematchStatus,
);

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  // TrackingBloc/BidBloc sont consommés par TalonRetraitCodeView (statuts
  // HANDED_OVER/IN_TRANSIT avec code) ; fournis pour tous les cas, inoffensif
  // pour les autres.
  final t = _MockTrackingBloc();
  final b = _MockBidBloc();
  when(() => t.state).thenReturn(TrackingInitial());
  when(() => b.state).thenReturn(BidInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: t),
            BlocProvider<BidBloc>.value(value: b),
          ],
          child: BilletTalon(bid: bid, isSender: isSender),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // ── Sender dispatch ─────────────────────────────────────────────────────────

  testWidgets('sender + PENDING → placeholder, pas de bande de suivi', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });

  testWidgets('sender + HANDED_OVER sans confirmationCode → bouton QR seul', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'), true);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'), findsOneWidget);
    expect(find.textContaining('QR du colis'), findsOneWidget);
    // Pas de bouton code de retrait tant que le code n'existe pas.
    expect(find.text('Code de retrait'), findsNothing);
  });

  testWidgets(
    'sender + HANDED_OVER avec confirmationCode → boutons QR + Code de retrait',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'HANDED_OVER', confirmationCode: '4729'),
        true,
      );
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'), findsOneWidget);
      expect(find.text('Code de retrait'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'key-round'), findsOneWidget);
      // La carte du code n'est PAS inline : elle vit dans le bottom sheet.
      expect(find.text('CODE DE RETRAIT'), findsNothing);
    },
  );

  testWidgets('sender + IN_TRANSIT sans confirmationCode → bouton QR seul', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'), true);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'), findsOneWidget);
    expect(find.text('Code de retrait'), findsNothing);
  });

  testWidgets(
    'sender + IN_TRANSIT avec confirmationCode → boutons QR + Code de retrait',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '4729'),
        true,
      );
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'), findsOneWidget);
      expect(find.text('Code de retrait'), findsOneWidget);
    },
  );

  testWidgets(
    'sender + tap "Code de retrait" → bottom sheet avec la carte du code',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '4729'),
        true,
      );
      await tester.tap(find.text('Code de retrait'));
      await tester.pumpAndSettle();
      // La carte riche apparaît maintenant dans le sheet.
      expect(find.text('CODE DE RETRAIT'), findsOneWidget);
      expect(find.text('Copier le code'), findsOneWidget);
      // Ferme le sheet pour drainer les timers d'animation.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('sender + COMPLETED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'), true);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('sender + DELIVERED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'DELIVERED'), true);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('sender + REJECTED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'), true);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets('sender + CANCELLED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'), true);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets(
    'sender + CANCELLED + retour en attente → bouton "Code de retour"',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          returnCode: '123456',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
        true,
      );
      expect(find.text('Code de retour'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'key-round'), findsOneWidget);
    },
  );

  testWidgets('sender + CANCELLED + colis restitué → bloc "Colis restitué"', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        returnDeadline: DateTime(2026, 5, 3),
        returnedAt: DateTime(2026, 5, 2),
      ),
      true,
    );
    expect(find.text('Colis restitué'), findsOneWidget);
  });

  // ── CTA rematch (trajet annulé par le voyageur) ─────────────────────────────

  testWidgets(
    'sender + CANCELLED + tripCancellationId + rematchStatus SUGGESTED → CTA "Voir les trajets alternatifs"',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsOneWidget);
      // Le message terminal reste affiché en plus du CTA.
      expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
    },
  );

  testWidgets(
    'voyageur + CANCELLED + tripCancellationId + rematchStatus SUGGESTED → pas de CTA (non-sender)',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
        ),
        false,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + tripCancellationRematchStatus null → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'CANCELLED', tripCancellationId: 'cancel-001'),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + tripCancellationId null + rematchStatus SUGGESTED → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'CANCELLED', tripCancellationRematchStatus: 'SUGGESTED'),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + tripCancellationRematchStatus != SUGGESTED → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'EXHAUSTED',
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + flux retour en attente (isAwaitingReturn) → pas de CTA même avec SUGGESTED',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
          returnCode: '123456',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
      expect(find.text('Code de retour'), findsOneWidget);
    },
  );

  testWidgets(
    'sender + CANCELLED + colis restitué → pas de CTA même avec SUGGESTED',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
          returnDeadline: DateTime(2026, 5, 3),
          returnedAt: DateTime(2026, 5, 2),
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
      expect(find.text('Colis restitué'), findsOneWidget);
    },
  );

  // ── CTA rematch (bid refusé par le voyageur, trajet non annulé) ─────────────

  testWidgets(
    'sender + REJECTED + tripCancellationId + rematchStatus SUGGESTED → CTA "Voir les trajets alternatifs"',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'REJECTED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsOneWidget);
      // Le message terminal reste affiché en plus du CTA.
      expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
    },
  );

  testWidgets(
    'voyageur + REJECTED + tripCancellationId + rematchStatus SUGGESTED → pas de CTA (non-sender)',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'REJECTED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'SUGGESTED',
        ),
        false,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + REJECTED + tripCancellationId null + rematchStatus SUGGESTED → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'REJECTED', tripCancellationRematchStatus: 'SUGGESTED'),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + REJECTED + tripCancellationRematchStatus null → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'REJECTED', tripCancellationId: 'cancel-001'),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + REJECTED + tripCancellationRematchStatus != SUGGESTED → pas de CTA',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'REJECTED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'EXHAUSTED',
        ),
        true,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  // ── Traveler dispatch ───────────────────────────────────────────────────────

  testWidgets('voyageur + ACCEPTED → lien "Scanner les étapes" (Suivi)', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      false,
    );
    // Accès au scan depuis le détail → redirige vers les étapes du Suivi.
    expect(find.text('Lire les QR des étapes'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'scan-line'), findsOneWidget);
    // La bande de suivi reste.
    expect(find.text('N° DE SUIVI'), findsOneWidget);
  });

  testWidgets(
    'voyageur + PENDING → résumé de décision avec poids/type',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'PENDING',
          contentCategory: 'Vêtements',
          weightKg: 3.5,
        ),
        false,
      );
      expect(find.text('POIDS'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('3.5 kg'), findsOneWidget);
      expect(find.text('Vêtements'), findsOneWidget);
    },
  );

  testWidgets('voyageur + HANDED_OVER → lien "Scanner les étapes" (Suivi)', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'), false);
    // Redirige vers les étapes du Suivi (ScanHub).
    expect(find.text('Lire les QR des étapes'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'scan-line'), findsOneWidget);
  });

  testWidgets('voyageur + IN_TRANSIT → lien "Scanner les étapes" (Suivi)', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'), false);
    expect(find.text('Lire les QR des étapes'), findsOneWidget);
  });

  testWidgets('voyageur + COMPLETED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'), false);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('voyageur + REJECTED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'), false);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets('voyageur + CANCELLED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'), false);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets(
    'voyageur + CANCELLED + retour en attente → bouton "Confirmer le retour"',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
        false,
      );
      expect(find.text('Confirmer le retour'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'clipboard-check'), findsOneWidget);
    },
  );

  testWidgets('voyageur + CANCELLED + colis restitué → bloc "Colis restitué"', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        returnDeadline: DateTime(2026, 5, 3),
        returnedAt: DateTime(2026, 5, 2),
      ),
      false,
    );
    expect(find.text('Colis restitué'), findsOneWidget);
  });

  // ── Tracking strip ──────────────────────────────────────────────────────────

  testWidgets('trackingNumber présent → bande de suivi affichée', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      false,
    );
    expect(find.text('N° DE SUIVI'), findsOneWidget);
    expect(find.text('DON-1'), findsOneWidget);
  });

  testWidgets('sans trackingNumber → pas de bande de suivi', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });
}
