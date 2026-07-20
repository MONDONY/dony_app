import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';

/// Filtre de vue de l'écran « Demandes reçues ».
enum TravelerBidFilter {
  /// Demandes en attente d'une décision du voyageur.
  aTraiter,

  /// Demandes acceptées, colis en cours d'acheminement.
  acceptees,

  /// Demandes clôturées (refusées, annulées, livrées).
  terminees,
}

extension TravelerBidFilterX on TravelerBidFilter {
  String get label => switch (this) {
    TravelerBidFilter.aTraiter => 'À traiter',
    TravelerBidFilter.acceptees => 'Acceptées',
    TravelerBidFilter.terminees => 'Terminées',
  };

  /// `true` si [bid] appartient à ce filtre.
  ///
  /// Réutilise les prédicats de `bid_list_filter_cubit.dart` pour rester
  /// cohérent avec les écrans existants.
  bool matches(BidModel bid) => switch (this) {
    TravelerBidFilter.aTraiter => isPendingBid(bid),
    TravelerBidFilter.acceptees => isActiveBid(bid),
    TravelerBidFilter.terminees => isClosedBid(bid),
  };
}

sealed class TravelerBidsState extends Equatable {
  const TravelerBidsState();

  @override
  List<Object?> get props => [];
}

class TravelerBidsInitial extends TravelerBidsState {
  const TravelerBidsInitial();
}

class TravelerBidsLoading extends TravelerBidsState {
  const TravelerBidsLoading();
}

class TravelerBidsLoaded extends TravelerBidsState {
  final List<BidModel> bids;
  final int totalElements;
  final int page;
  final bool hasMore;
  final TravelerBidFilter filter;

  /// `true` pendant le chargement d'une page supplémentaire — la liste
  /// courante reste affichée.
  final bool isLoadingMore;

  const TravelerBidsLoaded({
    required this.bids,
    required this.totalElements,
    required this.page,
    required this.hasMore,
    required this.filter,
    this.isLoadingMore = false,
  });

  /// Nombre de demandes en attente d'une décision — la valeur portée par la
  /// tuile « Demandes » du hub Activités.
  int get pendingCount => bids.where(isPendingBid).length;

  /// Bids correspondant au filtre courant.
  List<BidModel> get visibleBids =>
      bids.where((b) => filter.matches(b)).toList();

  int countFor(TravelerBidFilter f) => bids.where(f.matches).length;

  TravelerBidsLoaded copyWith({
    List<BidModel>? bids,
    int? totalElements,
    int? page,
    bool? hasMore,
    TravelerBidFilter? filter,
    bool? isLoadingMore,
  }) => TravelerBidsLoaded(
    bids: bids ?? this.bids,
    totalElements: totalElements ?? this.totalElements,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    filter: filter ?? this.filter,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [
    bids,
    totalElements,
    page,
    hasMore,
    filter,
    isLoadingMore,
  ];
}

class TravelerBidsError extends TravelerBidsState {
  final AppException error;

  const TravelerBidsError(this.error);

  @override
  List<Object?> get props => [error];
}
