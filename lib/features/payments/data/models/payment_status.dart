import 'package:json_annotation/json_annotation.dart';

enum PaymentStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('AUTHORIZED') authorized,
  @JsonValue('CAPTURED') captured,
  @JsonValue('REFUNDED') refunded,
  @JsonValue('FAILED') failed,
  @JsonValue('DISPUTED') disputed,
  @JsonValue('CANCELED') canceled;

  static PaymentStatus fromString(String raw) =>
      PaymentStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == raw.toUpperCase(),
        orElse: () => PaymentStatus.pending,
      );
}
