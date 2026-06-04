import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(ContentCategory.vetements);
  });

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  PackageRequestFormBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return PackageRequestFormBloc(repo, analytics: a);
  }

  final fakeRequest = PackageRequest(
    id: 'r-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 3,
    weightKg: 5,
    parcelSize: ParcelSize.small,
    transportMode: TransportMode.plane,
    contentCategory: ContentCategory.vetements,
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  test('package_request_created fires with corridor on step3 success', () async {
    when(() => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          contentCategory: any(named: 'contentCategory'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        )).thenAnswer((_) async => fakeRequest);

    final bloc = makeBloc();
    bloc.add(FormStep1Submitted(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 3,
      transportMode: TransportMode.plane,
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep2Submitted(
      weightKg: 5.0,
      parcelSize: ParcelSize.small,
      contentCategory: ContentCategory.vetements,
      description: 'test',
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep3Submitted(targetPriceEur: 50.0));
    await bloc.stream.firstWhere((s) => s.submissionStatus == FormSubmissionStatus.success);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
          AnalyticsEvents.packageRequestCreated,
          {
            'corridor': 'Paris→Dakar',
            'negotiable': true,
            'payment_methods': ['STRIPE'],
          },
        )).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          contentCategory: any(named: 'contentCategory'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        )).thenAnswer((_) async => fakeRequest);

    final bloc = makeBloc(enabled: false);
    bloc.add(FormStep1Submitted(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 3,
      transportMode: TransportMode.plane,
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep2Submitted(
      weightKg: 5.0,
      parcelSize: ParcelSize.small,
      contentCategory: ContentCategory.vetements,
      description: 'test',
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep3Submitted(targetPriceEur: 50.0));
    await bloc.stream.firstWhere((s) => s.submissionStatus == FormSubmissionStatus.success);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
