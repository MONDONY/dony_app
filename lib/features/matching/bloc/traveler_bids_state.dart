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

/// Onglet nommé par un paramètre d'URL (`/demandes?filter=aTraiter`), `null`
/// si la valeur est absente ou inconnue : l'écran choisit alors lui-même.
TravelerBidFilter? resolveTravelerBidFilter(String? value) =>
    value == null ? null : TravelerBidFilter.values.asNameMap()[value];

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

  /// Trajet auquel la vue est restreinte (`/demandes?announcement=<id>`,
  /// ouvert par la tuile « Demandes » de la fiche trajet), `null` pour toutes
  /// les demandes. Restreint la liste visible et les compteurs des onglets,
  /// jamais [pendingCount] : le hub et la barre d'onglets montrent le total.
  final String? announcementId;

  /// Répartition de toutes les bids par filtre, tous trajets confondus.
  final Map<TravelerBidFilter, List<BidModel>> _allByFilter;

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
    this.announcementId,
  }) : _allByFilter = _split(bids, null),
       _byFilter = _split(bids, announcementId);

  /// Bids rangées par onglet, restreintes au trajet [announcementId] s'il est
  /// posé.
  static Map<TravelerBidFilter, List<BidModel>> _split(
    List<BidModel> bids,
    String? announcementId,
  ) {
    final scoped = announcementId == null
        ? bids
        : bids.where((b) => b.announcementId == announcementId);
    return {
      for (final f in TravelerBidFilter.values)
        f: scoped.where(f.matches).toList(growable: false),
    };
  }

  /// Nombre de demandes en attente d'une décision, tous trajets confondus :
  /// la valeur portée par la tuile « Demandes reçues » du hub Activités.
  int get pendingCount => _allByFilter[TravelerBidFilter.aTraiter]!.length;

  /// Une demande du trajet de [announcementId], s'il y en a une : elle porte
  /// les villes du trajet, affichées sur la pastille du filtre.
  BidModel? get announcementSample {
    final id = announcementId;
    if (id == null) return null;
    for (final b in bids) {
      if (b.announcementId == id) return b;
    }
    return null;
  }

  /// Bids correspondant au filtre courant.
  List<BidModel> get visibleBids => _byFilter[filter]!;

  int countFor(TravelerBidFilter f) => _byFilter[f]!.length;

  /// Onglet à montrer à l'ouverture de l'écran : le courant s'il a du
  /// contenu, sinon le premier non vide dans l'ordre des onglets, sinon
  /// « À traiter ».
  TravelerBidFilter get openingFilter {
    if (countFor(filter) > 0) return filter;
    for (final f in TravelerBidFilter.values) {
      if (countFor(f) > 0) return f;
    }
    return TravelerBidFilter.aTraiter;
  }

  TravelerBidsLoaded copyWith({
    List<BidModel>? bids,
    int? page,
    bool? hasMore,
    TravelerBidFilter? filter,
    bool? isLoadingMore,
    String? announcementId,
    bool clearAnnouncement = false,
  }) => TravelerBidsLoaded(
    bids: bids ?? this.bids,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    filter: filter ?? this.filter,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    announcementId: clearAnnouncement
        ? null
        : (announcementId ?? this.announcementId),
  );

  @override
  List<Object?> get props => [
    bids,
    page,
    hasMore,
    filter,
    isLoadingMore,
    announcementId,
  ];
}

class TravelerBidsError extends TravelerBidsState {
  final AppException error;

  const TravelerBidsError(this.error);

  @override
  List<Object?> get props => [error];
}
