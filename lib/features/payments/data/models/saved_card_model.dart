import 'package:equatable/equatable.dart';

/// Carte enregistrée du customer Stripe (GET /payments/me/payment-methods).
class SavedCardModel extends Equatable {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  const SavedCardModel({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  factory SavedCardModel.fromJson(Map<String, dynamic> json) =>
      SavedCardModel(
        id: json['id'] as String,
        brand: json['brand'] as String,
        last4: json['last4'] as String,
        expMonth: (json['expMonth'] as num).toInt(),
        expYear: (json['expYear'] as num).toInt(),
      );

  /// Ex. « Visa •••• 4242 ».
  String get displayLabel {
    final capitalized = brand.isEmpty
        ? brand
        : brand[0].toUpperCase() + brand.substring(1);
    return '$capitalized •••• $last4';
  }

  @override
  List<Object?> get props => [id, brand, last4, expMonth, expYear];
}
