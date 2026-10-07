import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:dony/features/matching/presentation/screens/bid_negotiation_thread_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockRepo extends Mock implements BidNegotiationRepository {}

BidNegotiation _thread(String status) => BidNegotiation(
  bidId: 'bid1',
  announcementId: 'ann1',
  status: status,
  round: 2,
  maxRounds: 5,
  proposedGrossEur: 40,
  description: 'Vêtements',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
);

/// Archiver / supprimer un fil de trajet terminé depuis son écran de détail
/// (FLUTTER-EJ, yadony-back #423).
void main() {
  late _MockNegotiationBloc bloc;
  late _MockPaymentBloc paymentBloc;
  late _MockRepo repo;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
  });

  setUp(() {
    DonySnackbar.clearDedup();
    bloc = _MockNegotiationBloc();
    paymentBloc = _MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => paymentBloc.close()).thenAnswer((_) async {});
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    getIt.registerFactory<PaymentBloc>(() => paymentBloc);
    repo = _MockRepo();
    when(() => repo.myNegotiations()).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await getIt.unregister<PaymentBloc>();
    if (getIt.isRegistered<BidNegotiationListBloc>()) {
      await getIt.unregister<BidNegotiationListBloc>();
    }
  });

  Future<void> pump(
    WidgetTester tester,
    String status, {
    bool archived = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final listBloc = BidNegotiationListBloc(repo);
    addTearDown(listBloc.close);
    getIt.registerSingleton<BidNegotiationListBloc>(listBloc);
    whenListen(
      bloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: BidNegotiationLoaded(_thread(status)),
    );
    await tester.pumpWidget(
      BlocProvider<BidNegotiationBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: Builder(
                    builder: (inner) => TextButton(
                      onPressed: () => inner.push('/thread'),
                      child: const Text('ListeStub'),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/thread',
                builder: (_, _) => BidNegotiationThreadScreen(
                  bidId: 'bid1',
                  archived: archived,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ListeStub'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nego-archive-menu')));
    await tester.pumpAndSettle();
  }

  for (final open in kBidNegotiationOpenStatuses) {
    testWidgets('$open : aucune action d\'archivage', (tester) async {
      await pump(tester, open);
      expect(find.byKey(const Key('nego-archive-menu')), findsNothing);
    });
  }

  testWidgets('fil terminé : Archiver, message, retour à la liste', (
    tester,
  ) async {
    when(() => repo.archive('bid1')).thenAnswer((_) async {});
    await pump(tester, 'REJECTED');

    await openMenu(tester);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    verify(() => repo.archive('bid1')).called(1);
    expect(find.text('Discussion archivée'), findsOneWidget);
    expect(find.text('ListeStub'), findsOneWidget);
  });

  testWidgets('ouvert depuis « Archivées » : Désarchiver', (tester) async {
    when(() => repo.unarchive('bid1')).thenAnswer((_) async {});
    await pump(tester, 'EXPIRED', archived: true);

    await openMenu(tester);
    await tester.tap(find.text('Désarchiver'));
    await tester.pumpAndSettle();

    verify(() => repo.unarchive('bid1')).called(1);
  });

  testWidgets('Supprimer : confirmation puis DELETE', (tester) async {
    when(() => repo.delete('bid1')).thenAnswer((_) async {});
    await pump(tester, 'CANCELLED');

    await openMenu(tester);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Cette discussion disparaîtra de votre liste. '
        "L'autre participant la conserve.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('nego-delete-confirm')));
    await tester.pumpAndSettle();

    verify(() => repo.delete('bid1')).called(1);
    expect(find.text('ListeStub'), findsOneWidget);
  });

  testWidgets('backend ancien (404 sans code) : message, on reste', (
    tester,
  ) async {
    when(() => repo.archive('bid1')).thenThrow(const NotFoundException());
    await pump(tester, 'REJECTED');

    await openMenu(tester);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Cette action n'est pas encore disponible. Réessayez plus tard.",
      ),
      findsOneWidget,
    );
    expect(find.text('ListeStub'), findsNothing);
  });
}
