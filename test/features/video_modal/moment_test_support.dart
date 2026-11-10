import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Service de moments qui retient ce qui est émis, sans écouteur ni stockage.
class RecordingMoments extends VideoModalMoments {
  RecordingMoments() : super(appVersion: () async => '1.0.0');

  final List<VideoModalMoment> emitted = [];
  final List<BuildContext?> origins = [];

  @override
  void emit(VideoModalMoment moment, {BuildContext? origin}) {
    emitted.add(moment);
    origins.add(origin);
  }

  List<VideoModalTrigger> get triggers =>
      emitted.map((m) => m.trigger).toList();
}

/// Installe un [RecordingMoments] comme point d'entrée de l'app pour le test
/// en cours, restauré à la fin.
RecordingMoments useRecordingMoments() {
  final moments = RecordingMoments();
  VideoModalMoments.useForTest(moments);
  addTearDown(VideoModalMoments.resetForTest);
  return moments;
}
