import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_bottom_bar.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

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

Widget _buildApp() {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => PackageRequestDetailBottomSheet.show(ctx, 'pr-1'),
            child: const Text('open sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late _MockPackageRequestRepository repo;
  late _MockAnnouncementRepository announcements;
  late _MockBidRepository bids;
  late _MockAnalyticsService analytics;
  late _MockRatingBloc ratingBloc;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockPackageRequestRepository();
    announcements = _MockAnnouncementRepository();
    bids = _MockBidRepository();
    analytics = _MockAnalyticsService();
    ratingBloc = _MockRatingBloc();

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    when(
      () => ratingBloc.stream,
    ).thenAnswer((_) => const Stream<RatingState>.empty());
    when(
      () => announcements.searchAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
      ),
    ).thenAnswer((_) async => const []);

    if (getIt.isRegistered<PackageRequestDetailCubit>()) {
      getIt.unregister<PackageRequestDetailCubit>();
    }
    getIt.registerFactoryParam<PackageRequestDetailCubit, String, void>(
      (requestId, _) => PackageRequestDetailCubit(
        repo,
        announcements,
        bids,
        analytics,
        requestId: requestId,
      ),
    );
    if (getIt.isRegistered<RatingBloc>()) getIt.unregister<RatingBloc>();
    getIt.registerFactory<RatingBloc>(() => ratingBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestDetailCubit>()) {
      await getIt.unregister<PackageRequestDetailCubit>();
    }
    if (getIt.isRegistered<RatingBloc>()) await getIt.unregister<RatingBloc>();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ouvre avec poignée, titre « Ma demande », billet et barre fixe',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
      when(
        () => repo.listThreadsForRequest('pr-1'),
      ).thenAnswer((_) async => []);

      await openSheet(tester);

      expect(find.text('Ma demande'), findsOneWidget);
      expect(find.text('DIV'), findsOneWidget);
      expect(find.byType(RequestDetailBottomBar), findsOneWidget);
    },
  );

  testWidgets('Fermer ferme la sheet', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await openSheet(tester);
    expect(find.text('Ma demande'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Ma demande'), findsNothing);
    expect(find.text('open sheet'), findsOneWidget);
  });
}
