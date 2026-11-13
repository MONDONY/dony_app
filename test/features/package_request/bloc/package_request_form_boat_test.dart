import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/parcel_fit_wire.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_duplicate.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

/// Demande d'envoi en bateau : dimensions obligatoires, « peu importe » tout ou
/// rien, avion et route sans dimensions (le volume n'est jamais envoyé).
void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerFallbackValue(const FieldChange<ItemSize>.keep());
  });

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  Future<PackageRequestFormBloc> makeBloc({
    PackageRequest? editing,
    PackageRequestDuplicate? duplicating,
  }) async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    return PackageRequestFormBloc(
      repo,
      analytics: analytics,
      editing: editing,
      duplicating: duplicating,
    );
  }

  PackageRequest request({
    TransportMode? mode,
    int? l,
    int? w,
    int? h,
    PackageRequestStatus status = PackageRequestStatus.open,
  }) => PackageRequest(
    id: 'r-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    dateToleranceDays: 0,
    weightKg: 20,
    parcelSize: ParcelSize.large,
    transportMode: mode,
    categories: const ['Meubles'],
    status: status,
    createdAt: DateTime(2026, 11, 12),
    lengthCm: l,
    widthCm: w,
    heightCm: h,
    volumeM3: l == null ? null : l * w! * h! / 1000000,
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
      lengthCm: any(named: 'lengthCm'),
      widthCm: any(named: 'widthCm'),
      heightCm: any(named: 'heightCm'),
    ),
  );

  When<Future<PackageRequest>> stubUpdate() => when(
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
      photoKeys: any(named: 'photoKeys'),
      pickupNeighborhood: any(named: 'pickupNeighborhood'),
      deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
      promoCode: any(named: 'promoCode'),
      itemSize: any(named: 'itemSize'),
      lengthCm: any(named: 'lengthCm'),
      widthCm: any(named: 'widthCm'),
      heightCm: any(named: 'heightCm'),
    ),
  );

  Future<void> fill(
    PackageRequestFormBloc bloc,
    TransportMode? mode, {
    int? l,
    int? w,
    int? h,
  }) async {
    bloc.add(
      FormStep1Submitted(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        desiredDate: null,
        dateToleranceDays: null,
        transportMode: mode,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(
      FormStep2Submitted(
        weightKg: 20,
        parcelSize: ParcelSize.large,
        categories: const ['Meubles'],
        lengthCm: l,
        widthCm: w,
        heightCm: h,
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<PackageRequestFormState> submit(
    PackageRequestFormBloc bloc, {
    bool draft = false,
  }) async {
    bloc.add(FormStep3Submitted(targetPriceEur: 600, saveAsDraft: draft));
    return bloc.stream.firstWhere(
      (s) =>
          s.submissionStatus == FormSubmissionStatus.success ||
          s.submissionStatus == FormSubmissionStatus.error,
    );
  }

  List<Map<String, Object>> captured(String event) => verify(
    () => backend.capture(event, captureAny()),
  ).captured.cast<Map<String, Object>>();

  group('état : dimensions et volume', () {
    test('le volume est un aperçu calculé comme le back', () {
      const state = PackageRequestFormState(
        transportMode: TransportMode.boat,
        lengthCm: 50,
        widthCm: 40,
        heightCm: 50,
      );
      expect(state.hasDimensions, isTrue);
      expect(state.volumeM3, 0.1);
      expect(const PackageRequestFormState().volumeM3, isNull);
      expect(
        const PackageRequestFormState(lengthCm: 50, widthCm: 40).hasDimensions,
        isFalse,
      );
    });

    test(
      'bateau et « peu importe » gardent les dimensions, pas avion ni route',
      () {
        expect(
          const PackageRequestFormState(
            transportMode: TransportMode.boat,
          ).modeKeepsDimensions,
          isTrue,
        );
        expect(
          const PackageRequestFormState(
            transportModeAny: true,
          ).modeKeepsDimensions,
          isTrue,
        );
        for (final mode in [TransportMode.plane, TransportMode.car, null]) {
          // `null` sans « peu importe » : mode jamais choisi, donc avion.
          expect(
            PackageRequestFormState(transportMode: mode).modeKeepsDimensions,
            isFalse,
            reason: '$mode',
          );
        }
      },
    );
  });

  group('boat_requiresDimensions : étape 2 et publication', () {
    test('les trois dimensions sont gardées en bateau', () async {
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat, l: 50, w: 40, h: 30);
      expect(bloc.state.lengthCm, 50);
      expect(bloc.state.widthCm, 40);
      expect(bloc.state.heightCm, 30);
      expect(bloc.state.volumeM3, 0.06);
    });

    test('un jeu incomplet est écarté : tout ou rien', () async {
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat, l: 50, w: 40);
      expect(bloc.state.hasDimensions, isFalse);
      expect(bloc.state.lengthCm, isNull);
    });

    test('bateau sans dimensions : refus local, rien n\'est envoyé', () async {
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat);
      final end = await submit(bloc);

      expect(end.submissionStatus, FormSubmissionStatus.error);
      expect(end.formError, PackageRequestFormError.dimensionsRequired);
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
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        captured(AnalyticsEvents.packageRequestSubmitFailed).single,
        containsPair('error_code', 'boat-dimensions-required'),
      );
    });

    test('création : les dimensions partent, jamais le volume', () async {
      stubCreate().thenAnswer(
        (_) async => request(mode: TransportMode.boat, l: 50, w: 40, h: 30),
      );
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat, l: 50, w: 40, h: 30);
      final end = await submit(bloc);

      expect(end.submissionStatus, FormSubmissionStatus.success);
      final call = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: TransportMode.boat,
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: 600,
          lengthCm: captureAny(named: 'lengthCm'),
          widthCm: captureAny(named: 'widthCm'),
          heightCm: captureAny(named: 'heightCm'),
        ),
      );
      expect(call.captured, [50, 40, 30]);
      await Future<void>.delayed(Duration.zero);
      expect(
        captured(AnalyticsEvents.packageRequestCreated).single,
        allOf(
          containsPair('transport_mode', 'boat'),
          containsPair('has_dimensions', true),
        ),
      );
      expect(
        captured(AnalyticsEvents.packageRequestStepCompleted).last,
        containsPair('has_dimensions', true),
      );
    });
  });

  group('any_dimensionsOptional : « peu importe »', () {
    test('sans dimensions : rien n\'est envoyé', () async {
      stubCreate().thenAnswer((_) async => request());
      final bloc = await makeBloc();
      await fill(bloc, null);
      final end = await submit(bloc);

      expect(end.submissionStatus, FormSubmissionStatus.success);
      final call = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: null,
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          lengthCm: captureAny(named: 'lengthCm'),
          widthCm: captureAny(named: 'widthCm'),
          heightCm: captureAny(named: 'heightCm'),
        ),
      );
      expect(call.captured, [null, null, null]);
      await Future<void>.delayed(Duration.zero);
      expect(
        captured(AnalyticsEvents.packageRequestCreated).single,
        allOf(
          containsPair('transport_mode', 'any'),
          containsPair('has_dimensions', false),
        ),
      );
    });

    test('avec dimensions : elles partent', () async {
      stubCreate().thenAnswer((_) async => request(l: 100, w: 100, h: 100));
      final bloc = await makeBloc();
      await fill(bloc, null, l: 100, w: 100, h: 100);
      await submit(bloc);

      final call = verify(
        () => repo.create(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: null,
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          lengthCm: captureAny(named: 'lengthCm'),
          widthCm: captureAny(named: 'widthCm'),
          heightCm: captureAny(named: 'heightCm'),
        ),
      );
      expect(call.captured, [100, 100, 100]);
    });
  });

  group('plane_unchanged : avion et route sans dimensions', () {
    for (final mode in [TransportMode.plane, TransportMode.car]) {
      test('${mode.name} : les dimensions reçues sont ignorées', () async {
        stubCreate().thenAnswer((_) async => request(mode: mode));
        final bloc = await makeBloc();
        await fill(bloc, mode, l: 50, w: 40, h: 30);
        expect(bloc.state.hasDimensions, isFalse);
        await submit(bloc);

        final call = verify(
          () => repo.create(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            desiredDate: any(named: 'desiredDate'),
            dateToleranceDays: any(named: 'dateToleranceDays'),
            weightKg: any(named: 'weightKg'),
            parcelSize: any(named: 'parcelSize'),
            transportMode: mode,
            categories: any(named: 'categories'),
            negotiable: any(named: 'negotiable'),
            acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
            totalBudgetEur: any(named: 'totalBudgetEur'),
            lengthCm: captureAny(named: 'lengthCm'),
            widthCm: captureAny(named: 'widthCm'),
            heightCm: captureAny(named: 'heightCm'),
          ),
        );
        expect(call.captured, [null, null, null]);
        await Future<void>.delayed(Duration.zero);
        expect(
          captured(AnalyticsEvents.packageRequestCreated).single.keys,
          isNot(contains('has_dimensions')),
        );
        expect(
          captured(AnalyticsEvents.packageRequestStepCompleted).last.keys,
          isNot(contains('has_dimensions')),
        );
      });
    }

    test('bateau puis avion : les dimensions sont effacées', () async {
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat, l: 50, w: 40, h: 30);
      bloc.add(const FormTransportModeChanged(TransportMode.plane));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasDimensions, isFalse);

      bloc.add(const FormTransportModeChanged(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasDimensions, isFalse);
    });

    test('bateau puis « peu importe » : les dimensions sont gardées', () async {
      final bloc = await makeBloc();
      await fill(bloc, TransportMode.boat, l: 50, w: 40, h: 30);
      bloc.add(const FormTransportModeChanged(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.volumeM3, 0.06);
    });
  });

  group('édition et duplication', () {
    test(
      'édition d\'un bateau : dimensions préremplies et renvoyées',
      () async {
        stubUpdate().thenAnswer(
          (_) async => request(mode: TransportMode.boat, l: 50, w: 40, h: 30),
        );
        final bloc = await makeBloc(
          editing: request(mode: TransportMode.boat, l: 50, w: 40, h: 30),
        );
        expect(bloc.state.heightCm, 30);
        bloc.add(const FormStep3Submitted(targetPriceEur: 700));
        await bloc.stream.firstWhere(
          (s) => s.submissionStatus == FormSubmissionStatus.success,
        );
        final call = verify(
          () => repo.update(
            'r-1',
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            desiredDate: any(named: 'desiredDate'),
            dateToleranceDays: any(named: 'dateToleranceDays'),
            weightKg: any(named: 'weightKg'),
            parcelSize: any(named: 'parcelSize'),
            transportMode: TransportMode.boat,
            categories: any(named: 'categories'),
            negotiable: any(named: 'negotiable'),
            acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
            totalBudgetEur: any(named: 'totalBudgetEur'),
            lengthCm: captureAny(named: 'lengthCm'),
            widthCm: captureAny(named: 'widthCm'),
            heightCm: captureAny(named: 'heightCm'),
          ),
        );
        expect(call.captured, [50, 40, 30]);
      },
    );

    test('édition « peu importe » sans dimensions : clés absentes', () async {
      stubUpdate().thenAnswer((_) async => request());
      final bloc = await makeBloc(editing: request());
      bloc.add(const FormStep3Submitted(targetPriceEur: 700));
      await bloc.stream.firstWhere(
        (s) => s.submissionStatus == FormSubmissionStatus.success,
      );
      final call = verify(
        () => repo.update(
          'r-1',
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          desiredDate: any(named: 'desiredDate'),
          dateToleranceDays: any(named: 'dateToleranceDays'),
          weightKg: any(named: 'weightKg'),
          parcelSize: any(named: 'parcelSize'),
          transportMode: null,
          categories: any(named: 'categories'),
          negotiable: any(named: 'negotiable'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          totalBudgetEur: any(named: 'totalBudgetEur'),
          lengthCm: captureAny(named: 'lengthCm'),
          widthCm: captureAny(named: 'widthCm'),
          heightCm: captureAny(named: 'heightCm'),
        ),
      );
      expect(call.captured, [null, null, null]);
    });

    test('dupliquer un bateau reprend ses dimensions', () async {
      final bloc = await makeBloc(
        duplicating: PackageRequestDuplicate(
          request(mode: TransportMode.boat, l: 50, w: 40, h: 30),
        ),
      );
      expect(bloc.state.volumeM3, 0.06);
      expect(bloc.state.isEditing, isFalse);
    });
  });

  group('brouillon local', () {
    PackageRequestFormState boatState({
      int? l = 50,
      int? w = 40,
      int? h = 30,
    }) => PackageRequestFormState(
      currentStep: 1,
      departureCity: 'Paris',
      arrivalCity: 'Abidjan',
      transportMode: TransportMode.boat,
      weightKg: 20,
      lengthCm: l,
      widthCm: w,
      heightCm: h,
    );

    test('aller-retour des dimensions d\'un bateau', () {
      final json = PackageRequestFormDraft.encode(boatState());
      expect(json['lengthCm'], 50);
      expect(json['widthCm'], 40);
      expect(json['heightCm'], 30);
      final back = PackageRequestFormDraft.decode(json);
      expect(back.volumeM3, 0.06);
    });

    test('ancien brouillon sans clés : aucune dimension', () {
      final json = PackageRequestFormDraft.encode(boatState())
        ..remove('lengthCm')
        ..remove('widthCm')
        ..remove('heightCm');
      expect(PackageRequestFormDraft.decode(json).hasDimensions, isFalse);
    });

    test('jeu incomplet écarté à la reprise', () {
      final json = PackageRequestFormDraft.encode(boatState(h: null));
      expect(PackageRequestFormDraft.decode(json).lengthCm, isNull);
    });

    test('brouillon en avion : dimensions écartées', () {
      final json = PackageRequestFormDraft.encode(
        boatState(),
        stepInput: {'transportMode': 'PLANE'},
      );
      expect(PackageRequestFormDraft.decode(json).hasDimensions, isFalse);
    });

    test('la saisie de l\'étape prime sur l\'état du bloc', () {
      final json = PackageRequestFormDraft.encode(
        boatState(l: null, w: null, h: null),
        stepInput: {'lengthCm': 10, 'widthCm': 20, 'heightCm': 30},
      );
      expect(PackageRequestFormDraft.decode(json).volumeM3, 0.006);
    });
  });

  test('FormStep2Submitted : égalité et dimensions', () {
    expect(
      const FormStep2Submitted(
        weightKg: 1,
        parcelSize: ParcelSize.small,
        lengthCm: 1,
        widthCm: 2,
        heightCm: 3,
      ),
      const FormStep2Submitted(
        weightKg: 1,
        parcelSize: ParcelSize.small,
        lengthCm: 1,
        widthCm: 2,
        heightCm: 3,
      ),
    );
    expect(
      const FormStep2Submitted(weightKg: 1, parcelSize: ParcelSize.small),
      isNot(
        const FormStep2Submitted(
          weightKg: 1,
          parcelSize: ParcelSize.small,
          lengthCm: 1,
          widthCm: 2,
          heightCm: 3,
        ),
      ),
    );
  });
}
