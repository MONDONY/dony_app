import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/trip_mobile_money_networks_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AnnouncementRepository {}

const _orangeCi = MobileMoneyNetwork(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
);
const _mtnCi = MobileMoneyNetwork(
  code: 'MTN_MOMO_CIV',
  label: 'MTN MoMo',
  brand: 'MTN',
  country: 'CI',
);

AnnouncementModel _trip({
  Set<BidPaymentMethod> methods = const {
    BidPaymentMethod.mobileMoney,
    BidPaymentMethod.stripe,
  },
  List<MobileMoneyNetwork> networks = const [],
}) {
  final now = DateTime(2026, 10, 20);
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: DateTime(2026, 11, 15),
    availableKg: 12,
    totalKg: 20,
    status: 'ACTIVE',
    currency: 'XOF',
    acceptedPaymentMethods: methods,
    acceptedMobileMoneyNetworks: networks,
    createdAt: now,
    updatedAt: now,
  );
}

/// Réseaux mobile money d'un trajet ouvert depuis la recherche ou l'accueil :
/// relus au détail du trajet quand la liste reçue est vide.
void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  TripMobileMoneyNetworksCubit build() =>
      TripMobileMoneyNetworksCubit(repository);

  test('état initial : aucun réseau connu', () {
    expect(build().state, isEmpty);
  });

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'liste vide, mobile money accepté : relit le détail et sert ses réseaux',
    build: () {
      when(
        () => repository.getAnnouncementDetail('a1'),
      ).thenAnswer((_) async => _trip(networks: const [_orangeCi, _mtnCi]));
      return build();
    },
    act: (c) => c.load(_trip()),
    expect: () => [
      const [_orangeCi, _mtnCi],
    ],
    verify: (_) {
      verify(() => repository.getAnnouncementDetail('a1')).called(1);
    },
  );

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'liste déjà reçue : servie telle quelle, aucun appel',
    build: build,
    act: (c) => c.load(_trip(networks: const [_orangeCi])),
    expect: () => [
      const [_orangeCi],
    ],
    verify: (_) {
      verifyNever(() => repository.getAnnouncementDetail(any()));
    },
  );

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'mobile money non accepté : aucun appel, rien d\'émis',
    build: build,
    act: (c) => c.load(_trip(methods: const {BidPaymentMethod.stripe})),
    expect: () => <List<MobileMoneyNetwork>>[],
    verify: (_) {
      verifyNever(() => repository.getAnnouncementDetail(any()));
    },
  );

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'trajet introuvable (404) : rien d\'émis, sans erreur',
    build: () {
      when(
        () => repository.getAnnouncementDetail('a1'),
      ).thenThrow(const NotFoundException());
      return build();
    },
    act: (c) => c.load(_trip()),
    expect: () => <List<MobileMoneyNetwork>>[],
  );

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'échec réseau : rien d\'émis, sans erreur',
    build: () {
      when(
        () => repository.getAnnouncementDetail('a1'),
      ).thenThrow(const NetworkException('offline'));
      return build();
    },
    act: (c) => c.load(_trip()),
    expect: () => <List<MobileMoneyNetwork>>[],
  );

  blocTest<TripMobileMoneyNetworksCubit, List<MobileMoneyNetwork>>(
    'détail sans réseau (back ancien) : rien d\'émis',
    build: () {
      when(
        () => repository.getAnnouncementDetail('a1'),
      ).thenAnswer((_) async => _trip());
      return build();
    },
    act: (c) => c.load(_trip()),
    expect: () => <List<MobileMoneyNetwork>>[],
  );

  test('fermé pendant la lecture : aucun emit après close', () async {
    when(
      () => repository.getAnnouncementDetail('a1'),
    ).thenAnswer((_) async => _trip(networks: const [_orangeCi]));
    final cubit = build();

    final loading = cubit.load(_trip());
    await cubit.close();
    await loading;

    expect(cubit.state, isEmpty);
  });
}
