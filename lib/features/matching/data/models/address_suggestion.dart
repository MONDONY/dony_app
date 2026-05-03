import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address_suggestion.g.dart';

@JsonSerializable()
class AddressSuggestion extends Equatable {
  const AddressSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;

  String get fullLabel => '$mainText, $secondaryText';

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      _$AddressSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$AddressSuggestionToJson(this);

  @override
  List<Object?> get props => [placeId, mainText, secondaryText];
}
