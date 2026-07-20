import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';

/// Page de demandes reçues sur les trajets du voyageur.
///
/// Correspond à la `Page<BidResponse>` Spring renvoyée par
/// `GET /travelers/me/bids`.
class TravelerBidsPage extends Equatable {
  final List<BidModel> content;
  final int totalElements;
  final int page;
  final bool isLast;

  const TravelerBidsPage({
    required this.content,
    required this.totalElements,
    required this.page,
    required this.isLast,
  });

  const TravelerBidsPage.empty()
    : content = const [],
      totalElements = 0,
      page = 0,
      isLast = true;

  factory TravelerBidsPage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'] as List? ?? const [];
    return TravelerBidsPage(
      content: rawContent
          .map((j) => BidModel.fromJson(j as Map<String, dynamic>))
          .toList(),
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      page: (json['number'] as num?)?.toInt() ?? 0,
      isLast: json['last'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [content, totalElements, page, isLast];
}
