import 'package:equatable/equatable.dart';

class PriceGridItemModel extends Equatable {
  final String id;
  final String label;
  final double unitPriceNet;
  final double unitPriceDisplay;
  final int position;

  const PriceGridItemModel({
    required this.id,
    required this.label,
    required this.unitPriceNet,
    required this.unitPriceDisplay,
    required this.position,
  });

  factory PriceGridItemModel.fromJson(Map<String, dynamic> json) =>
      PriceGridItemModel(
        id: json['id'] as String,
        label: json['label'] as String,
        unitPriceNet: (json['unitPriceNet'] as num).toDouble(),
        unitPriceDisplay: (json['unitPriceDisplay'] as num).toDouble(),
        position: json['position'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'unitPriceNet': unitPriceNet,
        'unitPriceDisplay': unitPriceDisplay,
        'position': position,
      };

  @override
  List<Object?> get props => [id, label, unitPriceNet, unitPriceDisplay, position];
}
