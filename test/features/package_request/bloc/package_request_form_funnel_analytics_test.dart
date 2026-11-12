import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

/// Tunnel de création d'une demande d'envoi : étapes validées, brouillon
/// distingué d'une publication, devise et tranche de budget, échecs.
void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
  });

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  Future<PackageRequestFormBloc> makeBloc() async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    return PackageRequestFormBloc(repo, analytics: analytics);
  }

  PackageRequest request(PackageRequestStatus status) => PackageRequest(
    id: 'r-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 6, 15),
    dateToleranceDays: 3,
    weightKg: 5,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: status,
    createdAt: DateTime(2026, 5, 10),
    currency: 'XOF',
  );

  When<Future<PackageRequest>> stubCreate() => when(
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
      photoKeys: any(named: 'photoKeys'),
      saveAsDraft: any(named: 'saveAsDraft'),
      promoCode: any(named: 'promoCode'),
      currency: any(named: 'currency'),
      itemSize: any(named: 'itemSize'),
    ),
  );

  Future<void> fillSteps(PackageRequestFormBloc bloc) async {
    bloc.add(
      FormStep1Submitted(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 6, 15),
        dateToleranceDays: 3,
        transportMode: TransportMode.plane,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(
      const FormStep2Submitted(
        weightKg: 5.0,
        parcelSize: ParcelSize.medium,
        categories: ['Vêtements', 'Livres'],
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  List<Map<String, Object>> capturedAll(String event) => verify(
    () => backend.capture(event, captureAny()),
  ).captured.cast<Map<String, Object>>();

  test('étapes 1 et 2 : package_request_step_completed', () async {
    final bloc = await makeBloc();
    await fillSteps(bloc);
    await Future<void>.delayed(Duration.zero);

    expect(capturedAll(AnalyticsEvents.packageRequestStepCompleted), [
      {
        'step': 1,
        'editing': false,
        'transport_mode': 'plane',
        'has_date': true,
      },
      {
        'step': 2,
        'editing': false,
        'parcel_size': 'MEDIUM',
        'categories_count': 2,
      },
    ]);
  });

  test('brouillon : is_draft vrai, devise et tranche de budget', () async {
    stubCreate().thenAnswer((_) async => request(PackageRequestStatus.draft));
    final bloc = await makeBloc();
    await fillSteps(bloc);

    bloc.add(
      const FormStep3Submitted(targetPriceEur: 120.0, saveAsDraft: true),
    );
    await bloc.stream.firstWhere(
      (s) => s.submissionStatus == FormSubmissionStatus.success,
    );
    await Future<void>.delayed(Duration.zero);

    final props = capturedAll(AnalyticsEvents.packageRequestCreated).single;
    expect(props, containsPair('is_draft', true));
    expect(props, containsPair('currency', 'XOF'));
    expect(props, containsPair('budget_bracket', '>100'));
    expect(props, containsPair('transport_mode', 'plane'));
    expect(props, containsPair('parcel_size', 'MEDIUM'));
    expect(props, containsPair('has_photos', false));
    expect(props, containsPair('has_promo_code', false));
  });

  test('limite de brouillons : package_request_submit_failed', () async {
    stubCreate().thenThrow(
      const ForbiddenException('Limite', 'draft-limit-reached'),
    );
    final bloc = await makeBloc();
    await fillSteps(bloc);

    bloc.add(const FormStep3Submitted(targetPriceEur: 40.0, saveAsDraft: true));
    await bloc.stream.firstWhere(
      (s) => s.submissionStatus == FormSubmissionStatus.error,
    );
    await Future<void>.delayed(Duration.zero);

    expect(capturedAll(AnalyticsEvents.packageRequestSubmitFailed).single, {
      'error_code': 'draft-limit-reached',
      'is_draft': true,
      'editing': false,
    });
    verifyNever(
      () => backend.capture(AnalyticsEvents.packageRequestCreated, any()),
    );
  });

  test(
    'peu importe : transport_mode vaut any (étape 1 et publication)',
    () async {
      stubCreate().thenAnswer((_) async => request(PackageRequestStatus.open));
      final bloc = await makeBloc();
      bloc.add(
        const FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: null,
          dateToleranceDays: null,
          transportMode: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const FormStep2Submitted(
          weightKg: 5.0,
          parcelSize: ParcelSize.medium,
          categories: ['Livres'],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FormStep3Submitted(targetPriceEur: 40.0));
      await bloc.stream.firstWhere(
        (s) => s.submissionStatus == FormSubmissionStatus.success,
      );
      await Future<void>.delayed(Duration.zero);

      final step = capturedAll(
        AnalyticsEvents.packageRequestStepCompleted,
      ).first;
      expect(step, containsPair('transport_mode', 'any'));
      final created = capturedAll(AnalyticsEvents.packageRequestCreated).single;
      expect(created, containsPair('transport_mode', 'any'));
    },
  );

  test(
    'route avec taille : item_size part, sans PII, à la publication',
    () async {
      stubCreate().thenAnswer((_) async => request(PackageRequestStatus.open));
      final bloc = await makeBloc();
      bloc.add(
        const FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: null,
          dateToleranceDays: null,
          transportMode: TransportMode.car,
        ),
      );
      bloc.add(const FormItemSizeChanged(ItemSize.l));
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const FormStep2Submitted(
          weightKg: 1200,
          parcelSize: ParcelSize.large,
          categories: ['Meubles'],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FormStep3Submitted(targetPriceEur: 900));
      await bloc.stream.firstWhere(
        (s) => s.submissionStatus == FormSubmissionStatus.success,
      );
      await Future<void>.delayed(Duration.zero);

      final created = capturedAll(AnalyticsEvents.packageRequestCreated).single;
      expect(created, containsPair('item_size', 'L'));
      expect(created, containsPair('transport_mode', 'car'));
    },
  );

  test('route sans taille : la propriété item_size est absente', () async {
    stubCreate().thenAnswer((_) async => request(PackageRequestStatus.open));
    final bloc = await makeBloc();
    bloc.add(
      const FormStep1Submitted(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: null,
        dateToleranceDays: null,
        transportMode: TransportMode.car,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(
      const FormStep2Submitted(
        weightKg: 1200,
        parcelSize: ParcelSize.large,
        categories: ['Meubles'],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep3Submitted(targetPriceEur: 900));
    await bloc.stream.firstWhere(
      (s) => s.submissionStatus == FormSubmissionStatus.success,
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      capturedAll(
        AnalyticsEvents.packageRequestCreated,
      ).single.containsKey('item_size'),
      isFalse,
    );
  });

  test('poids hors plafond du mode : refus tracé sans PII', () async {
    final bloc = await makeBloc();
    bloc.add(
      const FormStep1Submitted(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: null,
        dateToleranceDays: null,
        transportMode: TransportMode.plane,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(
      const FormStep2Submitted(
        weightKg: 1200,
        parcelSize: ParcelSize.large,
        categories: ['Meubles'],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FormStep3Submitted(targetPriceEur: 100));
    await bloc.stream.firstWhere(
      (s) => s.formError == PackageRequestFormError.weightTooHeavyForMode,
    );
    await Future<void>.delayed(Duration.zero);

    expect(capturedAll(AnalyticsEvents.packageRequestSubmitFailed).single, {
      'error_code': 'weight-too-heavy-for-mode',
      'is_draft': false,
      'editing': false,
    });
    verifyNever(
      () => backend.capture(AnalyticsEvents.packageRequestCreated, any()),
    );
  });
}
