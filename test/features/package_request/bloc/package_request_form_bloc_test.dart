import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
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
    contentCategory: 'vetements',
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'step 1 → step 2 transitions update currentStep',
    build: () => PackageRequestFormBloc(repo),
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
          contentCategory: 'vetements')),
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
            parcelSize: any(named: 'parcelSize'),
            transportMode: any(named: 'transportMode'),
            contentCategory: any(named: 'contentCategory'),
            description: any(named: 'description'),
            targetPriceEur: any(named: 'targetPriceEur'),
            photoUrl: any(named: 'photoUrl'),
            pickupNeighborhood: any(named: 'pickupNeighborhood'),
            deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          )).thenAnswer((_) async => fakeRequest);
      return PackageRequestFormBloc(repo);
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
          contentCategory: 'vetements'))
      ..add(const FormStep3Submitted(targetPriceEur: 25)),
    skip: 2,
    expect: () => [
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.submitting),
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
            parcelSize: ParcelSize.small,
            transportMode: TransportMode.plane,
            contentCategory: 'vetements',
            description: null,
            targetPriceEur: 25,
            photoUrl: null,
            pickupNeighborhood: null,
            deliveryNeighborhood: null,
          )).called(1);
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
            parcelSize: any(named: 'parcelSize'),
            transportMode: any(named: 'transportMode'),
            contentCategory: any(named: 'contentCategory'),
            description: any(named: 'description'),
            targetPriceEur: any(named: 'targetPriceEur'),
            photoUrl: any(named: 'photoUrl'),
            pickupNeighborhood: any(named: 'pickupNeighborhood'),
            deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          )).thenThrow(Exception('boom'));
      return PackageRequestFormBloc(repo);
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
          contentCategory: 'vetements'))
      ..add(const FormStep3Submitted()),
    skip: 3,
    expect: () => [
      isA<PackageRequestFormState>()
          .having((s) => s.submissionStatus, 'submissionStatus', FormSubmissionStatus.error),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormReset → empty state',
    build: () => PackageRequestFormBloc(repo),
    seed: () => const PackageRequestFormState(currentStep: 2, departureCity: 'X'),
    act: (bloc) => bloc.add(const FormReset()),
    expect: () => [const PackageRequestFormState()],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStepBack on step 1 → step 0',
    build: () => PackageRequestFormBloc(repo),
    seed: () => const PackageRequestFormState(currentStep: 1),
    act: (bloc) => bloc.add(const FormStepBack()),
    expect: () => [
      isA<PackageRequestFormState>().having((s) => s.currentStep, 'currentStep', 0),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStepBack on step 0 → no state change',
    build: () => PackageRequestFormBloc(repo),
    act: (bloc) => bloc.add(const FormStepBack()),
    expect: () => [],
  );
}
