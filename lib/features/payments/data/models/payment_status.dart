import 'package:json_annotation/json_annotation.dart';

enum PaymentStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('ESCROW')
  escrow,
  @JsonValue('RELEASED')
  released,
  @JsonValue('REFUNDED')
  refunded,
  @JsonValue('FAILED')
  failed,
  @JsonValue('CANCELLED')
  cancelled;

  static PaymentStatus fromString(String raw) =>
      PaymentStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == raw.toUpperCase(),
        orElse: () => PaymentStatus.pending,
      );
}
