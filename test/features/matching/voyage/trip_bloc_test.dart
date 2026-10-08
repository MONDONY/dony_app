import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import 'trip_fixtures.dart';

class _MockRepo extends Mock implements AnnouncementRepository {}

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(<AnnouncementPayload>[]);
  });

  setUp(() => repo = _MockRepo());

  AnnouncementBloc build() {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    analytics.onConfigured();
    return AnnouncementBloc(repo, analytics);
  }

  group('buildTripPayloads', () {
    test("l'étape 2 part d'Abidjan et reprend le premier trajet", () {
      final payloads = buildTripPayloads(firstLeg(), [doualaLeg()]);
      expect(payloads, hasLength(2));
      final p1 = payloads[0];
      final p2 = payloads[1];
      expect(p1.departureCity, 'Paris');
      expect(p1.arrivalTime, '18:00');
      expect(p2.departureCity, 'Abidjan');
      expect(p2.departureCountryCode, 'CI');
      expect(p2.arrivalCity, 'Douala');
      expect(p2.arrivalCountryCode, 'CM');
      expect(p2.pickupAddress, kAbidjan);
      expect(p2.deliveryAddress, kDouala);
      // Kilos et prix propres à l'étape.
      expect(p2.availableKg, 12);
      expect(p2.pricePerKg, 6);
      // Le reste vient du premier trajet.
      expect(p2.transportMode, TransportMode.plane);
      expect(p2.acceptedContentTypes, ['CLOTHES']);
      expect(p2.refusedTypes, ['FOOD']);
      expect(p2.acceptedPaymentMethods, ['CASH']);
      expect(p2.capacityUnit, 'KG_EXACT');
      expect(p2.negotiable, isTrue);
      expect(p2.currency, 'EUR');
      expect(p2.description, 'Bagage soute');
      // Pas d'heure d'arrivée héritée : l'étape a la sienne (inconnue).
      expect(p2.arrivalTime, isNull);
      expect(p2.arrivalDate, isNull);
      // Même délai de dépôt que le premier trajet : 24 h avant le départ.
      expect(p2.handoverDeadline, DateTime(2026, 11, 13, 9, 30));
    });

    test("l'étape 3 part de l'arrivée de l'étape 2", () {
      final third = doualaLeg(date: DateTime(2026, 11, 20));
      final payloads = buildTripPayloads(firstLeg(), [
        doualaLeg(),
        TripLegDraftCopy.withCity(third, 'Lomé', 'TG'),
      ]);
      expect(payloads[2].departureCity, 'Douala');
      expect(payloads[2].departureCountryCode, 'CM');
      expect(payloads[2].pickupAddress, kDouala);
      expect(payloads[2].arrivalCity, 'Lomé');
    });

    test('grille seule : prix au kilo du premier trajet', () {
      final payloads = buildTripPayloads(firstLeg(pricingMode: 'MIXED'), [
        doualaLeg(price: null),
      ]);
      expect(payloads[1].pricePerKg, 8);
      expect(payloads[1].pricingMode, 'MIXED');
    });

    test('brouillon : toutes les étapes en brouillon', () {
      final payloads = buildTripPayloads(firstLeg(draft: true), [doualaLeg()]);
      expect(payloads.every((p) => p.saveAsDraft), isTrue);
    });

    test('date limite après le départ : délai ramené à zéro', () {
      final first = firstLeg();
      final late = AnnouncementCreateRequested(
        departureCity: first.departureCity,
        arrivalCity: first.arrivalCity,
        departureDate: first.departureDate,
        departureTime: first.departureTime,
        pickupAddress: first.pickupAddress,
        deliveryAddress: first.deliveryAddress,
        availableKg: 20,
        pricePerKg: 8,
        transportMode: TransportMode.plane,
        handoverDeadline: DateTime(2026, 11, 10, 12),
      );
      final payloads = buildTripPayloads(late, [doualaLeg()]);
      expect(payloads[1].handoverDeadline, DateTime(2026, 11, 14, 9, 30));
    });
  });

  group('AnnouncementTripCreateRequested', () {
    final legs = [
      legModel(id: 'a', from: 'Paris', to: 'Abidjan', group: 'g', index: 1),
      legModel(id: 'b', from: 'Abidjan', to: 'Douala', group: 'g', index: 2),
    ];

    blocTest<AnnouncementBloc, AnnouncementState>(
      'succès : AnnouncementTripCreated, qui est aussi un AnnouncementCreated',
      build: () {
        when(() => repo.createTrip(any())).thenAnswer((_) async => legs);
        return build();
      },
      act: (b) => b.add(
        AnnouncementTripCreateRequested(first: firstLeg(), legs: [doualaLeg()]),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementTripCreated>()
            .having((s) => s.legs, 'legs', legs)
            .having((s) => s.announcement.id, 'première étape', 'a'),
      ],
      verify: (_) {
        final sent =
            verify(() => repo.createTrip(captureAny())).captured.single
                as List<AnnouncementPayload>;
        expect(sent, hasLength(2));
        expect(sent[1].departureCity, 'Abidjan');
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'réponse vide : non pris en charge',
      build: () {
        when(() => repo.createTrip(any())).thenAnswer((_) async => []);
        return build();
      },
      act: (b) => b.add(
        AnnouncementTripCreateRequested(first: firstLeg(), legs: [doualaLeg()]),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementTripUnsupported>(),
      ],
    );

    for (final error in <AppException>[
      const NotFoundException(message: 'absent'),
      const NetworkException('Method Not Allowed', code: '405'),
    ]) {
      blocTest<AnnouncementBloc, AnnouncementState>(
        'ancien backend (${error.runtimeType}) : non pris en charge',
        build: () {
          when(() => repo.createTrip(any())).thenThrow(
            DioException(requestOptions: RequestOptions(), error: error),
          );
          return build();
        },
        act: (b) => b.add(
          AnnouncementTripCreateRequested(
            first: firstLeg(),
            legs: [doualaLeg()],
          ),
        ),
        expect: () => [
          isA<AnnouncementLoading>(),
          isA<AnnouncementTripUnsupported>(),
        ],
      );
    }

    blocTest<AnnouncementBloc, AnnouncementState>(
      'étape refusée (422) : erreur, rien de créé',
      build: () {
        when(() => repo.createTrip(any())).thenThrow(
          const ValidationException(
            'L\'étape 2 doit partir de Abidjan',
            code: 'trip-leg-city-mismatch',
          ),
        );
        return build();
      },
      act: (b) => b.add(
        AnnouncementTripCreateRequested(first: firstLeg(), legs: [doualaLeg()]),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementError>().having(
          (s) => s.error.code,
          'code',
          'trip-leg-city-mismatch',
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'quota de brouillons atteint',
      build: () {
        when(
          () => repo.createTrip(any()),
        ).thenThrow(const ForbiddenException('Limite', 'draft-limit-reached'));
        return build();
      },
      act: (b) => b.add(
        AnnouncementTripCreateRequested(
          first: firstLeg(draft: true),
          legs: [doualaLeg()],
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementDraftLimitReached>(),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'limite PRO atteinte',
      build: () {
        when(
          () => repo.createTrip(any()),
        ).thenThrow(const ForbiddenException('Limite', 'pro-limit-reached'));
        return build();
      },
      act: (b) => b.add(
        AnnouncementTripCreateRequested(first: firstLeg(), legs: [doualaLeg()]),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementProLimitReached>(),
      ],
    );
  });

  group('AnnouncementDeleteRequested avec étapes suivantes', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'annule les suivantes au mieux et compte les refus',
      build: () {
        when(() => repo.deleteAnnouncement('a')).thenAnswer((_) async {});
        when(() => repo.deleteAnnouncement('b')).thenAnswer((_) async {});
        when(
          () => repo.deleteAnnouncement('c'),
        ).thenThrow(Exception('colis accepté'));
        return build();
      },
      act: (b) =>
          b.add(AnnouncementDeleteRequested('a', followingLegIds: ['b', 'c'])),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementDeleted>().having((s) => s.followingFailed, 'refus', 1),
      ],
      verify: (_) {
        verify(() => repo.deleteAnnouncement('b')).called(1);
        verify(() => repo.deleteAnnouncement('c')).called(1);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'sans étape suivante : comportement historique',
      build: () {
        when(() => repo.deleteAnnouncement('a')).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(AnnouncementDeleteRequested('a')),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementDeleted>().having((s) => s.followingFailed, 'refus', 0),
      ],
    );
  });
}
