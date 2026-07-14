import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

NegotiationThread _thread({
  String? travelerName = 'Fatou Ndiaye',
  double? travelerRating = 4.9,
  int? travelerTripsCount = 24,
}) =>
    NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: NegotiationThreadStatus.open,
      currentPriceEur: 50,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: const [],
      travelerName: travelerName,
      travelerRating: travelerRating,
      travelerTripsCount: travelerTripsCount,
    );

void main() {
  late _MockNegotiationBloc bloc;

  setUpAll(() {
    registerFallbackValue(const NegotiationFetchRequested('t-1'));
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    getIt.registerFactory<NegotiationBloc>(() => bloc);
  });

  tearDown(() {
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
  });

  Widget wrap({String viewerUserId = 'sender-1'}) => MaterialApp(
        theme: AppTheme.light,
        home: NegotiationThreadScreen(
          threadId: 't-1',
          viewerUserId: viewerUserId,
        ),
      );

  group('NegotiationThreadScreen', () {
    testWidgets('affiche CircularProgressIndicator en état Initial',
        (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche "Négociation" dans l\'AppBar en état Initial',
        (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Négociation'), findsOneWidget);
    });

    testWidgets('affiche le nom du voyageur dans l\'AppBar une fois chargé',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(NegotiationLoaded(_thread(travelerName: 'Fatou Ndiaye')));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Fatou Ndiaye'), findsOneWidget);
    });

    testWidgets('affiche la note et les trajets si disponibles', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationLoaded(
        _thread(
          travelerName: 'Fatou Ndiaye',
          travelerRating: 4.9,
          travelerTripsCount: 24,
        ),
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('★4.9'), findsOneWidget);
      expect(find.textContaining('24 trajets'), findsOneWidget);
    });

    testWidgets('affiche "Voyageur" si travelerName est null', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(_thread(travelerName: null)),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voyageur'), findsOneWidget);
    });

    testWidgets('n\'affiche pas la note si travelerRating est null',
        (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(
          _thread(travelerRating: null, travelerTripsCount: null),
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('affiche l\'avatar du voyageur une fois chargé', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationLoaded(_thread()),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets(
        'bouton retour sans pile de navigation (arrivée via go depuis un '
        'écran de succès) → repli vers /negotiations', (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationInitial());
      final router = GoRouter(
        initialLocation: '/negotiations/t-1',
        routes: [
          GoRoute(
            path: '/negotiations',
            builder: (_, __) =>
                const Scaffold(body: Text('LISTE_NEGOCIATIONS')),
          ),
          GoRoute(
            path: '/negotiations/:id',
            builder: (_, __) => const NegotiationThreadScreen(
              threadId: 't-1',
              viewerUserId: 'sender-1',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('LISTE_NEGOCIATIONS'), findsOneWidget);
    });
  });
}
