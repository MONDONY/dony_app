import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:equatable/equatable.dart';

/// Une date refusée d'une série : son code métier (quota de brouillons, KYC,
/// date passée, date déjà prise…), jamais bloquant pour les autres dates.
class TripSeriesFailure extends Equatable {
  const TripSeriesFailure({required this.date, required this.code});

  factory TripSeriesFailure.fromJson(Map<String, dynamic> json) =>
      TripSeriesFailure(
        date: DateTime.parse(json['date'] as String),
        code: (json['code'] as String?) ?? 'series-copy-failed',
      );

  final DateTime date;
  final String code;

  @override
  List<Object?> get props => [date, code];
}

/// Réponse de `POST /announcements/{id}/series` (yadony-back #525) : un
/// trajet par date acceptée, et le détail des dates refusées.
class TripSeriesResult extends Equatable {
  const TripSeriesResult({
    required this.seriesId,
    required this.created,
    required this.failed,
  });

  factory TripSeriesResult.fromJson(Map<String, dynamic> json) =>
      TripSeriesResult(
        seriesId: json['seriesId'] as String,
        created: [
          for (final e in (json['created'] as List?) ?? const [])
            AnnouncementModel.fromJson(e as Map<String, dynamic>),
        ],
        failed: [
          for (final e in (json['failed'] as List?) ?? const [])
            TripSeriesFailure.fromJson(e as Map<String, dynamic>),
        ],
      );

  final String seriesId;
  final List<AnnouncementModel> created;
  final List<TripSeriesFailure> failed;

  /// Date au format attendu par le back (`yyyy-MM-dd`), sans fuseau.
  static String wireDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [seriesId, created.map((a) => a.id), failed];
}
