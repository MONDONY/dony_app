import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
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
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
  });

  setUp(() => repo = _MockRepo());

  final fakeRequest = PackageRequest(
    id: 'r-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 2,
    weightKg: 5,
    parcelSize: ParcelSize.small,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  final fakeDraftRequest = PackageRequest(
    id: 'r-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 2,
    weightKg: 5,
    parcelSize: ParcelSize.small,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.draft,
    createdAt: DateTime(2026, 5, 10),
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'step 1 → step 2 transitions update currentStep',
    build: () => makeBloc(repo),
    act: (bloc) => bloc
      ..add(
        FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane,
        ),
      )
      ..add(
        const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          categories: const ['Vêtements'],
        ),
      ),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.currentStep,
        'currentStep',
        1,
      ),
      isA<PackageRequestFormState>().having(
        (s) => s.currentStep,
        'currentStep',
        2,
      ),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'submit complete → calls repo.create + Success state',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      ).thenAnswer((_) async => fakeRequest);
      return makeBloc(repo);
    },
    act: (bloc) => bloc
      ..add(
        FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane,
        ),
      )
      ..add(
        const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          categories: const ['Vêtements'],
        ),
      )
      ..add(const FormStep3Submitted(targetPriceEur: 25)),
    skip: 2,
    expect: () => [
      // submitting + targetPriceEur posés dans le même emit
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.submitting,
          )
          .having((s) => s.targetPriceEur, 'targetPriceEur', 25.0),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.success,
          )
          .having((s) => s.createdRequest, 'createdRequest', fakeRequest),
    ],
    verify: (_) {
      verify(
        () => repo.create(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          weightKg: 5,
          parcelSize: ParcelSize.small,
          transportMode: TransportMode.plane,
          categories: const ['Vêtements'],
          negotiable: true,
          acceptedPaymentMethods: {PaymentMethod.stripe},
          totalBudgetEur: 25,
          description: null,
          photoKeys: null,
          pickupNeighborhood: null,
          deliveryNeighborhood: null,
        ),
      ).called(1);
    },
  );

  // ── Brouillons (saveAsDraft) ────────────────────────────────────────────────
  final draftValidSeed = PackageRequestFormState(
    currentStep: 2,
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 2,
    transportMode: TransportMode.plane,
    weightKg: 5,
    parcelSize: ParcelSize.small,
    categories: const ['Vêtements'],
    totalBudgetEur: 25,
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStep3Submitted(saveAsDraft: true) creates with saveAsDraft:true',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenAnswer((_) async => fakeRequest);
      return makeBloc(repo);
    },
    seed: () => draftValidSeed,
    act: (b) => b.add(const FormStep3Submitted(saveAsDraft: true)),
    verify: (b) {
      final captured = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: captureAny(named: 'saveAsDraft'),
        ),
      ).captured;
      expect(captured.single, isTrue);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStep3Submitted() without saveAsDraft creates with saveAsDraft:false',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenAnswer((_) async => fakeRequest);
      return makeBloc(repo);
    },
    seed: () => draftValidSeed,
    act: (b) => b.add(const FormStep3Submitted()),
    verify: (b) {
      final captured = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: captureAny(named: 'saveAsDraft'),
        ),
      ).captured;
      expect(captured.single, isFalse);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'publier publie automatiquement si la creation revient en DRAFT',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenAnswer((_) async => fakeDraftRequest);
      when(() => repo.publish('r-1')).thenAnswer((_) async => fakeRequest);
      return makeBloc(repo);
    },
    seed: () => draftValidSeed,
    act: (b) => b.add(const FormStep3Submitted()),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus,
        'submissionStatus',
        FormSubmissionStatus.submitting,
      ),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.success,
          )
          .having(
            (s) => s.createdRequest?.status,
            'createdRequest.status',
            PackageRequestStatus.open,
          ),
    ],
    verify: (_) {
      final captured = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: captureAny(named: 'saveAsDraft'),
        ),
      ).captured;
      expect(captured.single, isFalse);
      verify(() => repo.publish('r-1')).called(1);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStep3Submitted sans budget ne crée pas la demande',
    build: () => makeBloc(repo),
    seed: () => draftValidSeed.copyWith(clearTotalBudgetEur: true),
    act: (b) => b.add(const FormStep3Submitted(saveAsDraft: true)),
    expect: () => [
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.error,
          )
          .having(
            (s) => s.errorMessage,
            'errorMessage',
            'Indique un budget pour continuer',
          )
          .having((s) => s.draftLimitMessage, 'draftLimitMessage', isNull),
    ],
    verify: (_) {
      verifyNever(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      );
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'draft-limit-reached (403) sets draftLimitMessage, not the generic errorMessage',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/package-requests'),
          error: const ForbiddenException(
            'Limite de 1 brouillon(s) atteinte.',
            'draft-limit-reached',
          ),
        ),
      );
      return makeBloc(repo);
    },
    seed: () => draftValidSeed,
    act: (b) => b.add(const FormStep3Submitted(saveAsDraft: true)),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus,
        'submissionStatus',
        FormSubmissionStatus.submitting,
      ),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.error,
          )
          .having(
            (s) => s.draftLimitMessage,
            'draftLimitMessage',
            'Limite de 1 brouillon(s) atteinte.',
          )
          .having((s) => s.errorMessage, 'errorMessage', isNull),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    // Régression : une tentative précédente ayant buté sur draft-limit-reached
    // laissait draftLimitMessage figé sur son ancien message ; une nouvelle
    // tentative échouant pour une raison différente (générique) devait quand
    // même en repartir propre, sans quoi les deux messages coexistent avec
    // des valeurs contradictoires dans le même state.
    'new submission after a previous draft-limit error clears the stale draftLimitMessage',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenThrow(Exception('boom'));
      return makeBloc(repo);
    },
    // État déjà porteur d'un draftLimitMessage périmé, comme après un 1er
    // échec draft-limit-reached lors d'une tentative précédente.
    seed: () => draftValidSeed.copyWith(
      submissionStatus: FormSubmissionStatus.error,
      draftLimitMessage: 'Limite de 1 brouillon(s) atteinte.',
    ),
    act: (b) => b.add(const FormStep3Submitted()),
    expect: () => [
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.submitting,
          )
          .having((s) => s.draftLimitMessage, 'draftLimitMessage', isNull),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'submissionStatus',
            FormSubmissionStatus.error,
          )
          .having((s) => s.draftLimitMessage, 'draftLimitMessage', isNull)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  // ── Mode édition ────────────────────────────────────────────────────────────
  final editRequest = PackageRequest(
    id: 'r-edit',
    senderId: 's-1',
    departureCity: 'Lyon',
    arrivalCity: 'Bamako',
    desiredDate: DateTime(2026, 7, 20),
    dateToleranceDays: 3,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
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
    expect(s.acceptedPaymentMethods, {
      PaymentMethod.stripe,
      PaymentMethod.cash,
    });
    expect(s.totalBudgetEur, closeTo(56.0, 0.001));
    bloc.close();
  });

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'mode édition : step 3 submit appelle repo.update (pas create) + Success',
    build: () {
      when(
        () => repo.update(
          any(),
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      ).thenAnswer((_) async => editRequest);
      return PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editRequest,
      );
    },
    act: (bloc) => bloc.add(const FormStep3Submitted()),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus,
        'status',
        FormSubmissionStatus.submitting,
      ),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'status',
            FormSubmissionStatus.success,
          )
          .having((s) => s.createdRequest, 'saved', editRequest),
    ],
    verify: (_) {
      verify(
        () => repo.update(
          'r-edit',
          departureCity: 'Lyon',
          arrivalCity: 'Bamako',
          desiredDate: DateTime(2026, 7, 20),
          dateToleranceDays: 3,
          weightKg: 8,
          parcelSize: ParcelSize.medium,
          transportMode: TransportMode.plane,
          categories: const ['Vêtements'],
          negotiable: false,
          acceptedPaymentMethods: {PaymentMethod.stripe, PaymentMethod.cash},
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      ).called(1);
      verifyNever(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      );
    },
  );

  final editDraftRequest = PackageRequest(
    id: 'r-draft-edit',
    senderId: 's-1',
    departureCity: 'Lyon',
    arrivalCity: 'Bamako',
    desiredDate: DateTime(2026, 7, 20),
    dateToleranceDays: 3,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.draft,
    createdAt: DateTime(2026, 5, 10),
    negotiable: false,
    targetPriceEur: 50.0,
    acceptedPaymentMethods: const {PaymentMethod.stripe, PaymentMethod.cash},
  );

  final publishedEditRequest = PackageRequest(
    id: 'r-draft-edit',
    senderId: 's-1',
    departureCity: 'Lyon',
    arrivalCity: 'Bamako',
    desiredDate: DateTime(2026, 7, 20),
    dateToleranceDays: 3,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
    negotiable: false,
    targetPriceEur: 50.0,
    acceptedPaymentMethods: const {PaymentMethod.stripe, PaymentMethod.cash},
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'publier un brouillon édité appelle update puis publish',
    build: () {
      when(
        () => repo.update(
          any(),
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      ).thenAnswer((_) async => editDraftRequest);
      when(
        () => repo.publish('r-draft-edit'),
      ).thenAnswer((_) async => publishedEditRequest);
      return PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editDraftRequest,
      );
    },
    act: (bloc) => bloc.add(const FormStep3Submitted()),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus,
        'status',
        FormSubmissionStatus.submitting,
      ),
      isA<PackageRequestFormState>()
          .having(
            (s) => s.submissionStatus,
            'status',
            FormSubmissionStatus.success,
          )
          .having(
            (s) => s.createdRequest?.status,
            'createdRequest.status',
            PackageRequestStatus.open,
          ),
    ],
    verify: (_) {
      verify(() => repo.publish('r-draft-edit')).called(1);
    },
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'repo throws → Error state',
    build: () {
      when(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: any(named: 'transportMode'),
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
          pickupNeighborhood: any(named: 'pickupNeighborhood'),
          deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        ),
      ).thenThrow(Exception('boom'));
      return makeBloc(repo);
    },
    act: (bloc) => bloc
      ..add(
        FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 6, 15),
          dateToleranceDays: 2,
          transportMode: TransportMode.plane,
        ),
      )
      ..add(
        const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.small,
          categories: const ['Vêtements'],
        ),
      )
      ..add(const PackageRequestTotalBudgetChanged(25))
      ..add(const FormStep3Submitted()),
    skip: 4,
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.submissionStatus,
        'submissionStatus',
        FormSubmissionStatus.error,
      ),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormReset → empty state',
    build: () => makeBloc(repo),
    seed: () =>
        const PackageRequestFormState(currentStep: 2, departureCity: 'X'),
    act: (bloc) => bloc.add(const FormReset()),
    expect: () => [const PackageRequestFormState()],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'FormStepBack on step 1 → step 0',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(currentStep: 1),
    act: (bloc) => bloc.add(const FormStepBack()),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.currentStep,
        'currentStep',
        0,
      ),
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
      isA<PackageRequestFormState>().having(
        (s) => s.negotiable,
        'negotiable',
        false,
      ),
    ],
  );

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    'toggle CASH adds it to acceptedPaymentMethods',
    build: () => makeBloc(repo),
    act: (b) =>
        b.add(const PackageRequestPaymentMethodToggled(PaymentMethod.cash)),
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
    act: (b) =>
        b.add(const PackageRequestPaymentMethodToggled(PaymentMethod.stripe)),
    // BLoC does not emit when the resulting set equals the current state.
    expect: () => [],
    verify: (b) =>
        expect(b.state.acceptedPaymentMethods, {PaymentMethod.stripe}),
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

  blocTest<PackageRequestFormBloc, PackageRequestFormState>(
    // Régression : le champ prix effacé (retour à null) restait bloqué sur
    // l'ancienne valeur — copyWith(totalBudgetEur: null) retombait sur
    // this.totalBudgetEur via `??`, laissant le bouton "Publier" actif alors
    // que le champ était vide à l'écran.
    'total budget cleared (null) after being set actually clears it',
    build: () => makeBloc(repo),
    seed: () => const PackageRequestFormState(totalBudgetEur: 39.20),
    act: (b) => b.add(const PackageRequestTotalBudgetChanged(null)),
    expect: () => [
      isA<PackageRequestFormState>().having(
        (s) => s.totalBudgetEur,
        'totalBudgetEur',
        isNull,
      ),
    ],
  );
}
