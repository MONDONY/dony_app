import 'package:json_annotation/json_annotation.dart';

part 'bid_photo.g.dart';

/// Photo de colis présignée renvoyée par le backend (ACTIVE uniquement).
@JsonSerializable()
class BidPhoto {
  final String id;
  final String url;

  const BidPhoto({required this.id, required this.url});

  factory BidPhoto.fromJson(Map<String, dynamic> json) =>
      _$BidPhotoFromJson(json);

  Map<String, dynamic> toJson() => _$BidPhotoToJson(this);
}
