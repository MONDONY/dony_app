import 'package:equatable/equatable.dart';

enum PriceEstimateConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW');

  final String wireName;
  const PriceEstimateConfidence(this.wireName);

  static PriceEstimateConfidence fromJson(String s) =>
      PriceEstimateConfidence.values.firstWhere((e) => e.wireName == s);
}

class PriceEstimate extends Equatable {
  const PriceEstimate({
    this.lowEur,
    this.highEur,
    required this.confidence,
    required this.sampleSize,
  });

  final double? lowEur;
  final double? highEur;
  final PriceEstimateConfidence confidence;
  final int sampleSize;

  factory PriceEstimate.fromJson(Map<String, dynamic> json) => PriceEstimate(
        lowEur: (json['lowEur'] as num?)?.toDouble(),
        highEur: (json['highEur'] as num?)?.toDouble(),
        confidence: PriceEstimateConfidence.fromJson(json['confidence'] as String),
        sampleSize: json['sampleSize'] as int,
      );

  @override
  List<Object?> get props => [lowEur, highEur, confidence, sampleSize];
}
