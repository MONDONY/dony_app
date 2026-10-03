import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

BidModel _makeBid(BidPaymentMethod method) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  weightKg: 5,
  status: 'PAYMENT_ESCROWED',
  paymentMethod: method,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _wrap(BidModel bid, MockBidBloc bidBloc, MockBidAcceptanceBloc accBloc) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<BidAcceptanceBloc>.value(value: accBloc),
            ],
            // Mirror la vraie hiérarchie : la barre est le bottomNavigationBar
            // d'un Scaffold plein écran atteint via GoRouter.
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: TravelerPendingBar(
                bid: bid,
                isLoading: false,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(BidRejectRequested('fallback'));
    registerFallbackValue(BidAcceptRequested('fallback'));
    registerFallbackValue(BidAcceptMobileMoneyRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc accBloc;

  setUp(() {
    bidBloc = MockBidBloc();
    accBloc = MockBidAcceptanceBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => accBloc.state).thenReturn(acs.BidAcceptanceInitial());
  });

  tearDown(() {
    bidBloc.close();
    accBloc.close();
  });

  group('TravelerPendingBar — Refuser (bid carte / PAYMENT_ESCROWED)', () {
    testWidgets('tap Refuser ouvre la feuille du motif', (tester) async {
      await tester.pumpWidget(
        _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(find.text('Refuser la demande'), findsOneWidget);
      expect(find.text('Confirmer le refus'), findsOneWidget);
    });

    testWidgets(
      'motif choisi puis Confirmer le refus dispatch BidRejectRequested et ferme la feuille',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Contenu du colis non accepté'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmer le refus'));
        await tester.pumpAndSettle();

        // La feuille doit être fermée…
        expect(find.text('Refuser la demande'), findsNothing);
        // …et l'événement de refus dispatché avec le code du motif.
        verify(
          () => bidBloc.add(
            any(
              that: isA<BidRejectRequested>().having(
                (e) => e.reason,
                'reason',
                'CONTENT_NOT_ACCEPTED',
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('Accepter (carte) dispatch BidAcceptRequested sur BidBloc', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
      await tester.pump();

      verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);
    });

    testWidgets('anglais — boutons Decline/Accept traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(_makeBid(BidPaymentMethod.stripe), bidBloc, accBloc),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Decline'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.pumpAndSettle();

      expect(find.text('Decline the request'), findsOneWidget);
      expect(find.text('Confirm the decline'), findsOneWidget);
    });
  });

  group('TravelerPendingBar — Accepter selon le mode de paiement', () {
    testWidgets(
      'Accepter (mobile money) dispatch BidAcceptMobileMoneyRequested sur '
      'BidBloc, jamais sur BidAcceptanceBloc',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeBid(BidPaymentMethod.mobileMoney), bidBloc, accBloc),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
        await tester.pump();

        verify(
          () => bidBloc.add(any(that: isA<BidAcceptMobileMoneyRequested>())),
        ).called(1);
        verifyNever(() => accBloc.add(any()));
      },
    );

    testWidgets(
      'Accepter (espèces) dispatch BidAcceptRequested sur BidAcceptanceBloc, '
      'jamais sur BidBloc',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_makeBid(BidPaymentMethod.cash), bidBloc, accBloc),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
        await tester.pump();

        verify(
          () => accBloc.add(any(that: isA<ace.BidAcceptRequested>())),
        ).called(1);
        verifyNever(() => bidBloc.add(any()));
      },
    );
  });

  group('showSenderOptionsSheet — Signaler ce trajet', () {
    Widget wrapSender(BidModel bid) => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSenderOptionsSheet(context, bid),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/settings/report-incident',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return Scaffold(
                body: Text(
                  'Reported: ${extra?['targetType']}/${extra?['targetId']}',
                ),
              );
            },
          ),
        ],
      ),
    );

    testWidgets(
      'tap Signaler ce trajet → navigue vers report-incident avec la cible BID',
      (tester) async {
        final bid = _makeBid(BidPaymentMethod.stripe);
        await tester.pumpWidget(wrapSender(bid));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Signaler ce trajet'));
        await tester.pumpAndSettle();

        expect(
          find.text('Reported: IncidentTargetType.bid/${bid.id}'),
          findsOneWidget,
        );
      },
    );
  });

  group('showSenderOptionsSheet — Modifier le destinataire', () {
    Widget wrapSender(BidModel bid) => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSenderOptionsSheet(context, bid),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    BidModel withStatus(String status) => BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: status,
      recipientName: 'Fatou Sow',
      recipientPhone: '+221771234567',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status : entrée présente', (tester) async {
        await tester.pumpWidget(wrapSender(withStatus(status)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Modifier le destinataire'), findsOneWidget);
        expect(find.text("Nom ou numéro, jusqu'à la remise"), findsOneWidget);
      });
    }

    for (final status in ['PENDING', 'COMPLETED', 'CANCELLED']) {
      testWidgets('$status : entrée absente', (tester) async {
        await tester.pumpWidget(wrapSender(withStatus(status)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Modifier le destinataire'), findsNothing);
      });
    }

    testWidgets('tap : ferme le menu et ouvre la feuille de modification', (
      tester,
    ) async {
      final analytics = _MockAnalyticsService();
      getIt.registerFactory<RecipientChangeCubit>(
        () => RecipientChangeCubit(_MockBidRepository(), analytics),
      );
      addTearDown(() => getIt.unregister<RecipientChangeCubit>());

      await tester.pumpWidget(wrapSender(withStatus('IN_TRANSIT')));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier le destinataire'));
      await tester.pumpAndSettle();

      // Le menu est fermé, la feuille est ouverte et pré-remplie.
      expect(find.text("Nom ou numéro, jusqu'à la remise"), findsNothing);
      expect(find.text('Modifier le destinataire'), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });
}
