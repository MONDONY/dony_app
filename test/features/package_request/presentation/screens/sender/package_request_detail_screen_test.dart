import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_skeleton.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestRepository extends Mock implements PackageRequestRepository {}
class _MockAnnouncementRepository extends Mock implements AnnouncementRepository {}
class _MockBidRepository extends Mock implements BidRepository {}
class _MockAnalyticsService extends Mock implements AnalyticsService {}
class _MockRatingBloc extends MockBloc<RatingEvent, RatingState> implements RatingBloc {}

PackageRequest _fakeRequest({
  PackageRequestStatus status = PackageRequestStatus.open,
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Divo',
  arrivalCity: 'Annemasse',
  desiredDate: DateTime(2026, 9, 27),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: status,
  createdAt: DateTime.utc(2026, 9, 17, 6, 25),
);

AnnouncementModel _trip(String id) => AnnouncementModel(
  id: id,
  travelerId: 'trav-$id',
  departureCity: 'Divo',
  arrivalCity: 'Annemasse',
  departureDate: DateTime(2026, 9, 26),
  availableKg: 8,
  totalKg: 10,
  pricePerKg: 7,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
);

Widget _buildApp({required String requestId}) {
  final router = GoRouter(
    initialLocation: '/package-requests/$requestId',
    routes: [
      GoRoute(
        path: '/package-requests/:id',
        builder: (ctx, state) => PackageRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/negotiations/:id',
        builder: (_, state) => Scaffold(body: Text('THREAD ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(body: Text('BID ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/traveler/:id',
        builder: (_, state) => Scaffold(body: Text('TRIP ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('clearDateForDuplicate', () {
    final now = DateTime(2026, 9, 17);

    test('republier vide toujours la date, même future', () {
      expect(clearDateForDuplicate('republish', DateTime(2026, 12, 25), now: now), isTrue);
    });

    test('dupliquer une date déjà passée vide aussi la date', () {
      expect(clearDateForDuplicate('duplicate', DateTime(2026, 9, 10), now: now), isTrue);
    });

    test('dupliquer avec la date du jour même ne la vide pas', () {
      expect(clearDateForDuplicate('duplicate', DateTime(2026, 9, 17), now: now), isFalse);
    });

    test('dupliquer une date future garde la date', () {
      expect(clearDateForDuplicate('duplicate', DateTime(2026, 12, 25), now: now), isFalse);
    });

    test('publier une demande similaire suit la même règle de date passée', () {
      expect(clearDateForDuplicate('similar', DateTime(2026, 9), now: now), isTrue);
      expect(clearDateForDuplicate('similar', DateTime(2026, 12), now: now), isFalse);
    });
  });

  late _MockPackageRequestRepository repo;
  late _MockAnnouncementRepository announcements;
  late _MockBidRepository bids;
  late _MockAnalyticsService analytics;
  late _MockRatingBloc ratingBloc;

  void stubSearch(List<AnnouncementModel> trips) => when(
    () => announcements.searchAnnouncements(
      departureCity: any(named: 'departureCity'),
      arrivalCity: any(named: 'arrivalCity'),
      departureDateFrom: any(named: 'departureDateFrom'),
      departureDateTo: any(named: 'departureDateTo'),
      minAvailableKg: any(named: 'minAvailableKg'),
    ),
  ).thenAnswer((_) async => trips);

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockPackageRequestRepository();
    announcements = _MockAnnouncementRepository();
    bids = _MockBidRepository();
    analytics = _MockAnalyticsService();
    ratingBloc = _MockRatingBloc();

    when(() => analytics.logEvent(any(), properties: any(named: 'properties'))).thenAnswer((_) async {});
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    when(() => ratingBloc.stream).thenAnswer((_) => const Stream<RatingState>.empty());
    stubSearch(const []);

    if (getIt.isRegistered<PackageRequestDetailCubit>()) {
      getIt.unregister<PackageRequestDetailCubit>();
    }
    getIt.registerFactoryParam<PackageRequestDetailCubit, String, void>(
      (requestId, _) => PackageRequestDetailCubit(repo, announcements, bids, analytics, requestId: requestId),
    );
    if (getIt.isRegistered<RatingBloc>()) getIt.unregister<RatingBloc>();
    getIt.registerFactory<RatingBloc>(() => ratingBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestDetailCubit>()) await getIt.unregister<PackageRequestDetailCubit>();
    if (getIt.isRegistered<RatingBloc>()) await getIt.unregister<RatingBloc>();
  });

  testWidgets('1. chargement : squelette puis billet', (tester) async {
    final completer = Completer<PackageRequest>();
    when(() => repo.getById('pr-1')).thenAnswer((_) => completer.future);
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pump();

    expect(find.byType(RequestDetailSkeleton), findsOneWidget);

    completer.complete(_fakeRequest());
    await tester.pumpAndSettle();

    expect(find.byType(RequestDetailSkeleton), findsNothing);
    expect(find.text('DIV'), findsOneWidget);
  });

  testWidgets('2. erreur de getById → message, Réessayer recharge le billet', (tester) async {
    var callCount = 0;
    when(() => repo.getById('pr-1')).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('Network error');
      return _fakeRequest();
    });
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger ta demande'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('DIV'), findsOneWidget);
  });

  testWidgets('3. brouillon → tap Publier appelle repo.publish', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.draft));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
    when(() => repo.publish('pr-1')).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.draft));

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    verify(() => repo.publish('pr-1')).called(1);
  });

  testWidgets('4. publiée → « … » → Dépublier appelle repo.unpublish', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
    when(() => repo.unpublish('pr-1')).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.draft));

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Plus d'actions"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dépublier'));
    await tester.pumpAndSettle();

    verify(() => repo.unpublish('pr-1')).called(1);
  });

  testWidgets(
    '5. publiée → « … » → Annuler la demande → dialogue → confirmer : bandeau '
    'annulée + Publier une demande similaire, écran ne se ferme pas',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
      when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
      when(() => repo.cancel('pr-1')).thenAnswer((_) async {});

      await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Plus d'actions"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler cette demande ?'), findsOneWidget);

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('pr-1')).called(1);
      expect(find.text('Tu as annulé cette demande'), findsOneWidget);
      expect(find.text('Publier une demande similaire'), findsOneWidget);
      // L'écran ne se ferme plus (pas de context.pop() après annulation).
      expect(find.text('Ma demande'), findsOneWidget);
    },
  );

  testWidgets(
    "6. annulation en échec : snackbar d'erreur, écran reste sur le cas publié",
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
      when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
      when(() => repo.cancel('pr-1')).thenThrow(Exception('409 has-offers'));

      await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("Plus d'actions"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('pr-1')).called(1);
      expect(find.text('Une erreur est survenue. Réessaie dans un instant.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      // Toujours le cas publié (pas annulé) : le billet reste affiché.
      expect(find.text('Tu as annulé cette demande'), findsNothing);
      expect(find.text('DIV'), findsOneWidget);
    },
  );

  testWidgets(
    '7. publiée avec voyageurs → tap Inviter appelle repo.inviteTraveler puis affiche Invité',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
      when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
      when(() => repo.getInsights('pr-1')).thenAnswer(
        (_) async => const PackageRequestInsights(viewCount: 3, invitedAnnouncementIds: {}),
      );
      stubSearch([_trip('a-1')]);
      when(() => repo.inviteTraveler('pr-1', 'a-1')).thenAnswer((_) async => InvitationOutcome.sent);

      await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
      await tester.pumpAndSettle();

      expect(find.text('Inviter'), findsOneWidget);
      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();

      verify(() => repo.inviteTraveler('pr-1', 'a-1')).called(1);
      expect(find.text('Invité'), findsOneWidget);
      expect(find.text('Invitation envoyée. Le voyageur est prévenu.'), findsOneWidget);
    },
  );

  testWidgets('8. acceptée : pas de Modifier, bouton Suivre mon colis présent', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.accepted));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Suivre mon colis'), findsOneWidget);
  });

  testWidgets('9. expirée : pas de bouton « … » (menu vide)', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.expired));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.byTooltip("Plus d'actions"), findsNothing);
  });
}
