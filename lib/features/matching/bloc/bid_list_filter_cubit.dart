import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Groupes de statuts ────────────────────────────────────────────────────────

/// Statuts d'un bid « actif » dans l'onglet Acceptées.
const kActiveBidStatuses = <String>{
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'COMPLETED',
};

/// Statuts d'un bid « clôturé » dans l'onglet Acceptées.
const kClosedBidStatuses = <String>{
  'NO_SHOW',
  'PARCEL_REFUSED',
  'CANCELLED',
};

/// `true` si le bid est un `CANCELLED` auto-annulé (PENDING jamais traité par
/// le voyageur — `rejectionReason == TRAVELER_NO_RESPONSE`), jamais accepté.
bool _isAutoCancelled(BidModel bid) =>
    bid.status == 'CANCELLED' &&
    bid.rejectionReason == 'TRAVELER_NO_RESPONSE';

/// `true` si le bid doit figurer dans l'onglet « Acceptées ».
/// Exclut les `CANCELLED` auto-annulés (jamais acceptés).
bool isAcceptedTabBid(BidModel bid) {
  if (_isAutoCancelled(bid)) return false;
  return kActiveBidStatuses.contains(bid.status) ||
      kClosedBidStatuses.contains(bid.status);
}

bool isActiveBid(BidModel bid) => kActiveBidStatuses.contains(bid.status);

/// `true` si le bid est clôturé. Cohérent avec [isAcceptedTabBid] : un
/// `CANCELLED` auto-annulé n'est pas considéré comme clôturé.
bool isClosedBid(BidModel bid) =>
    kClosedBidStatuses.contains(bid.status) && !_isAutoCancelled(bid);

// ── Normalisation de recherche ────────────────────────────────────────────────

const _diacriticsMap = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ñ': 'n',
  'ÿ': 'y',
};

/// Minuscule + suppression des diacritiques. Préserve la longueur (1 char → 1 char),
/// ce qui garantit que les index de correspondance restent valides sur la chaîne
/// d'origine (utilisé pour le surlignage).
String normalizeSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacriticsMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// `true` si le bid correspond à la requête (nom de l'expéditeur ou n° de suivi).
bool bidMatchesQuery(BidModel bid, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  final name = normalizeSearch(bid.resolvedSenderName);
  final track = normalizeSearch(bid.trackingNumber ?? '');
  return name.contains(q) || track.contains(q);
}

// ── État de filtre ────────────────────────────────────────────────────────────

enum AcceptedStatusFilter { all, active, closed }

class BidListFilterState extends Equatable {
  final String query;
  final AcceptedStatusFilter filter;

  const BidListFilterState({
    this.query = '',
    this.filter = AcceptedStatusFilter.all,
  });

  BidListFilterState copyWith({
    String? query,
    AcceptedStatusFilter? filter,
  }) =>
      BidListFilterState(
        query: query ?? this.query,
        filter: filter ?? this.filter,
      );

  @override
  List<Object?> get props => [query, filter];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Porte l'état de vue de l'onglet « Acceptées » : requête de recherche et
/// catégorie de filtre. Aucune donnée métier, aucun appel réseau.
class BidListFilterCubit extends Cubit<BidListFilterState> {
  BidListFilterCubit() : super(const BidListFilterState());

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setFilter(AcceptedStatusFilter filter) =>
      emit(state.copyWith(filter: filter));

  void reset() => emit(const BidListFilterState());
}
