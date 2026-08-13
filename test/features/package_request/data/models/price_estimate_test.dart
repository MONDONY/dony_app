import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PriceEstimate.fromJson with HIGH confidence and sample', () {
    final pe = PriceEstimate.fromJson(const {
      'lowEur': 85.0,
      'highEur': 115.0,
      'confidence': 'HIGH',
      'sampleSize': 15,
    });
    expect(pe.confidence, PriceEstimateConfidence.high);
    expect(pe.lowEur, 85.0);
    expect(pe.sampleSize, 15);
  });

  test('PriceEstimate.fromJson with empty corridor', () {
    final pe = PriceEstimate.fromJson(const {
      'lowEur': null,
      'highEur': null,
      'confidence': 'LOW',
      'sampleSize': 0,
    });
    expect(pe.confidence, PriceEstimateConfidence.low);
    expect(pe.lowEur, null);
  });
}
