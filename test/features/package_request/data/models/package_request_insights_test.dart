import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson', () {
    final i = PackageRequestInsights.fromJson(const {
      'viewCount': 14,
      'invitedAnnouncementIds': ['a-1', 'a-2'],
    });
    expect(i.viewCount, 14);
    expect(i.invitedAnnouncementIds, const {'a-1', 'a-2'});
  });

  test('fromJson lit le nombre de personnes quand le back le fournit', () {
    final i = PackageRequestInsights.fromJson(const {
      'viewCount': 14,
      'uniqueViewerCount': 5,
    });
    expect(i.uniqueViewerCount, 5);
  });

  test('fromJson tolère les champs absents', () {
    final i = PackageRequestInsights.fromJson(const {});
    expect(i.viewCount, 0);
    // Ancien back : null, et non 0, pour que l'écran sache retomber sur viewCount.
    expect(i.uniqueViewerCount, isNull);
    expect(i.invitedAnnouncementIds, isEmpty);
  });
}
