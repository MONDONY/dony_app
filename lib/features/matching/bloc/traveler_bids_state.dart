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
  final int page;
  final bool hasMore;
  final TravelerBidFilter filter;

  /// `true` pendant le chargement d'une page supplémentaire — la liste
  /// courante reste affichée.
  final bool isLoadingMore;

  /// Répartition des bids par filtre, calculée une fois à la construction.
  ///
  /// L'écran lit les trois compteurs et la liste visible à chaque build ;
  /// les recalculer à la demande ferait quatre passes sur une liste qui
  /// grandit de 20 à chaque page.
  final Map<TravelerBidFilter, List<BidModel>> _byFilter;

  TravelerBidsLoaded({
    required this.bids,
    required this.page,
    required this.hasMore,
    required this.filter,
    this.isLoadingMore = false,
  }) : _byFilter = {
         for (final f in TravelerBidFilter.values)
           f: bids.where(f.matches).toList(growable: false),
       };

  /// Nombre de demandes en attente d'une décision — la valeur portée par la
  /// tuile « Demandes reçues » du hub Activités.
  int get pendingCount => countFor(TravelerBidFilter.aTraiter);

  /// Bids correspondant au filtre courant.
  List<BidModel> get visibleBids => _byFilter[filter]!;

  int countFor(TravelerBidFilter f) => _byFilter[f]!.length;

  TravelerBidsLoaded copyWith({
    List<BidModel>? bids,
    int? page,
    bool? hasMore,
    TravelerBidFilter? filter,
    bool? isLoadingMore,
  }) => TravelerBidsLoaded(
    bids: bids ?? this.bids,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    filter: filter ?? this.filter,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [bids, page, hasMore, filter, isLoadingMore];
}

class TravelerBidsError extends TravelerBidsState {
  final AppException error;

  const TravelerBidsError(this.error);

  @override
  List<Object?> get props => [error];
}
