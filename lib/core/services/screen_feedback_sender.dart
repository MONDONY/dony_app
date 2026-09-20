import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:path_provider/path_provider.dart';

/// Envoie un rapport du scarabée au backend, par l'API de signalement déjà
/// utilisée par « Signaler un bug » : il apparaît ainsi dans l'admin, page
/// Signalements, avec le texte et les captures. Sentry reste alimenté en
/// parallèle par [DonyFeedbackButton] : ce service ne le remplace pas.
///
/// Motif `SCREEN_BUG` et route de l'écran (`screenRoute`) : contrat de
/// yadony-back #317. Un backend antérieur ignore `screenRoute` et refuse le
/// motif : l'appelant traite l'échec comme non bloquant.
class ScreenFeedbackSender {
  ScreenFeedbackSender(
    this._repository, {
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final IncidentReportRepository _repository;
  final Future<Directory> Function() _tempDirectory;

  /// Motif backend des rapports du scarabée (miroir de `ReportReason`).
  static const String reason = 'SCREEN_BUG';

  /// Route transmise quand le bouton n'a pas pu la lire.
  static const String unknownRoute = 'unknown';

  /// Uploade la capture automatique ([screenshot], PNG) puis les captures
  /// du testeur, et crée le signalement. Une capture qui ne s'uploade pas
  /// est ignorée : le rapport part avec les autres. Une création qui
  /// échoue lève, à l'appelant de décider.
  Future<String> send({
    required FeedbackReport report,
    required String route,
    Uint8List? screenshot,
  }) async {
    final keys = <String>[];

    if (screenshot != null) {
      File? file;
      try {
        final dir = await _tempDirectory();
        file = File(
          '${dir.path}/dony_screen_feedback_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(screenshot, flush: true);
        keys.add(await _repository.uploadPhoto(file.path));
      } catch (e) {
        AppLog.warn('Capture automatique non jointe au signalement : $e');
      } finally {
        try {
          await file?.delete();
        } catch (_) {}
      }
    }

    for (final path in report.attachments) {
      try {
        keys.add(await _repository.uploadPhoto(path));
      } catch (e) {
        AppLog.warn('Capture $path non jointe au signalement : $e');
      }
    }

    return _repository.submit(
      targetType: IncidentTargetType.app,
      reason: reason,
      description: report.message,
      photoKeys: keys,
      screenRoute: route == unknownRoute ? null : route,
    );
  }
}
