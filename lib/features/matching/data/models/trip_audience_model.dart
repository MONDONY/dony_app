import 'package:equatable/equatable.dart';

/// Audience d'un trajet, réservée à son voyageur (`GET /announcements/{id}/insights`).
class TripAudienceModel extends Equatable {
  const TripAudienceModel({
    required this.uniqueViewerCount,
    required this.shareViewCount,
  });

  factory TripAudienceModel.fromJson(Map<String, dynamic> json) =>
      TripAudienceModel(
        uniqueViewerCount: (json['uniqueViewerCount'] as num?)?.toInt() ?? 0,
        shareViewCount: (json['shareViewCount'] as num?)?.toInt() ?? 0,
      );

  /// Personnes connectées, autres que le voyageur, qui ont ouvert le trajet
  /// dans l'app pendant qu'il était en ligne (une fois chacune).
  final int uniqueViewerCount;

  /// Consultations de la page web publique de l'affiche partagée.
  final int shareViewCount;

  bool get isEmpty => uniqueViewerCount == 0 && shareViewCount == 0;

  @override
  List<Object?> get props => [uniqueViewerCount, shareViewCount];
}
