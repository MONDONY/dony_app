import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photo_upload.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

final _now = DateTime(2026, 10, 13);

PackageRequestFormState _full() => PackageRequestFormState(
  currentStep: 2,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 11, 2),
  dateToleranceDays: 3,
  transportMode: TransportMode.plane,
  weightKg: 4.5,
  parcelSize: ParcelSize.medium,
  categories: const ['Vêtements', 'Bijoux faits main'],
  description: 'Deux paquets',
  pickupNeighborhood: 'Belleville',
  deliveryNeighborhood: 'Plateau',
  negotiable: false,
  acceptedPaymentMethods: const {PaymentMethod.cash, PaymentMethod.stripe},
  totalBudgetEur: 60,
  targetPriceEur: 60,
  promoCode: 'BIENVENUE',
  currency: SupportedCurrency.eur,
);

void main() {
  group('PackageRequestFormDraft', () {
    test('aller-retour : la saisie revient à l\'identique', () {
      final json = PackageRequestFormDraft.encode(_full());
      final back = PackageRequestFormDraft.decode(json, now: _now);

      expect(back.currentStep, 2);
      expect(back.departureCity, 'Paris');
      expect(back.arrivalCity, 'Dakar');
      expect(back.desiredDate, DateTime(2026, 11, 2));
      expect(back.dateToleranceDays, 3);
      expect(back.transportMode, TransportMode.plane);
      expect(back.weightKg, 4.5);
      expect(back.parcelSize, ParcelSize.medium);
      expect(back.categories, ['Vêtements', 'Bijoux faits main']);
      expect(back.description, 'Deux paquets');
      expect(back.pickupNeighborhood, 'Belleville');
      expect(back.deliveryNeighborhood, 'Plateau');
      expect(back.negotiable, isFalse);
      expect(back.acceptedPaymentMethods, {
        PaymentMethod.cash,
        PaymentMethod.stripe,
      });
      expect(back.totalBudgetEur, 60);
      expect(back.targetPriceEur, 60);
      expect(back.promoCode, 'BIENVENUE');
      expect(back.currency, SupportedCurrency.eur);
    });

    test('la saisie de l\'étape en cours prime sur l\'état du bloc', () {
      final json = PackageRequestFormDraft.encode(
        const PackageRequestFormState(departureCity: 'Lyon'),
        stepInput: {'departureCity': null, 'arrivalCity': 'Abidjan'},
      );
      final back = PackageRequestFormDraft.decode(json, now: _now);

      expect(back.departureCity, isNull);
      expect(back.arrivalCity, 'Abidjan');
    });

    test('formulaire vide : valeurs par défaut', () {
      final back = PackageRequestFormDraft.decode(
        PackageRequestFormDraft.encode(const PackageRequestFormState()),
        now: _now,
      );
      expect(back.currentStep, 0);
      expect(back.desiredDate, isNull);
      expect(back.negotiable, isTrue);
      expect(back.acceptedPaymentMethods, {PaymentMethod.stripe});
      expect(back.parcelSize, isNull);
      expect(back.transportMode, isNull);
    });

    test('date passée : retirée, retour à la première étape', () {
      final json = PackageRequestFormDraft.encode(_full());
      final back = PackageRequestFormDraft.decode(
        json,
        now: DateTime(2026, 12),
      );
      expect(back.desiredDate, isNull);
      expect(back.currentStep, 0);
    });

    test('lecture tolérante des valeurs inconnues', () {
      final back = PackageRequestFormDraft.decode({
        'step': 9,
        'parcelSize': 'XXL',
        'acceptedPaymentMethods': ['CHEQUE', 1],
        'categories': ['A', 3],
        'desiredDate': 42,
      }, now: _now);
      expect(back.currentStep, 2);
      expect(back.parcelSize, isNull);
      expect(back.acceptedPaymentMethods, {PaymentMethod.stripe});
      expect(back.categories, ['A']);
      expect(back.desiredDate, isNull);
    });

    test('photos : seules les photos envoyées et locales sont gardées', () {
      final json = PackageRequestFormDraft.encode(
        const PackageRequestFormState(),
        photos: const [
          PackageRequestPhotoUpload(
            localId: '1',
            localPath: '/tmp/a.jpg',
            status: PackageRequestPhotoUploadStatus.ready,
            remoteKey: 'k/a',
          ),
          PackageRequestPhotoUpload(localId: '2', localPath: '/tmp/b.jpg'),
          PackageRequestPhotoUpload(
            localId: '3',
            localPath: '',
            status: PackageRequestPhotoUploadStatus.ready,
            remoteKey: 'k/c',
            remoteUrl: 'https://x',
          ),
        ],
      );
      expect(PackageRequestFormDraft.decodePhotos(json), [
        (key: 'k/a', localPath: '/tmp/a.jpg'),
      ]);
      expect(
        PackageRequestFormDraft.decodePhotos({
          'photos': [
            'x',
            {'key': 'k', 'localPath': ''},
          ],
        }),
        isEmpty,
      );
    });

    test('encodeDate / decodeDate : jour seul', () {
      expect(
        PackageRequestFormDraft.encodeDate(DateTime(2026, 3, 4, 23, 59)),
        '2026-03-04',
      );
      expect(PackageRequestFormDraft.encodeDate(null), isNull);
      expect(
        PackageRequestFormDraft.decodeDate('2026-03-04'),
        DateTime(2026, 3, 4),
      );
      expect(PackageRequestFormDraft.decodeDate('n/a'), isNull);
    });
  });

  test(
    'FormDraftRestored remplace la saisie et incrémente draftRevision',
    () async {
      final bloc = PackageRequestFormBloc(
        _MockRepo(),
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      bloc.add(FormDraftRestored(_full()));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.departureCity, 'Paris');
      expect(bloc.state.currentStep, 2);
      expect(bloc.state.draftRevision, 1);
      expect(FormDraftRestored(_full()).props, [_full()]);
      await bloc.close();
    },
  );

  group('PackageRequestPhotosCubit.restoreDraft', () {
    late PackageRequestPhotosCubit cubit;

    setUp(() {
      cubit = PackageRequestPhotosCubit(
        _MockRepo(),
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );
    });

    tearDown(() => cubit.close());

    test('photos dont le fichier existe, prêtes avec leur clé', () {
      cubit.restoreDraft(const [
        (key: 'k/a', localPath: '/a.jpg'),
        (key: 'k/b', localPath: '/disparu.jpg'),
      ], fileExists: (p) => p == '/a.jpg');
      expect(cubit.readyKeys, ['k/a']);
      expect(cubit.state.single.localPath, '/a.jpg');
    });

    test('aucune photo encore présente : rien n\'est émis', () {
      cubit.restoreDraft(const [(key: 'k', localPath: '/nulle/part.jpg')]);
      expect(cubit.state, isEmpty);
    });

    test('no-op si des photos sont déjà là', () {
      cubit.seed(const [(key: 'k/x', url: 'https://x')]);
      cubit.restoreDraft(const [
        (key: 'k/a', localPath: '/a.jpg'),
      ], fileExists: (_) => true);
      expect(cubit.readyKeys, ['k/x']);
    });
  });
}
