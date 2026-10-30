import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:dony/features/tracking/bloc/pickup_code_request_cubit.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid({
  required String status,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  String? trackingNumber,
  String? confirmationCode,
  String? contentCategory,
  double weightKg = 5,
  String? returnCode,
  DateTime? returnDeadline,
  DateTime? returnedAt,
  String? tripCancellationId,
  String? tripCancellationRematchStatus,
  String? rejectionReason,
  bool pickupCodeRenewalNeeded = false,
}) => BidModel(
  paymentMethod: paymentMethod,
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
  rejectionReason: rejectionReason,
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
);

/// Icône de l'ancien bouton « Lire les QR des étapes » du voyageur.
final _scanStepsIcon = find.byWidgetPredicate(
  (w) => w is DonyIcon && w.name == 'scan-line',
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

  testWidgets('sender + PENDING cash → placeholder, pas de bande de suivi', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'PENDING', paymentMethod: BidPaymentMethod.cash),
      true,
    );
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
  });

  testWidgets(
    'sender + PENDING carte (pas encore payé) → « En attente de votre '
    'paiement », jamais « en attente du voyageur » (FLUTTER-G7)',
    (tester) async {
      await _pump(tester, _bid(status: 'PENDING'), true);
      expect(find.text('En attente de votre paiement'), findsOneWidget);
      expect(find.textContaining('En attente de confirmation'), findsNothing);
    },
  );

  testWidgets(
    'sender + PAYMENT_ESCROWED carte (payé) → en attente du voyageur',
    (tester) async {
      await _pump(tester, _bid(status: 'PAYMENT_ESCROWED'), true);
      expect(find.textContaining('En attente de confirmation'), findsOneWidget);
      expect(find.text('En attente de votre paiement'), findsNothing);
    },
  );

  // Décision du propriétaire : plus de bouton « QR du colis » dans le talon de
  // l'expéditeur avant la remise, le footer porte « Afficher le QR de
  // remise ». Il ne reste que la bande du numéro de suivi, ou pas de talon.
  testWidgets(
    'sender + ACCEPTED avec numéro → bande du numéro de suivi seule',
    (tester) async {
      final bid = _bid(status: 'ACCEPTED', trackingNumber: 'DON-1');
      expect(BilletTalon.isShown(bid, isSender: true), isTrue);
      await _pump(tester, bid, true);
      expect(find.byType(TalonTrackingStrip), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsNothing,
      );
      expect(find.textContaining('QR du colis'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      // Sans zone d'action, la bande n'est pas décalée par un espace vide.
      expect(
        tester.getTopLeft(find.byType(TalonTrackingStrip)).dy -
            tester.getTopLeft(find.byType(BilletTalon)).dy,
        DonySpacing.base,
      );
    },
  );

  testWidgets('sender + ACCEPTED sans numéro → talon non affiché', (
    tester,
  ) async {
    final bid = _bid(status: 'ACCEPTED');
    expect(BilletTalon.isShown(bid, isSender: true), isFalse);
    await _pump(tester, bid, true);
    expect(tester.getSize(find.byType(BilletTalon)).height, 0);
  });

  testWidgets('sender + ACCEPTED en anglais : plus de « Parcel QR »', (
    tester,
  ) async {
    useEnglish();
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      true,
    );
    expect(find.textContaining('Parcel QR'), findsNothing);
    expect(find.text('TRACKING NUMBER'), findsOneWidget);
  });

  testWidgets(
    'sender + HANDED_OVER sans confirmationCode → QR + « Générer un nouveau code »',
    (tester) async {
      await _pump(tester, _bid(status: 'HANDED_OVER'), true);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsOneWidget,
      );
      expect(find.textContaining('QR du colis'), findsOneWidget);
      // Pas de bouton « Code de retrait » sans code : le talon propose d'en
      // générer un nouveau (code bloqué après trois essais, FLUTTER-G1).
      expect(find.text('Code de retrait'), findsNothing);
      expect(find.text('Code de retrait bloqué'), findsOneWidget);
      expect(find.text('Générer un nouveau code'), findsOneWidget);
    },
  );

  testWidgets(
    'sender + HANDED_OVER avec confirmationCode → boutons QR + Code de retrait',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'HANDED_OVER', confirmationCode: '4729'),
        true,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsOneWidget,
      );
      expect(find.text('Code de retrait'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'key-round'),
        findsOneWidget,
      );
      // La carte du code n'est PAS inline : elle vit dans le bottom sheet.
      expect(find.text('CODE DE RETRAIT'), findsNothing);
    },
  );

  testWidgets(
    'sender + IN_TRANSIT sans confirmationCode → QR + « Générer un nouveau code »',
    (tester) async {
      await _pump(tester, _bid(status: 'IN_TRANSIT'), true);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsOneWidget,
      );
      expect(find.text('Code de retrait'), findsNothing);
      expect(find.byKey(const Key('talon-generate-new-code')), findsOneWidget);
    },
  );

  testWidgets(
    'sender + IN_TRANSIT avec confirmationCode → boutons QR + Code de retrait',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '4729'),
        true,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsOneWidget,
      );
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

  testWidgets(
    'sender + ARRIVED avec confirmationCode → boutons QR + Code de retrait',
    (tester) async {
      await _pump(
        tester,
        _bid(status: 'ARRIVED', confirmationCode: '4729'),
        true,
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'qr-code'),
        findsOneWidget,
      );
      expect(find.text('Code de retrait'), findsOneWidget);
    },
  );

  testWidgets(
    'sender + ARRIVED sans confirmationCode → QR + « Générer un nouveau code »',
    (tester) async {
      await _pump(tester, _bid(status: 'ARRIVED'), true);
      expect(find.textContaining('QR du colis'), findsOneWidget);
      expect(find.text('Code de retrait'), findsNothing);
      expect(find.byKey(const Key('talon-generate-new-code')), findsOneWidget);
    },
  );

  // ── Code de retrait bloqué (FLUTTER-G1) ────────────────────────────────────

  group('code bloqué', () {
    late _MockTrackingBloc tracking;
    late _MockBidBloc bidBloc;

    setUpAll(() {
      registerFallbackValue(TrackingRefreshCodeRequested('x'));
      registerFallbackValue(BidDetailRequested('x'));
    });

    Future<void> pumpBlocked(
      WidgetTester tester, {
      TrackingState? initial,
      Stream<TrackingState>? stream,
      bool isSender = true,
      String? code,
    }) async {
      tracking = _MockTrackingBloc();
      bidBloc = _MockBidBloc();
      when(() => bidBloc.state).thenReturn(BidInitial());
      if (stream != null) {
        whenListen(
          tracking,
          stream,
          initialState: initial ?? TrackingInitial(),
        );
      } else {
        when(() => tracking.state).thenReturn(initial ?? TrackingInitial());
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<TrackingBloc>.value(value: tracking),
                BlocProvider<BidBloc>.value(value: bidBloc),
              ],
              child: BilletTalon(
                bid: _bid(status: 'IN_TRANSIT', confirmationCode: code),
                isSender: isSender,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('le bouton régénère le code, marqué « après blocage »', (
      tester,
    ) async {
      await pumpBlocked(tester);
      expect(find.textContaining("trop d'essais incorrects"), findsOneWidget);
      await tester.tap(find.byKey(const Key('talon-generate-new-code')));
      await tester.pump();

      final captured =
          verify(() => tracking.add(captureAny())).captured.single
              as TrackingRefreshCodeRequested;
      expect(captured.bidId, 'bid-1');
      expect(captured.afterBlock, isTrue);
    });

    testWidgets('nouveau code reçu → recharge le colis', (tester) async {
      await pumpBlocked(
        tester,
        stream: Stream.value(TrackingConfirmCodeLoaded('123456')),
      );
      await tester.pump();

      final captured =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidDetailRequested;
      expect(captured.bidId, 'bid-1');
    });

    testWidgets('pendant la régénération, le bouton ne relance rien', (
      tester,
    ) async {
      await pumpBlocked(tester, initial: TrackingRefreshCodeLoading());
      await tester.tap(
        find.byKey(const Key('talon-generate-new-code')),
        warnIfMissed: false,
      );
      await tester.pump();
      verifyNever(() => tracking.add(any()));
    });

    testWidgets('le voyageur ne voit jamais le bouton de régénération', (
      tester,
    ) async {
      await pumpBlocked(tester, isSender: false);
      expect(find.byKey(const Key('talon-generate-new-code')), findsNothing);
    });

    testWidgets('avec un code, pas de bloc « code bloqué »', (tester) async {
      await pumpBlocked(tester, code: '4729');
      expect(find.byKey(const Key('talon-blocked-code')), findsNothing);
      expect(find.text('Code de retrait'), findsOneWidget);
    });
  });

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

  testWidgets('sender + REJECTED avec motif → motif du voyageur affiché', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'REJECTED', rejectionReason: 'HANDOVER_NOT_POSSIBLE'),
      true,
    );
    expect(
      find.text('Motif du voyageur : Remise impossible (lieu ou horaire)'),
      findsOneWidget,
    );
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets('sender + REJECTED motif hors liste → pas de ligne motif', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'REJECTED', rejectionReason: 'TRAVELER_NO_RESPONSE'),
      true,
    );
    expect(find.byKey(const Key('billet-rejection-reason')), findsNothing);
  });

  testWidgets(
    'sender + CANCELLED avant paiement → motif « Vous avez annulé… »',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          rejectionReason: 'SENDER_CANCELLED_BEFORE_PAYMENT',
        ),
        true,
      );
      expect(
        find.text('Vous avez annulé cette demande avant le paiement.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'voyageur + CANCELLED avant paiement → motif « L’expéditeur a annulé… »',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          rejectionReason: 'SENDER_CANCELLED_BEFORE_PAYMENT',
        ),
        false,
      );
      expect(
        find.text("L'expéditeur a annulé cette demande avant le paiement."),
        findsOneWidget,
      );
    },
  );

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
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'key-round'),
        findsOneWidget,
      );
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

  // Décision du propriétaire : un colis annulé après remise reçoit aussi les
  // trajets proposés, pendant le retour comme après.
  testWidgets(
    'sender + CANCELLED + retour en attente + SUGGESTED → code de retour puis CTA',
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
      expect(find.text('Code de retour'), findsOneWidget);
      expect(find.text('Voir les trajets alternatifs'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Code de retour')).dy,
        lessThan(
          tester.getTopLeft(find.text('Voir les trajets alternatifs')).dy,
        ),
      );
    },
  );

  testWidgets(
    'voyageur + CANCELLED + retour en attente + SUGGESTED → pas de CTA',
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
        false,
      );
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + retour en attente sans suggestion → code de retour seul',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          tripCancellationId: 'cancel-001',
          tripCancellationRematchStatus: 'NONE',
          returnCode: '123456',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
        true,
      );
      expect(find.text('Code de retour'), findsOneWidget);
      expect(find.text('Voir les trajets alternatifs'), findsNothing);
    },
  );

  testWidgets(
    'sender + CANCELLED + colis restitué + SUGGESTED → "Colis restitué" et CTA',
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
      expect(find.text('Colis restitué'), findsOneWidget);
      expect(find.text('Voir les trajets alternatifs'), findsOneWidget);
    },
  );

  for (final returned in [false, true]) {
    testWidgets(
      'CTA d\'un colis remis puis annulé (restitué: $returned) → écran rematch en mode retour',
      (tester) async {
        final t = _MockTrackingBloc();
        final b = _MockBidBloc();
        when(() => t.state).thenReturn(TrackingInitial());
        when(() => b.state).thenReturn(BidInitial());
        final visited = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: MultiBlocProvider(
                  providers: [
                    BlocProvider<TrackingBloc>.value(value: t),
                    BlocProvider<BidBloc>.value(value: b),
                  ],
                  child: BilletTalon(
                    bid: _bid(
                      status: 'CANCELLED',
                      tripCancellationId: 'cancel-001',
                      tripCancellationRematchStatus: 'SUGGESTED',
                      returnCode: returned ? null : '123456',
                      returnDeadline: DateTime.now().add(
                        const Duration(days: 2),
                      ),
                      returnedAt: returned ? DateTime.now() : null,
                    ),
                    isSender: true,
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/cancellations/:id/rematch',
              builder: (_, state) {
                visited.add(state.uri.toString());
                return const Scaffold(body: Text('alternatives'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text('Voir les trajets alternatifs'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(visited, ['/cancellations/cancel-001/rematch?retour=1']);
      },
    );
  }

  testWidgets('CTA d\'une annulation avant remise → écran rematch classique', (
    tester,
  ) async {
    final t = _MockTrackingBloc();
    final b = _MockBidBloc();
    when(() => t.state).thenReturn(TrackingInitial());
    when(() => b.state).thenReturn(BidInitial());
    final visited = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<TrackingBloc>.value(value: t),
                BlocProvider<BidBloc>.value(value: b),
              ],
              child: BilletTalon(
                bid: _bid(
                  status: 'CANCELLED',
                  tripCancellationId: 'cancel-001',
                  tripCancellationRematchStatus: 'SUGGESTED',
                ),
                isSender: true,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/cancellations/:id/rematch',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('alternatives'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Voir les trajets alternatifs'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(visited, ['/cancellations/cancel-001/rematch']);
  });

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

  testWidgets(
    'sender + AWAITING_PAYMENT mobile money → invitation à payer, pas le '
    'placeholder « en attente du voyageur »',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'AWAITING_PAYMENT',
          paymentMethod: BidPaymentMethod.mobileMoney,
        ),
        true,
      );
      expect(find.textContaining('payez par mobile money'), findsOneWidget);
      expect(find.textContaining('En attente de confirmation'), findsNothing);
    },
  );

  testWidgets('sender + AWAITING_PAYMENT carte → placeholder inchangé', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'AWAITING_PAYMENT'), true);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.textContaining('payez par mobile money'), findsNothing);
  });

  // ── Traveler dispatch ───────────────────────────────────────────────────────

  // Plus de bouton « Lire les QR des étapes » côté voyageur (décision du
  // propriétaire) : le footer porte « Lire le QR du colis » puis « Valider la
  // remise ». Avant la remise, le talon n'a donc plus rien à montrer.
  testWidgets('voyageur + ACCEPTED → talon vide, non affiché', (tester) async {
    final bid = _bid(status: 'ACCEPTED', trackingNumber: 'DON-1');
    expect(BilletTalon.isShown(bid, isSender: false), isFalse);
    await _pump(tester, bid, false);
    expect(tester.getSize(find.byType(BilletTalon)).height, 0);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(_scanStepsIcon, findsNothing);
    // Le numéro de suivi n'est pas visible du voyageur avant la remise.
    expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
  });

  // Régression staging : un bid accepté en mobile money passe en
  // AWAITING_PAYMENT (30 min pour le séquestre côté expéditeur) — avant le
  // fix, le dispatch voyageur n'avait pas de cas dédié et retombait sur
  // SizedBox.shrink() (zone d'action vide, sans explication).
  testWidgets(
    'voyageur + AWAITING_PAYMENT → ligne d\'information, aucune action de '
    'scan',
    (tester) async {
      await _pump(tester, _bid(status: 'AWAITING_PAYMENT'), false);
      expect(
        find.textContaining("En attente du paiement de l'expéditeur"),
        findsOneWidget,
      );
      expect(_scanStepsIcon, findsNothing);
    },
  );

  testWidgets('voyageur + PENDING → résumé de décision avec poids/type', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'PENDING', contentCategory: 'Vêtements', weightKg: 3.5),
      false,
    );
    expect(find.text('POIDS'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('3.5 kg'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
  });

  // À partir de la remise, le talon ne garde que la bande du numéro de suivi.
  for (final status in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
    testWidgets('voyageur + $status → bande du numéro de suivi seule', (
      tester,
    ) async {
      final bid = _bid(status: status, trackingNumber: 'DON-1');
      expect(BilletTalon.isShown(bid, isSender: false), isTrue);
      await _pump(tester, bid, false);
      expect(find.byType(TalonTrackingStrip), findsOneWidget);
      expect(find.text('NUMÉRO DE SUIVI'), findsOneWidget);
      expect(_scanStepsIcon, findsNothing);
      // Sans zone d'action, la bande n'est pas décalée par un espace vide.
      expect(
        tester.getTopLeft(find.byType(TalonTrackingStrip)).dy -
            tester.getTopLeft(find.byType(BilletTalon)).dy,
        DonySpacing.base,
      );
    });

    testWidgets('voyageur + $status sans numéro servi → talon non affiché', (
      tester,
    ) async {
      final bid = _bid(status: status);
      expect(BilletTalon.isShown(bid, isSender: false), isFalse);
      await _pump(tester, bid, false);
      expect(tester.getSize(find.byType(BilletTalon)).height, 0);
    });
  }

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
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'clipboard-check',
        ),
        findsOneWidget,
      );
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
      true,
    );
    expect(find.text('NUMÉRO DE SUIVI'), findsOneWidget);
    expect(find.text('DON-1'), findsOneWidget);
  });

  testWidgets('sans trackingNumber → pas de bande de suivi', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
  });

  // Règle du propriétaire : le voyageur ne voit pas le numéro de suivi tant que
  // le colis n'a pas été remis. Le back le garantit ; l'app aussi.
  group('numéro de suivi voyageur : invisible avant la remise', () {
    const handedOver = [
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
    ];
    const beforeOrWithoutHandover = [
      'PENDING',
      'PAYMENT_ESCROWED',
      'AWAITING_PAYMENT',
      'ACCEPTED',
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ];

    for (final status in handedOver) {
      testWidgets('voyageur · $status + numéro → bande, copier, partager', (
        tester,
      ) async {
        await _pump(
          tester,
          _bid(status: status, trackingNumber: 'DON-1'),
          false,
        );
        expect(find.text('NUMÉRO DE SUIVI'), findsOneWidget);
        expect(find.text('DON-1'), findsOneWidget);
        expect(find.byKey(const Key('talon-copy-button')), findsOneWidget);
        expect(find.byKey(const Key('talon-share-button')), findsOneWidget);
        expect(find.byKey(const Key('talon-tracking-help')), findsOneWidget);
      });

      testWidgets('voyageur · $status sans numéro → pas de bande', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status), false);
        expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
        expect(find.byKey(const Key('talon-copy-button')), findsNothing);
      });
    }

    for (final status in beforeOrWithoutHandover) {
      testWidgets(
        'voyageur · $status + numéro servi quand même → ni bande, ni copier, '
        'ni partager',
        (tester) async {
          await _pump(
            tester,
            _bid(status: status, trackingNumber: 'DON-1'),
            false,
          );
          expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
          expect(find.text('DON-1'), findsNothing);
          expect(find.byKey(const Key('talon-copy-button')), findsNothing);
          expect(find.byKey(const Key('talon-share-button')), findsNothing);
          expect(find.byKey(const Key('talon-tracking-help')), findsNothing);
        },
      );

      testWidgets('voyageur · $status sans numéro → pas de bande', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status), false);
        expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
      });
    }

    // Expéditeur : inchangé, la bande suit le numéro quel que soit le statut.
    for (final status in [...handedOver, ...beforeOrWithoutHandover]) {
      testWidgets('expéditeur · $status + numéro → bande inchangée', (
        tester,
      ) async {
        await _pump(
          tester,
          _bid(status: status, trackingNumber: 'DON-1'),
          true,
        );
        expect(find.text('NUMÉRO DE SUIVI'), findsOneWidget);
        expect(find.text('DON-1'), findsOneWidget);
        expect(find.byKey(const Key('talon-copy-button')), findsOneWidget);
        expect(find.byKey(const Key('talon-share-button')), findsOneWidget);
      });

      testWidgets('expéditeur · $status sans numéro → pas de bande', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status), true);
        expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
      });
    }
  });

  group('traductions', () {
    testWidgets('en anglais : sender + COMPLETED → "Parcel delivered"', (
      tester,
    ) async {
      useEnglish();
      await _pump(tester, _bid(status: 'COMPLETED'), true);
      expect(find.text('Parcel delivered'), findsOneWidget);
      expect(find.text('Colis livré'), findsNothing);
    });

    testWidgets('en anglais : sender + REJECTED → "This request is closed."', (
      tester,
    ) async {
      useEnglish();
      await _pump(tester, _bid(status: 'REJECTED'), true);
      expect(find.text('This request is closed.'), findsOneWidget);
    });

    testWidgets(
      'en anglais : voyageur + PENDING → "WEIGHT" / "TYPE" (mini-stats)',
      (tester) async {
        useEnglish();
        await _pump(
          tester,
          _bid(
            status: 'PENDING',
            contentCategory: 'Vêtements & tissus',
            weightKg: 3.5,
          ),
          false,
        );
        expect(find.text('WEIGHT'), findsOneWidget);
        expect(find.text('TYPE'), findsOneWidget);
        expect(find.text('POIDS'), findsNothing);
        // Catégorie du catalogue traduite, jamais le français brut.
        expect(find.text('Clothing & fabrics'), findsOneWidget);
        expect(find.textContaining('Vêtements'), findsNothing);
      },
    );

    testWidgets(
      'en anglais : sender + CANCELLED + rematch → "View alternative trips"',
      (tester) async {
        useEnglish();
        await _pump(
          tester,
          _bid(
            status: 'CANCELLED',
            tripCancellationId: 'cancel-001',
            tripCancellationRematchStatus: 'SUGGESTED',
          ),
          true,
        );
        expect(find.text('View alternative trips'), findsOneWidget);
      },
    );

    testWidgets(
      'en anglais : voyageur + IN_TRANSIT → "TRACKING NUMBER", sans bouton '
      'des étapes',
      (tester) async {
        useEnglish();
        await _pump(
          tester,
          _bid(status: 'IN_TRANSIT', trackingNumber: 'DON-1'),
          false,
        );
        expect(find.text('TRACKING NUMBER'), findsOneWidget);
        expect(_scanStepsIcon, findsNothing);
      },
    );
  });

  group('EXPIRED à la date limite de dépôt (FLUTTER-GA)', () {
    testWidgets('expéditeur : annulée et remboursée intégralement', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(status: 'EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
        true,
      );
      expect(
        find.byKey(const Key('billet-handover-deadline-expired')),
        findsOneWidget,
      );
      expect(find.text('Date limite de dépôt passée'), findsOneWidget);
      expect(
        find.text(
          'La date limite de dépôt est passée : demande annulée. '
          'Tout paiement vous est remboursé intégralement.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('voyageur : demande annulée, sans mention de paiement', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(status: 'EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
        false,
      );
      expect(
        find.text('La date limite de dépôt est passée : demande annulée.'),
        findsOneWidget,
      );
    });

    testWidgets('EXPIRED au départ du voyageur : talon inchangé (vide)', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'EXPIRED'), true);
      expect(
        find.byKey(const Key('billet-handover-deadline-expired')),
        findsNothing,
      );
    });

    testWidgets('en anglais : sender + date limite passée', (tester) async {
      useEnglish();
      await _pump(
        tester,
        _bid(status: 'EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
        true,
      );
      expect(find.text('Drop-off deadline passed'), findsOneWidget);
    });
  });

  // NO_SHOW, PARCEL_REFUSED et EXPIRED (hors date limite de dépôt) : le talon
  // était vide, l'écran n'expliquait rien. Il dit maintenant que la demande
  // est terminée et pourquoi, avec le vocabulaire du tampon, pour le voyageur
  // comme pour l'expéditeur.
  group('demande terminée sans bloc dédié (voyageur et expéditeur)', () {
    const closed = 'Cette demande est terminée.';
    const closedEn = 'This request is closed.';
    // (statut, motif voyageur FR/EN, motif expéditeur FR/EN)
    final cases = <(String, String, String, String, String)>[
      (
        'NO_SHOW',
        'Absence constatée',
        'No-show recorded',
        'Absence constatée',
        'No-show recorded',
      ),
      (
        'PARCEL_REFUSED',
        'Colis refusé à la remise',
        'Parcel refused at handover',
        'Le voyageur a refusé le colis à la remise',
        'The traveler refused the parcel at handover',
      ),
      (
        'EXPIRED',
        'Demande expirée',
        'Request expired',
        'Demande expirée',
        'Request expired',
      ),
    ];

    for (final (status, fr, en, senderFr, senderEn) in cases) {
      testWidgets('voyageur · $status : motif + « demande terminée »', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status), false);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-closed-reason')))
              .data,
          fr,
        );
        expect(find.text(closed), findsOneWidget);
        // Rien d'autre dans la zone du talon : pas de bouton, pas de bande.
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('NUMÉRO DE SUIVI'), findsNothing);
      });

      testWidgets('voyageur · $status, en anglais', (tester) async {
        useEnglish();
        await _pump(tester, _bid(status: status), false);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-closed-reason')))
              .data,
          en,
        );
        expect(find.text(closedEn), findsOneWidget);
      });

      testWidgets('expéditeur · $status : motif + « demande terminée »', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status), true);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-closed-reason')))
              .data,
          senderFr,
        );
        expect(find.text(closed), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('expéditeur · $status, en anglais', (tester) async {
        useEnglish();
        await _pump(tester, _bid(status: status), true);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-closed-reason')))
              .data,
          senderEn,
        );
        expect(find.text(closedEn), findsOneWidget);
      });
    }

    testWidgets('expéditeur · EXPIRED à la date limite de dépôt : son bloc, '
        'sans le motif générique', (tester) async {
      await _pump(
        tester,
        _bid(status: 'EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
        true,
      );
      expect(
        find.byKey(const Key('billet-handover-deadline-expired')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('billet-closed-reason')), findsNothing);
    });

    testWidgets('voyageur · EXPIRED à la date limite de dépôt : son bloc, '
        'sans le motif générique', (tester) async {
      await _pump(
        tester,
        _bid(status: 'EXPIRED', rejectionReason: 'HANDOVER_DEADLINE_PASSED'),
        false,
      );
      expect(
        find.byKey(const Key('billet-handover-deadline-expired')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('billet-closed-reason')), findsNothing);
      expect(find.text('Demande expirée'), findsNothing);
    });
  });

  // FLUTTER-G2 (back #461) : code de retrait bloqué ou expiré.
  group('code à renouveler (pickupCodeRenewalNeeded)', () {
    late _MockTrackingRepository repository;

    setUp(() {
      repository = _MockTrackingRepository();
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<PickupCodeRequestCubit>(
        () => PickupCodeRequestCubit(repository, analytics),
      );
    });

    tearDown(() => getIt.unregister<PickupCodeRequestCubit>());

    for (final status in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('voyageur + $status : bouton « Demander un nouveau code »', (
        tester,
      ) async {
        await _pump(
          tester,
          _bid(status: status, pickupCodeRenewalNeeded: true),
          false,
        );
        expect(
          find.byKey(const Key('talon-code-renewal-request')),
          findsOneWidget,
        );
        expect(find.text('Demander un nouveau code'), findsOneWidget);
        // Le bloc reste à sa place, sans le bouton des étapes.
        expect(_scanStepsIcon, findsNothing);
      });
    }

    testWidgets('voyageur : le bloc précède la bande du numéro de suivi', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          trackingNumber: 'DON-1',
          pickupCodeRenewalNeeded: true,
        ),
        false,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('talon-code-renewal-request')))
            .dy,
        lessThan(tester.getTopLeft(find.byType(TalonTrackingStrip)).dy),
      );
    });

    testWidgets('voyageur : l\'appui envoie la demande', (tester) async {
      when(() => repository.requestNewCode('bid-1')).thenAnswer(
        (_) async => (requestedAt: null, nextRequestAllowedAt: null),
      );
      await _pump(
        tester,
        _bid(status: 'ARRIVED', pickupCodeRenewalNeeded: true),
        false,
      );
      await tester.ensureVisible(
        find.byKey(const Key('pickup-code-request-button')),
      );
      await tester.tap(find.byKey(const Key('pickup-code-request-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => repository.requestNewCode('bid-1')).called(1);
      expect(find.byKey(const Key('pickup-code-request-sent')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('voyageur sans drapeau (back antérieur) : talon inchangé', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'IN_TRANSIT'), false);
      expect(find.byKey(const Key('talon-code-renewal-request')), findsNothing);
    });

    testWidgets('expéditeur, code expiré encore présent : régénération', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          confirmationCode: '123456',
          pickupCodeRenewalNeeded: true,
        ),
        true,
      );
      expect(find.byKey(const Key('talon-blocked-code')), findsOneWidget);
      expect(find.byKey(const Key('talon-code-renewal-request')), findsNothing);
      // Le texte parle d'expiration, pas des essais faux du voyageur.
      expect(find.text('Code de retrait expiré'), findsOneWidget);
      expect(
        find.text('Le code de retrait a expiré. Générez-en un nouveau.'),
        findsOneWidget,
      );
      expect(find.text('Code de retrait bloqué'), findsNothing);
    });

    testWidgets('expéditeur, code effacé : « bloqué après trop d\'essais »', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(status: 'IN_TRANSIT', pickupCodeRenewalNeeded: true),
        true,
      );
      expect(find.text('Code de retrait bloqué'), findsOneWidget);
      expect(find.textContaining("trop d'essais"), findsOneWidget);
      expect(find.text('Code de retrait expiré'), findsNothing);
    });
  });
  // `isShown` suit ce que le talon rend vraiment : sans contenu (voyageur
  // avant la remise), ni bloc vide ni perforation dans le billet.
  group('isShown = le talon rend quelque chose', () {
    // Code à renouveler : le talon du voyageur monte le bloc de demande.
    setUp(() {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<PickupCodeRequestCubit>(
        () => PickupCodeRequestCubit(_MockTrackingRepository(), analytics),
      );
    });

    tearDown(() => getIt.unregister<PickupCodeRequestCubit>());

    const statuses = [
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
      'UNKNOWN',
    ];
    for (final status in statuses) {
      for (final tracking in [null, 'DON-1']) {
        for (final renewal in [false, true]) {
          testWidgets('voyageur, $status, numéro ${tracking ?? 'absent'}'
              '${renewal ? ', code à renouveler' : ''}', (tester) async {
            final bid = _bid(
              status: status,
              trackingNumber: tracking,
              pickupCodeRenewalNeeded: renewal,
            );
            await _pump(tester, bid, false);
            expect(
              BilletTalon.isShown(bid, isSender: false),
              tester.getSize(find.byType(BilletTalon)).height > 0,
            );
          });
        }
      }
    }

    for (final status in statuses) {
      for (final tracking in [null, 'DON-1']) {
        testWidgets('expéditeur, $status, numéro ${tracking ?? 'absent'}', (
          tester,
        ) async {
          final bid = _bid(status: status, trackingNumber: tracking);
          await _pump(tester, bid, true);
          // Seuls un colis accepté et un statut inconnu, sans numéro, n'ont
          // pas de talon côté expéditeur.
          expect(
            BilletTalon.isShown(bid, isSender: true),
            !((status == 'ACCEPTED' || status == 'UNKNOWN') &&
                tracking == null),
          );
          expect(
            BilletTalon.isShown(bid, isSender: true),
            tester.getSize(find.byType(BilletTalon)).height > 0,
          );
        });
      }
    }
  });

  // Statut que l'app ne connaît pas encore (back plus récent) : comme côté
  // voyageur, pas de talon vide ni de perforation ; le numéro de suivi, s'il
  // existe, reste montré seul.
  group('expéditeur, statut inconnu', () {
    testWidgets('sans numéro : talon absent', (tester) async {
      final bid = _bid(status: 'SOMETHING_NEW');
      await _pump(tester, bid, true);
      expect(BilletTalon.isShown(bid, isSender: true), isFalse);
      expect(tester.getSize(find.byType(BilletTalon)).height, 0);
    });

    testWidgets('avec numéro : seulement la bande de suivi', (tester) async {
      final bid = _bid(status: 'SOMETHING_NEW', trackingNumber: 'DON-9');
      await _pump(tester, bid, true);
      expect(BilletTalon.isShown(bid, isSender: true), isTrue);
      expect(find.byType(TalonTrackingStrip), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
