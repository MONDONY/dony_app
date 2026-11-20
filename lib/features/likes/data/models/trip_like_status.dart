import 'package:equatable/equatable.dart';

/// Réponse de `PUT`/`DELETE /announcements/{id}/like`.
class TripLikeStatus extends Equatable {
  const TripLikeStatus({required this.likeCount, required this.likedByMe});

  factory TripLikeStatus.fromJson(Map<String, dynamic> json) => TripLikeStatus(
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
  );

  final int likeCount;
  final bool likedByMe;

  @override
  List<Object?> get props => [likeCount, likedByMe];
}
