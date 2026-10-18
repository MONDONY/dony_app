import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/parcel_refusal/parcel_refusal_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ACCEPTED',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _label = 'Contenu différent de la déclaration';

void main() {
  late _MockBidRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;

  setUpAll(() => registerFallbackValue(ImageSource.camera));

  setUp(() {
    repository = _MockBidRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  ParcelRefusalCubit build() =>
      ParcelRefusalCubit(repository, media, analytics);

  /// Formulaire prêt : motif choisi et photo prise.
  ParcelRefusalState ready({
    ParcelRefusalReason reason = ParcelRefusalReason.contentMismatch,
    String details = '',
    String? photoKey,
  }) => ParcelRefusalState(
    reason: reason,
    details: details,
    photoPath: '/tmp/refus.jpg',
    photoKey: photoKey,
  );

  void stubUpload() => when(
    () => repository.uploadRefusalPhoto(any(), any()),
  ).thenAnswer((_) async => 'tracking/bid-1/refus.jpg');

  void stubRefuse(Future<BidModel> Function() answer) => when(
    () => repository.refuseParcel(
      any(),
      reason: any(named: 'reason'),
      photoKey: any(named: 'photoKey'),
    ),
  ).thenAnswer((_) => answer());

  group('canSubmit', () {
    test('exige un motif et une photo', () {
      expect(const ParcelRefusalState().canSubmit, isFalse);
      expect(
        const ParcelRefusalState(
          reason: ParcelRefusalReason.overweight,
        ).canSubmit,
        isFalse,
      );
      expect(
        const ParcelRefusalState(photoPath: '/tmp/a.jpg').canSubmit,
        isFalse,
      );
      expect(ready().canSubmit, isTrue);
    });

    test('« Autre raison » exige un détail', () {
      expect(ready(reason: ParcelRefusalReason.other).canSubmit, isFalse);
      expect(
        ready(reason: ParcelRefusalReason.other, details: '   ').canSubmit,
        isFalse,
      );
      expect(
        ready(reason: ParcelRefusalReason.other, details: 'Abîmé').canSubmit,
        isTrue,
      );
    });

    test('jamais pendant un envoi', () {
      expect(
        ready().copyWith(status: ParcelRefusalStatus.submitting).canSubmit,
        isFalse,
      );
    });
  });

  group('composeReason', () {
    test('libellé seul sans détail', () {
      expect(ParcelRefusalCubit.composeReason(_label, '  '), _label);
    });

    test('libellé suivi du détail', () {
      expect(
        ParcelRefusalCubit.composeReason(_label, ' Un iPhone '),
        '$_label : Un iPhone',
      );
    });

    test('tronqué à la limite du serveur', () {
      final reason = ParcelRefusalCubit.composeReason(_label, 'x' * 600);
      expect(reason.length, kParcelRefusalReasonMaxLength);
      expect(reason, startsWith(_label));
    });
  });

  group('formulaire', () {
    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'motif et détail sont gardés',
      build: build,
      act: (cubit) => cubit
        ..selectReason(ParcelRefusalReason.prohibited)
        ..detailsChanged('Parfum'),
      verify: (cubit) {
        expect(cubit.state.reason, ParcelRefusalReason.prohibited);
        expect(cubit.state.details, 'Parfum');
        expect(cubit.state.status, ParcelRefusalStatus.editing);
      },
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'une nouvelle photo efface la clé déjà envoyée',
      build: () {
        when(
          () => media.pick(source: any(named: 'source')),
        ).thenAnswer((_) async => XFile('/tmp/nouvelle.jpg'));
        return build();
      },
      seed: () => ready(photoKey: 'ancienne'),
      act: (cubit) => cubit.takePhoto(),
      verify: (cubit) {
        expect(cubit.state.photoPath, '/tmp/nouvelle.jpg');
        expect(cubit.state.photoKey, isNull);
        verify(() => media.pick(source: ImageSource.camera)).called(1);
      },
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'prise de vue annulée : rien ne change',
      build: () {
        when(
          () => media.pick(source: any(named: 'source')),
        ).thenAnswer((_) async => null);
        return build();
      },
      act: (cubit) => cubit.takePhoto(),
      expect: () => <ParcelRefusalState>[],
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'photo illisible : statut photoFailed, formulaire intact',
      build: () {
        when(
          () => media.pick(source: any(named: 'source')),
        ).thenThrow(const UnsupportedMediaTypeException('video.mp4'));
        return build();
      },
      seed: () =>
          const ParcelRefusalState(reason: ParcelRefusalReason.overweight),
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        isA<ParcelRefusalState>()
            .having((s) => s.status, 'status', ParcelRefusalStatus.photoFailed)
            .having((s) => s.reason, 'reason', ParcelRefusalReason.overweight),
      ],
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'pas de prise de vue pendant un envoi',
      build: build,
      seed: () => ready().copyWith(status: ParcelRefusalStatus.submitting),
      act: (cubit) => cubit.takePhoto(),
      verify: (_) =>
          verifyNever(() => media.pick(source: any(named: 'source'))),
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'retirer la photo',
      build: build,
      seed: () => ready(photoKey: 'k'),
      act: (cubit) => cubit.removePhoto(),
      verify: (cubit) {
        expect(cubit.state.photoPath, isNull);
        expect(cubit.state.photoKey, isNull);
        expect(cubit.state.canSubmit, isFalse);
      },
    );
  });

  group('submit', () {
    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'envoie la photo puis le refus, succès et analytics sans le détail',
      build: () {
        stubUpload();
        stubRefuse(() async => _bid(status: 'PARCEL_REFUSED'));
        return build();
      },
      seed: () => ready(details: 'Un téléphone'),
      act: (cubit) => cubit.submit(_bid(), reasonLabel: _label),
      expect: () => [
        isA<ParcelRefusalState>().having(
          (s) => s.status,
          'status',
          ParcelRefusalStatus.submitting,
        ),
        isA<ParcelRefusalState>()
            .having((s) => s.status, 'status', ParcelRefusalStatus.submitting)
            .having((s) => s.photoKey, 'photoKey', 'tracking/bid-1/refus.jpg'),
        isA<ParcelRefusalState>()
            .having((s) => s.status, 'status', ParcelRefusalStatus.success)
            .having((s) => s.bid?.status, 'bid', 'PARCEL_REFUSED'),
      ],
      verify: (_) {
        verify(
          () => repository.uploadRefusalPhoto('bid-1', '/tmp/refus.jpg'),
        ).called(1);
        verify(
          () => repository.refuseParcel(
            'bid-1',
            reason: '$_label : Un téléphone',
            photoKey: 'tracking/bid-1/refus.jpg',
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.parcelRefused,
            properties: {
              'reason': 'content_mismatch',
              'status': 'ACCEPTED',
              'payment_method': 'stripe',
            },
          ),
        ).called(1);
      },
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'photo déjà envoyée : un nouvel essai ne la renvoie pas',
      build: () {
        stubRefuse(() async => _bid(status: 'PARCEL_REFUSED'));
        return build();
      },
      seed: () => ready(photoKey: 'deja'),
      act: (cubit) => cubit.submit(_bid(), reasonLabel: _label),
      verify: (cubit) {
        expect(cubit.state.status, ParcelRefusalStatus.success);
        verifyNever(() => repository.uploadRefusalPhoto(any(), any()));
        verify(
          () => repository.refuseParcel(
            'bid-1',
            reason: _label,
            photoKey: 'deja',
          ),
        ).called(1);
      },
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'formulaire incomplet : rien ne part',
      build: build,
      seed: () =>
          const ParcelRefusalState(reason: ParcelRefusalReason.overweight),
      act: (cubit) => cubit.submit(_bid(), reasonLabel: _label),
      expect: () => <ParcelRefusalState>[],
      verify: (_) =>
          verifyNever(() => repository.uploadRefusalPhoto(any(), any())),
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      '409 trajet parti : statut conflict et analytics d\'échec',
      build: () {
        stubUpload();
        stubRefuse(
          () async => throw const ConflictException(
            'parti',
            code: 'parcel-refusal-locked',
          ),
        );
        return build();
      },
      seed: ready,
      act: (cubit) =>
          cubit.submit(_bid(status: 'HANDED_OVER'), reasonLabel: _label),
      verify: (cubit) {
        expect(cubit.state.status, ParcelRefusalStatus.conflict);
        expect(cubit.state.error?.code, 'parcel-refusal-locked');
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.parcelRefusalFailed,
            properties: {
              'reason': 'content_mismatch',
              'error_code': 'parcel-refusal-locked',
            },
          ),
        ).called(1);
      },
    );

    blocTest<ParcelRefusalCubit, ParcelRefusalState>(
      'échec de l\'envoi de la photo : statut failure, formulaire gardé',
      build: () {
        when(
          () => repository.uploadRefusalPhoto(any(), any()),
        ).thenThrow(const OfflineException());
        return build();
      },
      seed: ready,
      act: (cubit) => cubit.submit(_bid(), reasonLabel: _label),
      verify: (cubit) {
        expect(cubit.state.status, ParcelRefusalStatus.failure);
        expect(cubit.state.error, isA<OfflineException>());
        expect(cubit.state.canSubmit, isTrue);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.parcelRefusalFailed,
            properties: any(named: 'properties'),
          ),
        ).called(1);
      },
    );
  });
}
