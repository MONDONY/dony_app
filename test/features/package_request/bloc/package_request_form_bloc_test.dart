import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

PackageRequestFormBloc makeBloc(_MockRepo repo) => PackageRequestFormBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(ContentCategory.vetements);
  });

  setUp(() => repo = _MockRepo());

  final fakeRequest = PackageRequest(
    id: 'r-1', senderId: 's-1',
    departureCity: 'Paris', arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 2,
    weightKg: 5,
    parcelSize: ParcelSize.small,
    transportMode: TransportMode.plane,
    contentCategory: ContentCategory.vetements,
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'step 1 → step 2 transitions update currentStep',
    build: () => makeBloc(repo),
    act: (bloc) => bloc
      ..add(FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane))
      ..add(const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          contentCategory: ContentCategory.vetements)),
    expect: () => [
      isA<PackageRequestFormState>().having((s) => s.currentStep, 'currentStep', 1),
      isA<PackageRequestFormState>().having((s) => s.currentStep, 'currentStep', 2),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'submit complete → calls repo.create + Success state',
    build: () {
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
      return makeBloc(repo);
    },
    act: (bloc) => bloc
      ..add(FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane))
      ..add(const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          contentCategory: ContentCategory.vetements))
      ..add(const FormStep3Submitted(targetPriceEur: 25)),
    skip: 2,
    expect: () => [
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.submitting),
      // Intermediate state: targetPriceEur/photo/neighborhoods saved before repo.create
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.submitting)
          .having((s) => s.targetPriceEur, 'targetPriceEur', 25.0),
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.success)
          .having((s) => s.createdRequest, 'createdRequest', fakeRequest),
    ],
    verify: (_) {
      verify(() => repo.create(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            desiredDate: DateTime(2026, 6, 15),
            dateToleranceDays: 2,
            weightKg: 5,
            contentCategory: ContentCategory.vetements,
            negotiable: true,
            acceptedPaymentMethods: {PaymentMethod.stripe},
            totalBudgetEur: 25,
            description: null,
            photoUrl: null,
            pickupNeighborhood: null,
            deliveryNeighborhood: null,
          )).called(1);
    },
  );

  // ── Mode édition ────────────────────────────────────────────────────────────
  final editRequest = PackageRequest(
    id: 'r-edit', senderId: 's-1',
    departureCity: 'Lyon', arrivalCity: 'Bamako',
    desiredDate: DateTime(2026, 7, 20),
    dateToleranceDays: 3,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    contentCategory: ContentCategory.vetements,
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
    negotiable: false,
    targetPriceEur: 50.0, // net → brut attendu : 50 * 1.12 = 56
    acceptedPaymentMethods: const {PaymentMethod.stripe, PaymentMethod.cash},
  );

  test('mode édition : état initial pré-rempli (id, champs, budget brut)', () {
    final bloc = PackageRequestFormBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      editing: editRequest,
    );
    final s = bloc.state;
    expect(s.isEditing, true);
    expect(s.editingRequestId, 'r-edit');
    expect(s.departureCity, 'Lyon');
    expect(s.arrivalCity, 'Bamako');
    expect(s.weightKg, 8);
    expect(s.parcelSize, ParcelSize.medium);
    expect(s.negotiable, false);
    expect(s.acceptedPaymentMethods,
        {PaymentMethod.stripe, PaymentMethod.cash});
    expect(s.totalBudgetEur, closeTo(56.0, 0.001));
    bloc.close();
  });

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'mode édition : step 3 submit appelle repo.update (pas create) + Success',
    build: () {
      when(() => repo.update(
            any(),
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
          )).thenAnswer((_) async => editRequest);
      return PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editRequest,
      );
    },
    act: (bloc) => bloc.add(const FormStep3Submitted()),
    expect: () => [
      isA<PackageRequestFormState>().having(
          (s) => s.submissionStatus, 'status', FormSubmissionStatus.submitting),
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'status', FormSubmissionStatus.success)
          .having((s) => s.createdRequest, 'saved', editRequest),
    ],
    verify: (_) {
      verify(() => repo.update(
            'r-edit',
            departureCity: 'Lyon',
            arrivalCity: 'Bamako',
            desiredDate: DateTime(2026, 7, 20),
            dateToleranceDays: 3,
            weightKg: 8,
            contentCategory: ContentCategory.vetements,
            negotiable: false,
            acceptedPaymentMethods: {PaymentMethod.stripe, PaymentMethod.cash},
            totalBudgetEur: any(named: 'totalBudgetEur'),
            description: any(named: 'description'),
            photoUrl: any(named: 'photoUrl'),
            pickupNeighborhood: any(named: 'pickupNeighborhood'),
            deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          )).called(1);
      verifyNever(() => repo.create(
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
          ));
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'repo throws → Error state',
    build: () {
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
          )).thenThrow(Exception('boom'));
      return makeBloc(repo);
    },
    act: (bloc) => bloc
      ..add(FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane))
      ..add(const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          contentCategory: ContentCategory.vetements))
      ..add(const FormStep3Submitted()),
    skip: 3,
    expect: () => [
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.error),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormReset → empty state',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(currentStep: 2, departureCity: 'X'),
    act: (bloc) => bloc.add(const FormReset()),
    expect: () => [const PackageRequestFormState()],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStepBack on step 1 → step 0',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(currentStep: 1),
    act: (bloc) => bloc.add(const FormStepBack()),
    expect: () => [
      isA<PackageRequestFormState>().having((s) => s.currentStep, 'currentStep', 0),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStepBack on step 0 → no state change',
    build: () => makeBloc(repo),
    act: (bloc) => bloc.add(const FormStepBack()),
    expect: () => [],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'toggle negotiable off updates state',
    build: () => makeBloc(repo),
    act: (b) => b.add(const PackageRequestNegotiableToggled(false)),
    expect: () => [
      isA<PackageRequestFormState>()
          .having((s) => s.negotiable, 'negotiable', false),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'toggle CASH adds it to acceptedPaymentMethods',
    build: () => makeBloc(repo),
    act: (b) => b.add(const PackageRequestPaymentMethodToggled(PaymentMethod.cash)),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.acceptedPaymentMethods.contains(PaymentMethod.cash),
        'has CASH',
        true,
      ),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'toggle STRIPE when it is the only method keeps STRIPE (cannot empty) — no emission',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(
      acceptedPaymentMethods: {PaymentMethod.stripe},
    ),
    act: (b) => b.add(const PackageRequestPaymentMethodToggled(PaymentMethod.stripe)),
    // BLoC does not emit when the resulting set equals the current state.
    expect: () => [],
    verify: (b) => expect(
      b.state.acceptedPaymentMethods,
      {PaymentMethod.stripe},
    ),
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'total budget changed updates state',
    build: () => makeBloc(repo),
    act: (b) => b.add(const PackageRequestTotalBudgetChanged(39.20)),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.totalBudgetEur,
        'totalBudgetEur',
        closeTo(39.20, 0.001),
      ),
    ],
  );
}
