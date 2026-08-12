import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

class MockHiveService extends Mock implements HiveService {}

class _FakeBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key] = value;
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store[key] ?? defaultValue;
}

const kTestPickupAddress = AddressData(
  label: 'CDG Terminal 2',
  lat: 49.0097,
  lng: 2.5479,
);
const kTestDeliveryAddress = AddressData(
  label: 'Aéroport LSS',
  lat: 14.7397,
  lng: -17.4902,
);

AnnouncementModel buildAnnouncement({String id = 'ann-001'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-001',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now().add(const Duration(days: 10)),
      availableKg: 20.0,
      totalKg: 20.0,
      pricePerKg: 5.0,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  late MockAnnouncementRepository mockRepo;
  late MockHiveService mockHive;
  late _FakeBox userPrefsBox;

  setUpAll(() {
    registerFallbackValue(kTestPickupAddress);
    registerFallbackValue(TransportMode.other);
  });

  setUp(() {
    mockRepo = MockAnnouncementRepository();
    mockHive = MockHiveService();
    userPrefsBox = _FakeBox();
    when(() => mockHive.userPrefs).thenReturn(userPrefsBox);
  });

  AnnouncementBloc buildBloc() {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    analytics.onConfigured();
    return AnnouncementBloc(mockRepo, mockHive, analytics);
  }

  // ─── État initial ────────────────────────────────────────────────────────────

  group('État initial', () {
    test('état initial est AnnouncementInitial', () {
      expect(buildBloc().state, isA<AnnouncementInitial>());
    });
  });

  // ─── AnnouncementCreateRequested ─────────────────────────────────────────────

  group('AnnouncementCreateRequested', () {
    final ann = buildAnnouncement();

    blocTest<AnnouncementBloc, AnnouncementState>(
      'création réussie → [Loading, AnnouncementCreated]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async => ann);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) => s is AnnouncementCreated && s.announcement.id == 'ann-001',
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur création → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );

    // RÉGRESSION : en prod, le datasource laisse remonter un DioException brut
    // (dont .error porte la ForbiddenException posée par l'interceptor), PAS une
    // ForbiddenException nue. L'ancien `on ForbiddenException catch` ne matchait
    // donc jamais → l'invite « Passer en PRO » était du code mort et l'utilisateur
    // ne voyait qu'un vague « Action non autorisée ». Ce test reproduit le wrapping
    // réel et garantit que le quota mensuel route bien vers AnnouncementProLimitReached.
    blocTest<AnnouncementBloc, AnnouncementState>(
      'DioException(pro-limit-reached) → [Loading, AnnouncementProLimitReached]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements'),
            error: ForbiddenException(
              'Vous avez atteint votre limite de 2 annonces ce mois-ci. '
                  'Passez en PRO pour continuer.',
              'pro-limit-reached',
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementProLimitReached &&
              s.message.contains('limite de 2 annonces'),
        ),
      ],
    );

    // Le cas « ForbiddenException nue » doit lui aussi router vers la limite PRO
    // (unwrapDioError est idempotent sur une AppException déjà déballée).
    blocTest<AnnouncementBloc, AnnouncementState>(
      'ForbiddenException nue pro-limit-reached → [Loading, AnnouncementProLimitReached]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(
          ForbiddenException(
            'Vous avez atteint votre quota mensuel',
            'pro-limit-reached',
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementProLimitReached &&
              s.message.contains('quota mensuel'),
        ),
      ],
    );

    // RÉGRESSION : 3 « Publier » en rafale (avant que le bouton ne se désactive)
    // ne doivent déclencher qu'UN seul POST /announcements. La garde
    // `if (state is AnnouncementLoading) return;` ignore les events empilés.
    blocTest<AnnouncementBloc, AnnouncementState>(
      'triple AnnouncementCreateRequested en rafale → 1 seul createAnnouncement',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async {
          // Délai → le 1er event reste en AnnouncementLoading le temps que les
          // 2 suivants soient dépilés et rejetés par la garde.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return ann;
        });
        return buildBloc();
      },
      act: (bloc) {
        final event = AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        );
        bloc.add(event);
        bloc.add(event);
        bloc.add(event);
      },
      // Laisse le 1er event finir son Future.delayed(50ms) → AnnouncementCreated.
      wait: const Duration(milliseconds: 100),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementCreated>()],
      verify: (_) {
        verify(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).called(1);
      },
    );

    // VERROU : la création DIRECTE (saveAsDraft: false, comportement par défaut)
    // doit écrire le flag Hive "premier pas voyageur" — seul le cas brouillon
    // (testé plus bas, group « brouillon ») en est dispensé. Sans ce test, une
    // inversion de la condition `!event.saveAsDraft` (announcement_bloc.dart:66)
    // passerait inaperçue : le test brouillon vérifie `isNull`, mais aucun test
    // n'affirmait le `isTrue` symétrique côté publication directe.
    blocTest<AnnouncementBloc, AnnouncementState>(
      'création directe (sans saveAsDraft) écrit kHasPublishedAsTraveler',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async => ann);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementCreated>()],
      verify: (_) {
        expect(userPrefsBox.get(HiveService.kHasPublishedAsTraveler), isTrue);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'ForbiddenException autre code → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(ForbiddenException('Accès refusé', 'account-banned'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── AnnouncementCreateRequested(saveAsDraft: true) ──────────────────────────

  group('AnnouncementCreateRequested — brouillon', () {
    final ann = buildAnnouncement();

    blocTest<AnnouncementBloc, AnnouncementState>(
      'création en brouillon propage saveAsDraft et n\'écrit pas kHasPublishedAsTraveler',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
            saveAsDraft: any(named: 'saveAsDraft'),
          ),
        ).thenAnswer((_) async => ann);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
          saveAsDraft: true,
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementCreated>()],
      verify: (_) {
        final captured = verify(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
            saveAsDraft: captureAny(named: 'saveAsDraft'),
          ),
        ).captured;
        expect(captured.single, isTrue);
        expect(userPrefsBox.get(HiveService.kHasPublishedAsTraveler), isNull);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'draft-limit-reached émet AnnouncementDraftLimitReached',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
            saveAsDraft: any(named: 'saveAsDraft'),
          ),
        ).thenThrow(
          ForbiddenException(
            'Limite de brouillons atteinte',
            'draft-limit-reached',
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
          saveAsDraft: true,
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementDraftLimitReached>(),
      ],
    );

    // RÉGRESSION (mirroir du cas pro-limit-reached ci-dessus, cf. l.162-167) : en
    // prod, le datasource laisse remonter un DioException brut dont .error porte
    // la ForbiddenException posée par l'interceptor — PAS une ForbiddenException
    // nue. Ce test reproduit le wrapping réel pour draft-limit-reached.
    blocTest<AnnouncementBloc, AnnouncementState>(
      'DioException(draft-limit-reached) → [Loading, AnnouncementDraftLimitReached]',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
            saveAsDraft: any(named: 'saveAsDraft'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements'),
            error: ForbiddenException(
              'Limite de brouillons atteinte',
              'draft-limit-reached',
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
          saveAsDraft: true,
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementDraftLimitReached &&
              s.message.contains('Limite de brouillons'),
        ),
      ],
    );
  });

  // ─── AnnouncementPublishRequested ─────────────────────────────────────────────

  group('AnnouncementPublishRequested', () {
    final ann = buildAnnouncement();

    blocTest<AnnouncementBloc, AnnouncementState>(
      'publication réussie → [Loading, AnnouncementPublished] + kHasPublishedAsTraveler',
      build: () {
        when(
          () => mockRepo.publishAnnouncement('a1'),
        ).thenAnswer((_) async => ann);
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementPublished>()],
      verify: (_) {
        expect(userPrefsBox.get(HiveService.kHasPublishedAsTraveler), isTrue);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'publish kyc-not-verified émet AnnouncementKycRequired',
      build: () {
        when(
          () => mockRepo.publishAnnouncement('a1'),
        ).thenThrow(ForbiddenException('KYC requis', 'kyc-not-verified'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementKycRequired>(),
      ],
    );

    // RÉGRESSION (mirroir du cas pro-limit-reached de la création, cf. l.162-167) :
    // en prod, le datasource laisse remonter un DioException brut dont .error
    // porte la ForbiddenException posée par l'interceptor — PAS une
    // ForbiddenException nue. Ce test reproduit le wrapping réel pour
    // kyc-not-verified sur la publication.
    blocTest<AnnouncementBloc, AnnouncementState>(
      'DioException(kyc-not-verified) → [Loading, AnnouncementKycRequired]',
      build: () {
        when(() => mockRepo.publishAnnouncement('a1')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements/a1/publish'),
            error: ForbiddenException('KYC requis', 'kyc-not-verified'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementKycRequired && s.message.contains('KYC requis'),
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'publish departure-date-passed émet AnnouncementDepartureDatePassed',
      build: () {
        when(() => mockRepo.publishAnnouncement('a1')).thenThrow(
          const ValidationException(
            'Date passée',
            code: 'departure-date-passed',
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementDepartureDatePassed>(),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'publish pro-limit-reached émet AnnouncementProLimitReached',
      build: () {
        when(
          () => mockRepo.publishAnnouncement('a1'),
        ).thenThrow(ForbiddenException('Limite', 'pro-limit-reached'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementProLimitReached>(),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur générique publish → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.publishAnnouncement('a1'),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementPublishRequested('a1')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  group('AnnouncementUnpublishRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'dépublication réussie → [Loading, AnnouncementUpdated]',
      build: () {
        when(
          () => mockRepo.unpublishAnnouncement('a1'),
        ).thenAnswer((_) async => buildAnnouncement());
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementUnpublishRequested('a1')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementUpdated>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur dépublication → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.unpublishAnnouncement('a1'),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementUnpublishRequested('a1')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── AnnouncementListRequested ────────────────────────────────────────────────

  group('AnnouncementListRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'liste chargée → [Loading, AnnouncementListLoaded]',
      build: () {
        final ann = buildAnnouncement();
        when(
          () => mockRepo.getMyAnnouncements(),
        ).thenAnswer((_) async => (announcements: [ann], totalElements: 1));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementListRequested()),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementListLoaded &&
              s.announcements.length == 1 &&
              s.totalElements == 1,
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'liste vide → [Loading, AnnouncementListLoaded avec liste vide]',
      build: () {
        when(() => mockRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementListRequested()),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) => s is AnnouncementListLoaded && s.announcements.isEmpty,
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur liste → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.getMyAnnouncements(),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementListRequested()),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'ignore un nouveau dispatch tant qu\'un chargement est déjà en cours '
      '(anti-course : évite qu\'un appel concurrent en retard n\'écrase le '
      'résultat le plus récent — cf. AnnouncementCreateRequested)',
      build: () {
        when(() => mockRepo.getMyAnnouncements()).thenAnswer(
          (_) async => (announcements: <AnnouncementModel>[], totalElements: 0),
        );
        return buildBloc();
      },
      seed: () => AnnouncementLoading(),
      act: (bloc) => bloc.add(AnnouncementListRequested()),
      expect: () => [],
      verify: (_) {
        verifyNever(() => mockRepo.getMyAnnouncements());
      },
    );
  });

  // ─── AnnouncementDetailRequested ──────────────────────────────────────────────

  group('AnnouncementDetailRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'détail chargé → [Loading, AnnouncementDetailLoaded]',
      build: () {
        final ann = buildAnnouncement();
        when(
          () => mockRepo.getAnnouncementDetail('ann-001'),
        ).thenAnswer((_) async => ann);
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDetailRequested('ann-001')),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementDetailLoaded && s.announcement.id == 'ann-001',
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur détail → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.getAnnouncementDetail(any()),
        ).thenThrow(Exception('Not found'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDetailRequested('ann-999')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── AnnouncementSearchRequested ──────────────────────────────────────────────

  group('AnnouncementSearchRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'recherche avec résultats → [Loading, AnnouncementSearchLoaded]',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => [buildAnnouncement()]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementSearchRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) => s is AnnouncementSearchLoaded && s.results.length == 1,
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'recherche sans résultats → AnnouncementSearchLoaded.isEmpty = true',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementSearchRequested()),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) => s is AnnouncementSearchLoaded && s.isEmpty,
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur recherche → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementSearchRequested()),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'recherche relancée après Loaded → [Loaded(isReloading:true), Loaded]',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => [buildAnnouncement(id: 'new')]);
        return buildBloc();
      },
      seed: () => AnnouncementSearchLoaded([buildAnnouncement(id: 'old')]),
      act: (bloc) => bloc.add(
        AnnouncementSearchRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          sortBy: 'date',
        ),
      ),
      expect: () => [
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementSearchLoaded &&
              s.isReloading == true &&
              s.results.length == 1 &&
              s.results.first.id == 'old',
        ),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementSearchLoaded &&
              s.isReloading == false &&
              s.results.length == 1 &&
              s.results.first.id == 'new',
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur après Loaded → AnnouncementError avec previousResults',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenThrow(Exception('network down'));
        return buildBloc();
      },
      seed: () => AnnouncementSearchLoaded([buildAnnouncement(id: 'cached')]),
      act: (bloc) => bloc.add(
        AnnouncementSearchRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          sortBy: 'date',
        ),
      ),
      expect: () => [
        predicate<AnnouncementState>(
          (s) => s is AnnouncementSearchLoaded && s.isReloading == true,
        ),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementError &&
              s.previousResults != null &&
              s.previousResults!.length == 1 &&
              s.previousResults!.first.id == 'cached',
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'AnnouncementSearchRequested with radius → repo called with userLat/userLng/radiusKm',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => const []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementSearchRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          userLat: 48.8566,
          userLng: 2.3522,
          radiusKm: 25,
        ),
      ),
      verify: (_) {
        verify(
          () => mockRepo.searchAnnouncements(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: 48.8566,
            userLng: 2.3522,
            radiusKm: 25,
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).called(1);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'AnnouncementSearchRequested(urgent: true) → repo appelé avec urgent: true',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => const []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementSearchRequested(urgent: true)),
      verify: (_) {
        verify(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: true,
          ),
        ).called(1);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'AnnouncementSearchRequested sans urgent → repo appelé avec urgent: null (jamais false)',
      build: () {
        when(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: any(named: 'urgent'),
          ),
        ).thenAnswer((_) async => const []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementSearchRequested()),
      verify: (_) {
        verify(
          () => mockRepo.searchAnnouncements(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDateFrom: any(named: 'departureDateFrom'),
            departureDateTo: any(named: 'departureDateTo'),
            minAvailableKg: any(named: 'minAvailableKg'),
            userLat: any(named: 'userLat'),
            userLng: any(named: 'userLng'),
            radiusKm: any(named: 'radiusKm'),
            sortBy: any(named: 'sortBy'),
            sortDir: any(named: 'sortDir'),
            urgent: null,
          ),
        ).called(1);
      },
    );
  });

  // ─── AnnouncementDeleteRequested ──────────────────────────────────────────────

  group('AnnouncementDeleteRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'suppression réussie → [Loading, AnnouncementDeleted]',
      build: () {
        when(
          () => mockRepo.deleteAnnouncement('ann-001'),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDeleteRequested('ann-001')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementDeleted>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur suppression → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.deleteAnnouncement(any()),
        ).thenThrow(Exception('Forbidden'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDeleteRequested('ann-001')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── AnnouncementDetailRequested — 404 ───────────────────────────────────────

  group('AnnouncementDetailRequested — 404', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      '404 → [Loading, AnnouncementNotFound]',
      build: () {
        when(() => mockRepo.getAnnouncementDetail(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements/missing'),
            error: const NotFoundException(),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDetailRequested('missing')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementNotFound>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur réseau générique → [Loading, AnnouncementError] (pas NotFound)',
      build: () {
        when(() => mockRepo.getAnnouncementDetail(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements/ann-001'),
            type: DioExceptionType.connectionTimeout,
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(AnnouncementDetailRequested('ann-001')),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── AnnouncementSurplusOpenRequested ────────────────────────────────────────

  group('AnnouncementSurplusOpenRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'ouverture réussie → [Loading, AnnouncementSurplusOpened]',
      build: () {
        when(
          () => mockRepo.openSurplus(
            announcementId: any(named: 'announcementId'),
            surplusKg: any(named: 'surplusKg'),
            pricePerKg: any(named: 'pricePerKg'),
          ),
        ).thenAnswer((_) async => buildAnnouncement());
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementSurplusOpenRequested(
          announcementId: 'ann-001',
          surplusKg: 8.0,
          pricePerKg: 7.0,
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementSurplusOpened && s.announcement.id == 'ann-001',
        ),
      ],
      verify: (_) {
        verify(
          () => mockRepo.openSurplus(
            announcementId: 'ann-001',
            surplusKg: 8.0,
            pricePerKg: 7.0,
          ),
        ).called(1);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur ouverture → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.openSurplus(
            announcementId: any(named: 'announcementId'),
            surplusKg: any(named: 'surplusKg'),
            pricePerKg: any(named: 'pricePerKg'),
          ),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementSurplusOpenRequested(
          announcementId: 'ann-001',
          surplusKg: 8.0,
          pricePerKg: 7.0,
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'double ouverture en rafale → 1 seul openSurplus',
      build: () {
        when(
          () => mockRepo.openSurplus(
            announcementId: any(named: 'announcementId'),
            surplusKg: any(named: 'surplusKg'),
            pricePerKg: any(named: 'pricePerKg'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return buildAnnouncement();
        });
        return buildBloc();
      },
      act: (bloc) {
        final event = AnnouncementSurplusOpenRequested(
          announcementId: 'ann-001',
          surplusKg: 8.0,
          pricePerKg: 7.0,
        );
        bloc.add(event);
        bloc.add(event);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<AnnouncementLoading>(),
        isA<AnnouncementSurplusOpened>(),
      ],
      verify: (_) {
        verify(
          () => mockRepo.openSurplus(
            announcementId: any(named: 'announcementId'),
            surplusKg: any(named: 'surplusKg'),
            pricePerKg: any(named: 'pricePerKg'),
          ),
        ).called(1);
      },
    );
  });

  // ─── AnnouncementUpdateRequested ──────────────────────────────────────────────

  group('AnnouncementUpdateRequested', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'mise à jour réussie → [Loading, AnnouncementUpdated]',
      build: () {
        final updated = buildAnnouncement(id: 'ann-001');
        when(
          () => mockRepo.updateAnnouncement(
            id: any(named: 'id'),
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async => updated);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementUpdateRequested(
          id: 'ann-001',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          departureDate: DateTime.now().add(const Duration(days: 15)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 25.0,
          pricePerKg: 6.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementUpdated>()],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      '409 bids acceptés → [Loading, AnnouncementError avec message spécifique]',
      build: () {
        when(
          () => mockRepo.updateAnnouncement(
            id: any(named: 'id'),
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/announcements/ann-001'),
            response: Response(
              requestOptions: RequestOptions(path: '/announcements/ann-001'),
              statusCode: 409,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementUpdateRequested(
          id: 'ann-001',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          departureDate: DateTime.now().add(const Duration(days: 15)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 25.0,
          pricePerKg: 6.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [
        isA<AnnouncementLoading>(),
        predicate<AnnouncementState>(
          (s) =>
              s is AnnouncementError &&
              s.error.message.contains('Modification impossible'),
        ),
      ],
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'erreur générique mise à jour → [Loading, AnnouncementError]',
      build: () {
        when(
          () => mockRepo.updateAnnouncement(
            id: any(named: 'id'),
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenThrow(Exception('Server error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementUpdateRequested(
          id: 'ann-001',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          departureDate: DateTime.now().add(const Duration(days: 15)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 25.0,
          pricePerKg: 6.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      expect: () => [isA<AnnouncementLoading>(), isA<AnnouncementError>()],
    );
  });

  // ─── Handover window forwarding ──────────────────────────────────────────────

  group('Handover window forwarding', () {
    blocTest<AnnouncementBloc, AnnouncementState>(
      'createAnnouncement reçoit handoverWindowStart/End depuis l\'event',
      build: () {
        when(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async => buildAnnouncement());
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 10)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 20.0,
          pricePerKg: 5.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      verify: (_) {
        verify(
          () => mockRepo.createAnnouncement(
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: DateTime(2026, 6, 14, 16),
            handoverWindowEnd: DateTime(2026, 6, 14, 18),
          ),
        ).called(1);
      },
    );

    blocTest<AnnouncementBloc, AnnouncementState>(
      'updateAnnouncement reçoit handoverWindowStart/End depuis l\'event',
      build: () {
        when(
          () => mockRepo.updateAnnouncement(
            id: any(named: 'id'),
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: any(named: 'handoverWindowStart'),
            handoverWindowEnd: any(named: 'handoverWindowEnd'),
          ),
        ).thenAnswer((_) async => buildAnnouncement());
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        AnnouncementUpdateRequested(
          id: 'ann-001',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          departureDate: DateTime.now().add(const Duration(days: 15)),
          pickupAddress: kTestPickupAddress,
          deliveryAddress: kTestDeliveryAddress,
          availableKg: 25.0,
          pricePerKg: 6.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      ),
      verify: (_) {
        verify(
          () => mockRepo.updateAnnouncement(
            id: any(named: 'id'),
            departureCity: any(named: 'departureCity'),
            arrivalCity: any(named: 'arrivalCity'),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            availableKg: any(named: 'availableKg'),
            pricePerKg: any(named: 'pricePerKg'),
            transportMode: any(named: 'transportMode'),
            handoverWindowStart: DateTime(2026, 6, 14, 16),
            handoverWindowEnd: DateTime(2026, 6, 14, 18),
          ),
        ).called(1);
      },
    );
  });

  // ─── État Loaded reloading flag ──────────────────────────────────────────────

  group('AnnouncementSearchLoaded.isReloading', () {
    test('par défaut isReloading = false', () {
      final state = AnnouncementSearchLoaded([buildAnnouncement()]);
      expect(state.isReloading, isFalse);
    });

    test('peut être créé avec isReloading = true', () {
      final state = AnnouncementSearchLoaded([
        buildAnnouncement(),
      ], isReloading: true);
      expect(state.isReloading, isTrue);
      expect(state.results, hasLength(1));
    });
  });

  // ─── AnnouncementError carries previousResults ──────────────────────────────

  group('AnnouncementError.previousResults', () {
    test('par défaut previousResults = null', () {
      final state = AnnouncementError(NetworkException('boom'));
      expect(state.previousResults, isNull);
    });

    test('peut transporter les résultats précédents', () {
      final ann = buildAnnouncement();
      final state = AnnouncementError(
        NetworkException('boom'),
        previousResults: [ann],
      );
      expect(state.previousResults, hasLength(1));
      expect(state.previousResults!.first.id, ann.id);
    });
  });
}
