import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGpProRepository extends Mock implements GpProRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockGpProRepository repository;
  late MockAnalyticsService analytics;

  const none = GpProStatus(state: GpProState.none);
  const pending = GpProStatus(state: GpProState.pending);
  const rejected = GpProStatus(state: GpProState.rejected, reason: 'x');

  setUpAll(() {
    registerFallbackValue(GpProDocType.other);
    registerFallbackValue(GpProFrequency.weekly);
    registerFallbackValue(GpProSource.profile);
  });

  setUp(() {
    repository = MockGpProRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  GpProCubit build() => GpProCubit(repository, analytics);

  void stubStatus(GpProStatus s) =>
      when(() => repository.fetchStatus()).thenAnswer((_) async => s);

  GpProPiece piece(
    String localId, {
    GpProUploadStatus status = GpProUploadStatus.ready,
    String? remoteId,
    String? localPath = '/tmp/a.jpg',
    GpProDocType type = GpProDocType.travelProof,
  }) => GpProPiece(
    localId: localId,
    type: type,
    localPath: localPath,
    remoteId: remoteId,
    status: status,
  );

  group('état', () {
    test('canAddPiece, hasUploading, canSubmit', () {
      const s = GpProCubitState();
      expect(s.canAddPiece, isTrue);
      expect(s.canSubmit, isFalse);
      final full = s.copyWith(
        frequency: GpProFrequency.weekly,
        pieces: [piece('1'), piece('2'), piece('3'), piece('4')],
      );
      expect(full.canAddPiece, isFalse);
      expect(full.canSubmit, isTrue);
      final up = full.copyWith(
        pieces: [piece('1', status: GpProUploadStatus.uploading)],
      );
      expect(up.hasUploading, isTrue);
      expect(up.canSubmit, isFalse);
      expect(full.copyWith(submitting: true).canSubmit, isFalse);
    });
  });

  group('load', () {
    blocTest<GpProCubit, GpProCubitState>(
      'ready + event opened une seule fois même après 2 load',
      build: () {
        stubStatus(none);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.load();
      },
      expect: () => [
        const GpProCubitState(),
        const GpProCubitState(load: GpProLoadStatus.ready, status: none),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.gpProApplicationOpened,
            properties: {'status': 'NONE'},
          ),
        ).called(1);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      '404 back ancien : unavailable',
      build: () {
        when(
          () => repository.fetchStatus(),
        ).thenThrow(const GpProUnavailableException(status: 404));
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const GpProCubitState(),
        const GpProCubitState(load: GpProLoadStatus.unavailable),
      ],
    );

    blocTest<GpProCubit, GpProCubitState>(
      'autre erreur : failure',
      build: () {
        when(
          () => repository.fetchStatus(),
        ).thenThrow(const GpProException('network'));
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const GpProCubitState(),
        const GpProCubitState(load: GpProLoadStatus.failure),
      ],
    );

    blocTest<GpProCubit, GpProCubitState>(
      'documents présents : pièces construites, locales en cours conservées',
      build: () {
        stubStatus(
          const GpProStatus(
            state: GpProState.pending,
            documents: [
              GpProDocument(id: 'd1', type: GpProDocType.socialProfile),
            ],
          ),
        );
        return build();
      },
      seed: () => GpProCubitState(
        pieces: [piece('p0', status: GpProUploadStatus.uploading)],
      ),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.pieces, hasLength(2));
        expect(c.state.pieces.first.remoteId, 'd1');
        expect(c.state.pieces.first.localPath, isNull);
        expect(c.state.pieces.first.status, GpProUploadStatus.ready);
        expect(c.state.pieces.last.status, GpProUploadStatus.uploading);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'documents null : pièces locales inchangées',
      build: () {
        stubStatus(pending);
        return build();
      },
      seed: () => GpProCubitState(pieces: [piece('p0', remoteId: 'd9')]),
      act: (c) => c.load(),
      verify: (c) => expect(c.state.pieces, [piece('p0', remoteId: 'd9')]),
    );
  });

  group('selectFrequency / restart', () {
    blocTest<GpProCubit, GpProCubitState>(
      'selectFrequency',
      build: build,
      act: (c) => c.selectFrequency(GpProFrequency.monthly),
      expect: () => [const GpProCubitState(frequency: GpProFrequency.monthly)],
    );

    blocTest<GpProCubit, GpProCubitState>(
      'restart vide le formulaire et passe restarting',
      build: build,
      seed: () => GpProCubitState(
        load: GpProLoadStatus.ready,
        status: rejected,
        frequency: GpProFrequency.weekly,
        pieces: [piece('p0', remoteId: 'd1')],
        errorCode: 'boom',
      ),
      act: (c) => c.restart(),
      expect: () => [
        const GpProCubitState(
          load: GpProLoadStatus.ready,
          status: rejected,
          restarting: true,
        ),
      ],
    );
  });

  group('addPiece', () {
    blocTest<GpProCubit, GpProCubitState>(
      'sans demande ouverte : pas d\'attachDocuments, event ajouté',
      build: () {
        when(
          () => repository.uploadDocument(
            filePath: '/tmp/a.jpg',
            type: GpProDocType.travelProof,
          ),
        ).thenAnswer(
          (_) async =>
              const GpProDocument(id: 'd1', type: GpProDocType.travelProof),
        );
        return build();
      },
      seed: () =>
          const GpProCubitState(load: GpProLoadStatus.ready, status: none),
      act: (c) =>
          c.addPiece(filePath: '/tmp/a.jpg', type: GpProDocType.travelProof),
      verify: (c) {
        expect(c.state.pieces.single.status, GpProUploadStatus.ready);
        expect(c.state.pieces.single.remoteId, 'd1');
        verifyNever(() => repository.attachDocuments(any()));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.gpProDocumentAdded,
            properties: {'doc_type': 'TRAVEL_PROOF'},
          ),
        ).called(1);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'demande PENDING : attachDocuments et statut remplacé',
      build: () {
        when(
          () => repository.uploadDocument(
            filePath: '/tmp/a.jpg',
            type: GpProDocType.other,
          ),
        ).thenAnswer(
          (_) async => const GpProDocument(id: 'd1', type: GpProDocType.other),
        );
        when(() => repository.attachDocuments(['d1'])).thenAnswer(
          (_) async => const GpProStatus(
            state: GpProState.pending,
            documentCount: 1,
            documents: [GpProDocument(id: 'd1', type: GpProDocType.other)],
          ),
        );
        return build();
      },
      seed: () =>
          const GpProCubitState(load: GpProLoadStatus.ready, status: pending),
      act: (c) => c.addPiece(filePath: '/tmp/a.jpg', type: GpProDocType.other),
      verify: (c) {
        verify(() => repository.attachDocuments(['d1'])).called(1);
        expect(c.state.status!.documentCount, 1);
        final p = c.state.pieces.single;
        expect(p.localPath, '/tmp/a.jpg');
        expect(p.status, GpProUploadStatus.ready);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'échec upload : pièce failed + errorCode, pas d\'event',
      build: () {
        when(
          () => repository.uploadDocument(
            filePath: '/tmp/a.jpg',
            type: GpProDocType.other,
          ),
        ).thenThrow(
          const GpProException('gp-pro-document-storage-unavailable'),
        );
        return build();
      },
      act: (c) => c.addPiece(filePath: '/tmp/a.jpg', type: GpProDocType.other),
      verify: (c) {
        expect(c.state.pieces.single.status, GpProUploadStatus.failed);
        expect(c.state.errorCode, 'gp-pro-document-storage-unavailable');
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.gpProDocumentAdded,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'échec de rattachement : pièce failed',
      build: () {
        when(
          () => repository.uploadDocument(
            filePath: '/tmp/a.jpg',
            type: GpProDocType.other,
          ),
        ).thenAnswer(
          (_) async => const GpProDocument(id: 'd1', type: GpProDocType.other),
        );
        when(
          () => repository.attachDocuments(['d1']),
        ).thenThrow(const GpProException('network'));
        return build();
      },
      seed: () =>
          const GpProCubitState(load: GpProLoadStatus.ready, status: pending),
      act: (c) => c.addPiece(filePath: '/tmp/a.jpg', type: GpProDocType.other),
      verify: (c) {
        expect(c.state.pieces.single.status, GpProUploadStatus.failed);
        expect(c.state.errorCode, 'network');
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'erreur non typée : code unknown',
      build: () {
        when(
          () => repository.uploadDocument(
            filePath: any(named: 'filePath'),
            type: any(named: 'type'),
          ),
        ).thenThrow(StateError('x'));
        return build();
      },
      act: (c) => c.addPiece(filePath: '/tmp/a.jpg', type: GpProDocType.other),
      verify: (c) => expect(c.state.errorCode, 'unknown'),
    );

    blocTest<GpProCubit, GpProCubitState>(
      '5e pièce refusée sans appel',
      build: build,
      seed: () => GpProCubitState(
        pieces: [piece('1'), piece('2'), piece('3'), piece('4')],
      ),
      act: (c) => c.addPiece(filePath: '/tmp/e.jpg', type: GpProDocType.other),
      expect: () => <GpProCubitState>[],
      verify: (_) => verifyNever(
        () => repository.uploadDocument(
          filePath: any(named: 'filePath'),
          type: any(named: 'type'),
        ),
      ),
    );
  });

  group('removePiece', () {
    blocTest<GpProCubit, GpProCubitState>(
      'pièce failed : retirée sans appel réseau',
      build: build,
      seed: () => GpProCubitState(
        pieces: [piece('p0', status: GpProUploadStatus.failed)],
      ),
      act: (c) => c.removePiece('p0'),
      expect: () => [const GpProCubitState()],
      verify: (_) => verifyNever(() => repository.removeDocument(any())),
    );

    blocTest<GpProCubit, GpProCubitState>(
      'pièce distante : removeDocument, retirée, event',
      build: () {
        when(() => repository.removeDocument('d1')).thenAnswer((_) async {});
        return build();
      },
      seed: () => GpProCubitState(
        pieces: [piece('p0', remoteId: 'd1', type: GpProDocType.other)],
      ),
      act: (c) => c.removePiece('p0'),
      verify: (c) {
        expect(c.state.pieces, isEmpty);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.gpProDocumentRemoved,
            properties: {'doc_type': 'OTHER'},
          ),
        ).called(1);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      '503 : pièce gardée + errorCode',
      build: () {
        when(() => repository.removeDocument('d1')).thenThrow(
          const GpProException(
            'gp-pro-document-storage-unavailable',
            status: 503,
          ),
        );
        return build();
      },
      seed: () => GpProCubitState(pieces: [piece('p0', remoteId: 'd1')]),
      act: (c) => c.removePiece('p0'),
      verify: (c) {
        expect(c.state.pieces, hasLength(1));
        expect(c.state.errorCode, 'gp-pro-document-storage-unavailable');
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'erreur non typée : unknown, pièce gardée',
      build: () {
        when(() => repository.removeDocument('d1')).thenThrow(StateError('x'));
        return build();
      },
      seed: () => GpProCubitState(pieces: [piece('p0', remoteId: 'd1')]),
      act: (c) => c.removePiece('p0'),
      verify: (c) {
        expect(c.state.pieces, hasLength(1));
        expect(c.state.errorCode, 'unknown');
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'identifiant inconnu : rien',
      build: build,
      act: (c) => c.removePiece('nope'),
      expect: () => <GpProCubitState>[],
    );
  });

  group('submit', () {
    GpProCubitState ready({List<GpProPiece>? pieces}) => GpProCubitState(
      load: GpProLoadStatus.ready,
      status: none,
      frequency: GpProFrequency.twiceAMonth,
      pieces: pieces ?? [piece('p0', remoteId: 'd1')],
      restarting: true,
    );

    blocTest<GpProCubit, GpProCubitState>(
      'succès : analytics exacts, statut remplacé, restarting remis à faux',
      build: () {
        when(
          () => repository.apply(
            frequency: GpProFrequency.twiceAMonth,
            commercialName: 'Awa Express',
            documentIds: ['d1'],
            source: GpProSource.profile,
          ),
        ).thenAnswer((_) async => pending);
        return build();
      },
      seed: ready,
      act: (c) => c.submit(commercialName: '  Awa Express '),
      verify: (c) {
        expect(c.state.status, pending);
        expect(c.state.restarting, isFalse);
        expect(c.state.submitting, isFalse);
        expect(c.state.pieces, hasLength(1));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.gpProApplicationSubmitted,
            properties: {
              'source': 'profile',
              'frequency': 'TWICE_A_MONTH',
              'document_count': 1,
              'has_commercial_name': true,
            },
          ),
        ).called(1);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'nom blanc : has_commercial_name faux, nom non envoyé',
      build: () {
        when(
          () => repository.apply(
            frequency: GpProFrequency.twiceAMonth,
            documentIds: ['d1'],
            source: GpProSource.profile,
          ),
        ).thenAnswer((_) async => pending);
        return build();
      },
      seed: ready,
      act: (c) => c.submit(commercialName: '  '),
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: {
            'source': 'profile',
            'frequency': 'TWICE_A_MONTH',
            'document_count': 1,
            'has_commercial_name': false,
          },
        ),
      ).called(1),
    );

    blocTest<GpProCubit, GpProCubitState>(
      'seules les pièces ready comptent',
      build: () {
        when(
          () => repository.apply(
            frequency: GpProFrequency.twiceAMonth,
            documentIds: ['d1'],
            source: GpProSource.profile,
          ),
        ).thenAnswer((_) async => pending);
        return build();
      },
      seed: () => ready(
        pieces: [
          piece('p0', remoteId: 'd1'),
          piece('p1', status: GpProUploadStatus.failed),
        ],
      ),
      act: (c) => c.submit(),
      verify: (_) => verify(
        () => repository.apply(
          frequency: GpProFrequency.twiceAMonth,
          documentIds: ['d1'],
          source: GpProSource.profile,
        ),
      ).called(1),
    );

    blocTest<GpProCubit, GpProCubitState>(
      'pièce uploading : aucun appel',
      build: build,
      seed: () =>
          ready(pieces: [piece('p0', status: GpProUploadStatus.uploading)]),
      act: (c) => c.submit(),
      expect: () => <GpProCubitState>[],
      verify: (_) => verifyNever(
        () => repository.apply(
          frequency: any(named: 'frequency'),
          commercialName: any(named: 'commercialName'),
          documentIds: any(named: 'documentIds'),
          source: any(named: 'source'),
        ),
      ),
    );

    for (final code in ['gp-pro-application-open', 'gp-pro-already-active']) {
      blocTest<GpProCubit, GpProCubitState>(
        '409 $code : fetchStatus rappelé',
        build: () {
          when(
            () => repository.apply(
              frequency: any(named: 'frequency'),
              commercialName: any(named: 'commercialName'),
              documentIds: any(named: 'documentIds'),
              source: any(named: 'source'),
            ),
          ).thenThrow(GpProException(code, status: 409));
          stubStatus(pending);
          return build();
        },
        seed: ready,
        act: (c) => c.submit(),
        verify: (c) {
          verify(() => repository.fetchStatus()).called(1);
          expect(c.state.status, pending);
          expect(c.state.restarting, isFalse);
          expect(c.state.submitting, isFalse);
        },
      );
    }

    blocTest<GpProCubit, GpProCubitState>(
      'autre erreur : errorCode, formulaire gardé',
      build: () {
        when(
          () => repository.apply(
            frequency: any(named: 'frequency'),
            commercialName: any(named: 'commercialName'),
            documentIds: any(named: 'documentIds'),
            source: any(named: 'source'),
          ),
        ).thenThrow(const GpProException('network'));
        return build();
      },
      seed: ready,
      act: (c) => c.submit(),
      verify: (c) {
        expect(c.state.errorCode, 'network');
        expect(c.state.submitting, isFalse);
        expect(c.state.restarting, isTrue);
        expect(c.state.frequency, GpProFrequency.twiceAMonth);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'erreur non typée : unknown',
      build: () {
        when(
          () => repository.apply(
            frequency: any(named: 'frequency'),
            commercialName: any(named: 'commercialName'),
            documentIds: any(named: 'documentIds'),
            source: any(named: 'source'),
          ),
        ).thenThrow(StateError('x'));
        return build();
      },
      seed: ready,
      act: (c) => c.submit(),
      verify: (c) => expect(c.state.errorCode, 'unknown'),
    );
  });

  group('cancel', () {
    blocTest<GpProCubit, GpProCubitState>(
      'succès : event, pièces vidées, statut rechargé',
      build: () {
        when(() => repository.cancel()).thenAnswer((_) async {});
        stubStatus(none);
        return build();
      },
      seed: () => GpProCubitState(
        load: GpProLoadStatus.ready,
        status: pending,
        pieces: [piece('p0', remoteId: 'd1')],
      ),
      act: (c) => c.cancel(),
      verify: (c) {
        expect(c.state.pieces, isEmpty);
        expect(c.state.status, none);
        expect(c.state.cancelling, isFalse);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.gpProApplicationCancelled,
            properties: any(named: 'properties'),
          ),
        ).called(1);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      '404 : rechargement sans event',
      build: () {
        when(() => repository.cancel()).thenThrow(
          const GpProException('gp-pro-no-open-application', status: 404),
        );
        stubStatus(none);
        return build();
      },
      seed: () =>
          const GpProCubitState(load: GpProLoadStatus.ready, status: pending),
      act: (c) => c.cancel(),
      verify: (c) {
        verify(() => repository.fetchStatus()).called(1);
        expect(c.state.cancelling, isFalse);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.gpProApplicationCancelled,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'autre erreur : errorCode',
      build: () {
        when(
          () => repository.cancel(),
        ).thenThrow(const GpProException('network'));
        return build();
      },
      seed: () =>
          const GpProCubitState(load: GpProLoadStatus.ready, status: pending),
      act: (c) => c.cancel(),
      verify: (c) {
        expect(c.state.errorCode, 'network');
        expect(c.state.cancelling, isFalse);
        expect(c.state.status, pending);
      },
    );

    blocTest<GpProCubit, GpProCubitState>(
      'erreur non typée : unknown',
      build: () {
        when(() => repository.cancel()).thenThrow(StateError('x'));
        return build();
      },
      act: (c) => c.cancel(),
      verify: (c) => expect(c.state.errorCode, 'unknown'),
    );
  });
}
