import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
    Future<Uint8List> Function(Uint8List png)? jpegEncoder,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _jpegEncoder = jpegEncoder ?? _encodeJpeg;

  final IncidentReportRepository _repository;
  final Future<Directory> Function() _tempDirectory;
  final Future<Uint8List> Function(Uint8List png) _jpegEncoder;

  static Future<Uint8List> _encodeJpeg(Uint8List png) =>
      FlutterImageCompress.compressWithList(
        png,
        quality: 80,
        // ignore: avoid_redundant_argument_values
        format: CompressFormat.jpeg,
      );

  /// Motif backend des rapports du scarabée (miroir de `ReportReason`).
  static const String reason = 'SCREEN_BUG';

  /// Route transmise quand le bouton n'a pas pu la lire.
  static const String unknownRoute = 'unknown';

  /// Uploade la capture automatique ([screenshot], PNG, convertie en JPEG 80) puis les captures
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
        // Conversion JPEG ; en cas d'échec, le PNG part tel quel (le back
        // l'accepte et le convertit).
        var bytes = screenshot;
        var ext = 'png';
        try {
          final jpeg = await _jpegEncoder(screenshot);
          if (jpeg.isNotEmpty) {
            bytes = jpeg;
            ext = 'jpg';
          }
        } catch (e) {
          AppLog.warn('Conversion JPEG de la capture impossible : $e');
        }
        file = File(
          '${dir.path}/dony_screen_feedback_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await file.writeAsBytes(bytes, flush: true);
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
      // Préfixe `[BUG]` / `[AVIS]` / `[SUGGESTION]` : le motif backend reste
      // `SCREEN_BUG` (contrat figé), le type se lit et se filtre dans le texte.
      description: '[${report.kind.tag}] ${report.message}',
      photoKeys: keys,
      screenRoute: route == unknownRoute ? null : route,
    );
  }
}
