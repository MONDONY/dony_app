import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/likes/bloc/trip_likes_cubit.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/likes/data/repositories/trip_like_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TripLikeRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

AnnouncementModel _trip(
  String id, {
  int likeCount = 0,
  bool likedByMe = false,
}) => AnnouncementModel.fromJson({
  'id': id,
  'travelerId': 'tv1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime.now()
      .add(const Duration(days: 5))
      .toIso8601String(),
  'totalKg': 20.0,
  'availableKg': 15.0,
  'pricePerKg': 8.0,
  'pricingMode': 'KG',
  'status': 'ACTIVE',
  'pendingBidCount': 0,
  'confirmedParcelCount': 0,
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  'likeCount': likeCount,
  'likedByMe': likedByMe,
});

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late TripLikesCubit cubit;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = TripLikesCubit(repo, analytics);
  });

  tearDown(() => cubit.close());

  test('toggle_ajoute_un_et_passe_likedByMe', () async {
    final trip = _trip('t1', likeCount: 2);
    when(() => repo.like('t1')).thenAnswer(
      (_) async => const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
    final seen = <TripLikeStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.byTrip['t1']!));

    await cubit.toggle(trip);
    await sub.cancel();

    expect(seen.first, const TripLikeStatus(likeCount: 3, likedByMe: true));
    expect(
      cubit.statusOf(trip),
      const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
    verify(() => repo.like('t1')).called(1);
  });

  test('toggle_retire_un_et_ne_descend_jamais_sous_zero', () async {
    final trip = _trip('t1', likedByMe: true); // likeCount 0, incohérent
    when(() => repo.unlike('t1')).thenAnswer(
      (_) async => const TripLikeStatus(likeCount: 0, likedByMe: false),
    );
    final seen = <TripLikeStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.byTrip['t1']!));

    await cubit.toggle(trip);
    await sub.cancel();

    expect(seen.first, const TripLikeStatus(likeCount: 0, likedByMe: false));
    verify(() => repo.unlike('t1')).called(1);
  });

  test('toggle_retire_un_quand_deja_aime', () async {
    final trip = _trip('t1', likeCount: 5, likedByMe: true);
    when(() => repo.unlike('t1')).thenAnswer(
      (_) async => const TripLikeStatus(likeCount: 4, likedByMe: false),
    );
    final seen = <TripLikeStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.byTrip['t1']!));

    await cubit.toggle(trip);
    await sub.cancel();

    expect(seen.first, const TripLikeStatus(likeCount: 4, likedByMe: false));
  });

  test('toggle_pendant_un_appel_en_cours_est_ignore', () async {
    final trip = _trip('t1');
    final completer = Completer<TripLikeStatus>();
    when(() => repo.like('t1')).thenAnswer((_) => completer.future);

    final first = cubit.toggle(trip);
    await cubit.toggle(trip); // ignoré
    completer.complete(const TripLikeStatus(likeCount: 1, likedByMe: true));
    await first;

    verify(() => repo.like('t1')).called(1);
    verifyNever(() => repo.unlike(any()));
  });

  test('echec_reseau_remet_l_etat_d_avant_et_relance_l_erreur', () async {
    final trip = _trip('t1', likeCount: 2);
    when(() => repo.like('t1')).thenThrow(Exception('réseau'));

    await expectLater(cubit.toggle(trip), throwsException);

    expect(
      cubit.statusOf(trip),
      const TripLikeStatus(likeCount: 2, likedByMe: false),
    );
    // l'appel n'est plus en cours : un nouvel essai part
    when(() => repo.like('t1')).thenAnswer(
      (_) async => const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
    await cubit.toggle(trip);
    verify(() => repo.like('t1')).called(2);
  });

  test('seed_ne_remplace_pas_un_trajet_en_cours_d_appel', () async {
    final trip = _trip('t1', likeCount: 2);
    final completer = Completer<TripLikeStatus>();
    when(() => repo.like('t1')).thenAnswer((_) => completer.future);

    final pending = cubit.toggle(trip);
    cubit.seed([_trip('t1', likeCount: 2)]);

    expect(
      cubit.state.byTrip['t1'],
      const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
    completer.complete(const TripLikeStatus(likeCount: 3, likedByMe: true));
    await pending;
  });

  test('seed_ne_remplace_pas_un_trajet_deja_bascule', () async {
    final trip = _trip('t1', likeCount: 2);
    when(() => repo.like('t1')).thenAnswer(
      (_) async => const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
    await cubit.toggle(trip);

    // liste rechargée depuis le cache serveur (5 min) : valeurs d'avant
    cubit.seed([_trip('t1', likeCount: 2)]);

    expect(
      cubit.state.byTrip['t1'],
      const TripLikeStatus(likeCount: 3, likedByMe: true),
    );
  });

  test('seed_ne_remplace_pas_un_trajet_dont_le_toggle_a_echoue', () async {
    final trip = _trip('t1', likeCount: 2);
    when(() => repo.like('t1')).thenThrow(Exception('x'));
    await expectLater(cubit.toggle(trip), throwsException);

    cubit.seed([_trip('t1', likeCount: 9, likedByMe: true)]);

    expect(
      cubit.state.byTrip['t1'],
      const TripLikeStatus(likeCount: 2, likedByMe: false),
    );
  });

  test('seed_ajoute_les_inconnus_et_rafraichit_les_jamais_bascules', () {
    cubit.seed([_trip('a', likeCount: 1), _trip('b', likeCount: 2)]);
    expect(cubit.state.byTrip.length, 2);

    cubit.seed([_trip('a', likeCount: 7, likedByMe: true)]);
    expect(
      cubit.state.byTrip['a'],
      const TripLikeStatus(likeCount: 7, likedByMe: true),
    );
    expect(cubit.state.byTrip['b']!.likeCount, 2);
  });

  test('seed_sans_changement_n_emet_rien', () async {
    cubit.seed([_trip('a', likeCount: 1)]);
    final emitted = <TripLikesState>[];
    final sub = cubit.stream.listen(emitted.add);
    cubit.seed([_trip('a', likeCount: 1)]);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emitted, isEmpty);
  });

  test('statusOf_retombe_sur_le_modele', () {
    final trip = _trip('t1', likeCount: 6, likedByMe: true);
    expect(
      cubit.statusOf(trip),
      const TripLikeStatus(likeCount: 6, likedByMe: true),
    );
  });

  test('reset_vide_l_etat', () async {
    cubit.seed([_trip('a', likeCount: 1)]);
    cubit.reset();
    expect(cubit.state.byTrip, isEmpty);
  });

  test('reset_pendant_un_appel_ne_ressuscite_pas_l_ancien_compte', () async {
    final trip = _trip('t1');
    final completer = Completer<TripLikeStatus>();
    when(() => repo.like('t1')).thenAnswer((_) => completer.future);
    final pending = cubit.toggle(trip);
    cubit.reset();
    completer.complete(const TripLikeStatus(likeCount: 1, likedByMe: true));
    await pending;
    expect(cubit.state.byTrip, isEmpty);
  });

  group('analytics', () {
    test(
      'tripLiked_emis_une_fois_apres_succes_et_tripLikeFailed_avec_error_code_sinon',
      () async {
        final trip = _trip('t1');
        when(() => repo.like('t1')).thenAnswer(
          (_) async => const TripLikeStatus(likeCount: 1, likedByMe: true),
        );
        await cubit.toggle(trip);
        verify(() => analytics.logEvent(AnalyticsEvents.tripLiked)).called(1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.tripLikeFailed,
            properties: any(named: 'properties'),
          ),
        );

        when(
          () => repo.unlike('t1'),
        ).thenThrow(const NetworkException('nope', code: 'trip-like-own-trip'));
        await expectLater(cubit.toggle(trip), throwsA(isA<AppException>()));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.tripLikeFailed,
            properties: {'error_code': 'trip-like-own-trip'},
          ),
        ).called(1);
      },
    );

    test('erreur_sans_code_donne_unknown', () async {
      when(() => repo.like('t1')).thenThrow(Exception('x'));
      await expectLater(cubit.toggle(_trip('t1')), throwsException);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripLikeFailed,
          properties: {'error_code': 'unknown'},
        ),
      ).called(1);
    });

    test('tripUnliked_emis_apres_un_retrait_reussi', () async {
      when(() => repo.unlike('t1')).thenAnswer(
        (_) async => const TripLikeStatus(likeCount: 0, likedByMe: false),
      );
      await cubit.toggle(_trip('t1', likeCount: 1, likedByMe: true));
      verify(() => analytics.logEvent(AnalyticsEvents.tripUnliked)).called(1);
    });

    test('trackLoginPrompted_et_trackShareTapped', () {
      cubit
        ..trackLoginPrompted()
        ..trackShareTapped();
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripLikeLoginPrompted),
      ).called(1);
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripCardShareTapped),
      ).called(1);
    });

    test('noms des événements', () {
      expect(AnalyticsEvents.tripLiked, 'trip_liked');
      expect(AnalyticsEvents.tripUnliked, 'trip_unliked');
      expect(AnalyticsEvents.tripLikeFailed, 'trip_like_failed');
      expect(AnalyticsEvents.tripLikeLoginPrompted, 'trip_like_login_prompted');
      expect(AnalyticsEvents.tripCardShareTapped, 'trip_card_share_tapped');
    });
  });
}
