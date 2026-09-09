import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Tests dédiés à la navigation « Payer par mobile money » → écran d'attente
/// → callback [SenderStickyBar.onPaymentReturned] au retour.
///
/// Fichier séparé de `sender_sticky_bar_test.dart` : ces cas ont besoin d'un
/// vrai [GoRouter] (via `MaterialApp.router`) pour exercer `context.push`,
/// alors que le harnais existant (`_host()`) utilise un simple [MaterialApp]
/// qui suffit aux autres cas (aucune navigation testée côté bloc stripe).
class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({String status = 'AWAITING_PAYMENT'}) {
  return BidModel(
    id: 'bid-mm-1',
    announcementId: 'ann-1',
    senderId: 'sender-1',
    status: status,
    paymentMethod: BidPaymentMethod.mobileMoney,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Widget _wrap(
  _MockBidBloc bloc,
  BidModel bid, {
  VoidCallback? onPaymentReturned,
  bool isLoading = false,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<BidBloc>.value(
            value: bloc,
            child: Scaffold(
              bottomNavigationBar: SenderStickyBar(
                bid: bid,
                isLoading: isLoading,
                onPaymentReturned: onPaymentReturned,
              ),
            ),
          ),
        ),
        // Remplace le vrai MobileMoneyAwaitingScreen (qui a ses propres
        // BLoC/DI, hors périmètre de ce test) : seul compte ici le
        // round-trip push → pop(bool).
        GoRoute(
          path: '/bids/:bidId/mobile-money/awaiting',
          builder: (context, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => context.pop(true),
              child: const Text('fake-awaiting-screen'),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  late _MockBidBloc bloc;

  setUp(() {
    bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
  });

  tearDown(() {
    bloc.close();
  });

  testWidgets(
    'tap "Payer par mobile money" navigue vers /bids/{id}/mobile-money/awaiting',
    (tester) async {
      await tester.pumpWidget(_wrap(bloc, _bid()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payer par mobile money'));
      await tester.pumpAndSettle();

      expect(find.text('fake-awaiting-screen'), findsOneWidget);
    },
  );

  testWidgets(
    "retour de l'écran d'attente (pop true) appelle onPaymentReturned",
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _wrap(bloc, _bid(), onPaymentReturned: () => callCount++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payer par mobile money'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('fake-awaiting-screen'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    },
  );

  testWidgets(
    "retour de l'écran d'attente sans onPaymentReturned (null) ne casse rien",
    (tester) async {
      // onPaymentReturned volontairement omis (null par défaut).
      await tester.pumpWidget(_wrap(bloc, _bid()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payer par mobile money'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('fake-awaiting-screen'));
      await tester.pumpAndSettle();

      // De retour sur la barre d'origine, sans exception levée.
      expect(find.text('Payer par mobile money'), findsOneWidget);
    },
  );

  testWidgets('isLoading=true → "Payer par mobile money" en chargement, '
      '"Annuler la demande" désactivé', (tester) async {
    await tester.pumpWidget(_wrap(bloc, _bid(), isLoading: true));
    // Pas de pumpAndSettle : le CircularProgressIndicator du bouton en
    // chargement anime en boucle et ferait échouer pumpAndSettle (timeout).
    await tester.pump();

    expect(find.text('Payer par mobile money'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final cancelBtn = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Annuler la demande'),
    );
    expect(cancelBtn.onPressed, isNull);
  });
}
