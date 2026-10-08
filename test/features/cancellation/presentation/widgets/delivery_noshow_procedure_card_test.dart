import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_procedure_card.dart';
import 'package:dony/features/cancellation/presentation/widgets/retry_appointment_sheet.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockProcedureCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

class _FakeEvent extends Fake implements CancellationEvent {}

final _now = DateTime(2026, 10, 8, 12);

BidModel _bid({
  String status = 'ARRIVED',
  bool? reportedByTraveler,
  String? deliveryStatus,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  departureAt: DateTime.now().subtract(const Duration(days: 1)),
  deliveryNoShowReportedByTraveler: reportedByTraveler,
  deliveryNoShowStatus: deliveryStatus,
);

DeliveryNoShowProcedureModel _traveler({
  bool canReport = false,
  bool waitElapsed = false,
  String? proof,
}) => DeliveryNoShowProcedureModel(
  bidId: 'b1',
  role: 'TRAVELER',
  bidStatus: 'ARRIVED',
  reportAvailableAt: _now.add(const Duration(minutes: 45)),
  waitElapsed: waitElapsed,
  contactProof: proof,
  canReport: canReport,
);

final _senderHolding = DeliveryNoShowProcedureModel(
  bidId: 'b1',
  role: 'SENDER',
  bidStatus: 'ARRIVED',
  reported: true,
  noShowStatus: 'CONFIRMED',
  holdUntil: _now.add(const Duration(days: 5)),
  retryAppointmentAt: _now.add(const Duration(days: 1)),
  canSetRetryAppointment: true,
);

void main() {
  late _MockCancellationBloc bloc;
  late _MockProcedureCubit cubit;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    bloc = _MockCancellationBloc();
    cubit = _MockProcedureCubit();
    whenListen(
      bloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
    when(() => cubit.load(any())).thenAnswer((_) async {});
    when(() => cubit.refresh()).thenAnswer((_) async {});
    when(() => cubit.close()).thenAnswer((_) async {});
    if (getIt.isRegistered<DeliveryNoShowProcedureCubit>()) {
      getIt.unregister<DeliveryNoShowProcedureCubit>();
    }
    getIt.registerFactory<DeliveryNoShowProcedureCubit>(() => cubit);
  });

  tearDown(() => getIt.unregister<DeliveryNoShowProcedureCubit>());

  Future<void> pump(
    WidgetTester tester,
    BidModel bid, {
    required bool isSender,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<CancellationBloc>.value(
          value: bloc,
          child: SingleChildScrollView(
            child: DeliveryNoShowProcedureCard(bid: bid, isSender: isSender),
          ),
        ),
      ),
    ),
  );

  void stub(DeliveryNoShowProcedureState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      const Stream<DeliveryNoShowProcedureState>.empty(),
      initialState: state,
    );
  }

  group('visibilité', () {
    test(
      'voyageur : à l arrivée ou après son signalement ; expéditeur : après le signalement',
      () {
        expect(
          DeliveryNoShowProcedureCard.shouldShow(_bid(), isSender: false),
          isTrue,
        );
        expect(
          DeliveryNoShowProcedureCard.shouldShow(
            _bid(status: 'IN_TRANSIT'),
            isSender: false,
          ),
          isFalse,
        );
        expect(
          DeliveryNoShowProcedureCard.shouldShow(_bid(), isSender: true),
          isFalse,
        );
        expect(
          DeliveryNoShowProcedureCard.shouldShow(
            _bid(reportedByTraveler: true),
            isSender: true,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'voyageur avant l arrivée : ancien signalement, aucune lecture',
      (tester) async {
        await pump(tester, _bid(status: 'IN_TRANSIT'), isSender: false);
        expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
        verifyNever(() => cubit.load(any()));
      },
    );

    testWidgets('back antérieur : le voyageur garde l ancien parcours', (
      tester,
    ) async {
      stub(const DeliveryNoShowProcedureUnavailable());
      await pump(tester, _bid(), isSender: false);
      expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
    });

    testWidgets('erreur : bandeau et réessai', (tester) async {
      stub(const DeliveryNoShowProcedureError(NetworkException('x')));
      await pump(tester, _bid(), isSender: false);
      expect(
        find.text("Impossible de charger le suivi de l'absence"),
        findsOneWidget,
      );
      await tester.tap(find.text('Réessayer'));
      verify(() => cubit.refresh()).called(1);
    });
  });

  group('voyageur', () {
    testWidgets(
      'attente en cours : compteur, contact à faire, bouton désactivé',
      (tester) async {
        stub(DeliveryNoShowProcedureLoaded(_traveler(), now: _now));
        await pump(tester, _bid(), isSender: false);

        expect(find.text('Destinataire absent ?'), findsOneWidget);
        expect(find.textContaining('Attendez encore 45 min'), findsOneWidget);
        expect(find.textContaining('Appelez ou écrivez'), findsOneWidget);
        final button = tester.widget<DonyButton>(
          find.byKey(const Key('dnp-report')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('conditions réunies : la case est exigée avant d envoyer', (
      tester,
    ) async {
      stub(
        DeliveryNoShowProcedureLoaded(
          _traveler(canReport: true, waitElapsed: true, proof: 'CALL'),
          now: _now,
        ),
      );
      await pump(tester, _bid(), isSender: false);
      expect(find.text('Tentative de contact enregistrée'), findsOneWidget);
      expect(find.text("Délai d'attente écoulé"), findsOneWidget);

      await tester.tap(find.byKey(const Key('dnp-report')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vous gardez le colis 7 jours'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dnp-report-confirm')));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any()));

      await tester.tap(find.byKey(const Key('dnp-confirm-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dnp-report-confirm')));
      await tester.pumpAndSettle();

      final captured =
          verify(() => bloc.add(captureAny())).captured.single
              as DeliveryNoShowReportRequested;
      expect(captured.contactConfirmed, isTrue);
      expect(captured.bidId, 'b1');
    });

    testWidgets('après le signalement : garde et nouveau rendez-vous', (
      tester,
    ) async {
      stub(
        DeliveryNoShowProcedureLoaded(
          DeliveryNoShowProcedureModel(
            bidId: 'b1',
            role: 'TRAVELER',
            bidStatus: 'ARRIVED',
            reported: true,
            holdUntil: _now.add(const Duration(days: 7)),
            retryAppointmentAt: _now.add(const Duration(days: 1)),
            retryAppointmentNote: 'Devant la gare',
          ),
          now: _now,
        ),
      );
      await pump(tester, _bid(reportedByTraveler: true), isSender: false);
      expect(find.text('Colis en garde'), findsOneWidget);
      expect(find.textContaining('Gardez le colis jusqu'), findsOneWidget);
      expect(find.textContaining('Nouveau rendez-vous'), findsOneWidget);
      expect(find.textContaining('Devant la gare'), findsOneWidget);
    });

    testWidgets('colis non réclamé : paiement libéré', (tester) async {
      stub(
        DeliveryNoShowProcedureLoaded(
          DeliveryNoShowProcedureModel(
            bidId: 'b1',
            role: 'TRAVELER',
            bidStatus: 'ARRIVED',
            reported: true,
            holdUntil: _now,
            unclaimedAt: _now,
          ),
          now: _now,
        ),
      );
      await pump(tester, _bid(reportedByTraveler: true), isSender: false);
      expect(find.text('Colis non réclamé'), findsOneWidget);
      expect(find.textContaining('votre paiement est libéré'), findsOneWidget);
    });
  });

  group('expéditeur', () {
    testWidgets(
      'garde en cours : choix nouveau RDV ou changement de destinataire',
      (tester) async {
        stub(DeliveryNoShowProcedureLoaded(_senderHolding, now: _now));
        await pump(tester, _bid(reportedByTraveler: true), isSender: true);

        expect(find.text('Votre destinataire était absent'), findsOneWidget);
        expect(find.byKey(const Key('dnp-sender-appointment')), findsOneWidget);
        expect(find.byKey(const Key('dnp-set-appointment')), findsOneWidget);
        expect(find.byKey(const Key('dnp-change-recipient')), findsOneWidget);

        await tester.tap(find.byKey(const Key('dnp-set-appointment')));
        await tester.pumpAndSettle();
        expect(find.byType(RetryAppointmentSheet), findsOneWidget);
      },
    );

    testWidgets(
      'colis non réclamé : mandataire via le changement de destinataire',
      (tester) async {
        stub(
          DeliveryNoShowProcedureLoaded(
            DeliveryNoShowProcedureModel(
              bidId: 'b1',
              role: 'SENDER',
              bidStatus: 'ARRIVED',
              reported: true,
              holdUntil: _now,
              unclaimedAt: _now,
            ),
            now: _now,
          ),
        );
        await pump(tester, _bid(reportedByTraveler: true), isSender: true);
        expect(find.textContaining('le voyageur a été payé'), findsOneWidget);
        expect(
          find.byKey(const Key('dnp-unclaimed-change-recipient')),
          findsOneWidget,
        );
      },
    );

    testWidgets('signalement relu après un nouveau signalement', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream<CancellationState>.fromIterable([DeliveryNoShowReported()]),
        initialState: CancellationInitial(),
      );
      stub(DeliveryNoShowProcedureLoaded(_senderHolding, now: _now));
      await pump(tester, _bid(reportedByTraveler: true), isSender: true);
      await tester.pump();
      verify(() => cubit.refresh()).called(1);
    });
  });
}
