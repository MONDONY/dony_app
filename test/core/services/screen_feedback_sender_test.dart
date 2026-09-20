import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/services/screen_feedback_sender.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements IncidentReportRepository {}

void main() {
  late _MockRepository repository;
  late Directory tempDir;
  late ScreenFeedbackSender sender;

  setUpAll(() {
    registerFallbackValue(IncidentTargetType.app);
  });

  setUp(() async {
    repository = _MockRepository();
    tempDir = await Directory.systemTemp.createTemp('dony_feedback_test');
    sender = ScreenFeedbackSender(
      repository,
      tempDirectory: () async => tempDir,
    );
    when(() => repository.uploadPhoto(any())).thenAnswer(
      (inv) async =>
          'reports/u/${(inv.positionalArguments.first as String).split('/').last}',
    );
    when(
      () => repository.submit(
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        screenRoute: any(named: 'screenRoute'),
      ),
    ).thenAnswer((_) async => 'r-1');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'uploade la capture automatique puis les captures, crée SCREEN_BUG avec la route',
    () async {
      final screenshot = Uint8List.fromList([137, 80, 78, 71, 0, 1, 2, 3]);

      final id = await sender.send(
        report: const FeedbackReport(
          message: 'Le badge passe sous le bouton',
          attachments: ['/tmp/a.jpg', '/tmp/b.jpg'],
          route: '/profile',
        ),
        route: '/profile',
        screenshot: screenshot,
      );

      expect(id, 'r-1');
      final uploaded = verify(
        () => repository.uploadPhoto(captureAny()),
      ).captured.cast<String>();
      expect(uploaded, hasLength(3));
      // La capture automatique part en premier, en PNG, depuis le dossier temporaire.
      expect(uploaded.first, startsWith(tempDir.path));
      expect(uploaded.first, endsWith('.png'));
      expect(uploaded.sublist(1), ['/tmp/a.jpg', '/tmp/b.jpg']);
      // Le fichier temporaire est nettoyé après l'upload.
      expect(File(uploaded.first).existsSync(), isFalse);

      verify(
        () => repository.submit(
          targetType: IncidentTargetType.app,
          reason: ScreenFeedbackSender.reason,
          description: 'Le badge passe sous le bouton',
          photoKeys: any(named: 'photoKeys', that: hasLength(3)),
          screenRoute: '/profile',
        ),
      ).called(1);
    },
  );

  test(
    'sans capture automatique ni pièce jointe, le rapport part quand même',
    () async {
      await sender.send(
        report: const FeedbackReport(message: 'x'),
        route: '/home',
      );
      verifyNever(() => repository.uploadPhoto(any()));
      verify(
        () => repository.submit(
          targetType: IncidentTargetType.app,
          reason: ScreenFeedbackSender.reason,
          description: 'x',
          screenRoute: '/home',
        ),
      ).called(1);
    },
  );

  test('une route inconnue est envoyée vide', () async {
    await sender.send(
      report: const FeedbackReport(message: 'x'),
      route: ScreenFeedbackSender.unknownRoute,
    );
    verify(
      () => repository.submit(
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        screenRoute: any(named: 'screenRoute', that: isNull),
      ),
    ).called(1);
  });

  test(
    'une capture qui ne s\'uploade pas est ignorée, les autres partent',
    () async {
      when(
        () => repository.uploadPhoto('/tmp/bad.jpg'),
      ).thenThrow(Exception('413'));

      await sender.send(
        report: const FeedbackReport(
          message: 'x',
          attachments: ['/tmp/bad.jpg', '/tmp/ok.jpg'],
        ),
        route: '/home',
      );

      final submit = verify(
        () => repository.submit(
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          description: any(named: 'description'),
          photoKeys: captureAny(named: 'photoKeys'),
          screenRoute: any(named: 'screenRoute'),
        ),
      ).captured;
      expect(submit.single, ['reports/u/ok.jpg']);
    },
  );

  test(
    'un backend qui refuse le signalement fait lever, à l\'appelant de décider',
    () async {
      when(
        () => repository.submit(
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
          screenRoute: any(named: 'screenRoute'),
        ),
      ).thenThrow(Exception('422 reason-not-applicable'));

      expect(
        () => sender.send(
          report: const FeedbackReport(message: 'x'),
          route: '/home',
        ),
        throwsException,
      );
    },
  );
}
