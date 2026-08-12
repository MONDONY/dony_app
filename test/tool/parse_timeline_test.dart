import 'package:test/test.dart';
import '../../tool/parse_timeline.dart';

Map<String, dynamic> summary({
  double avg = 5,
  double worst = 14,
  int missed = 0,
  int frames = 100,
}) => {
  'average_frame_build_time_millis': avg,
  'worst_frame_build_time_millis': worst,
  'missed_frame_build_budget_count': missed,
  'average_frame_rasterizer_time_millis': 5.0,
  'worst_frame_rasterizer_time_millis': 10.0,
  'missed_frame_rasterizer_budget_count': 0,
  'frame_count': frames,
};

void main() {
  test('PASS quand tout sous les seuils bons', () {
    expect(verdictFor(summary()), 'PASS');
  });
  test('FAIL quand avg build > 12ms', () {
    expect(verdictFor(summary(avg: 20)), 'FAIL');
  });
  test('FAIL quand %jank > 5%', () {
    expect(verdictFor(summary(missed: 10, frames: 100)), 'FAIL');
  });
  test('WARN quand avg entre 8 et 12', () {
    expect(verdictFor(summary(avg: 10)), 'WARN');
  });
  test('renderReport produit un tableau markdown avec le scénario', () {
    final md = renderReport({'home_sheet_scroll': summary(avg: 20)});
    expect(md, contains('home_sheet_scroll'));
    expect(md, contains('FAIL'));
  });
}
