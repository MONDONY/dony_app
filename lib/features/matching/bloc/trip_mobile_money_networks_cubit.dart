import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Réseaux mobile money acceptés par le voyageur d'un trajet, pour les
/// pastilles de la fiche et l'encart de l'opérateur habituel.
///
/// Le back ne remplit `acceptedMobileMoneyNetworks` que dans
/// `GET /announcements/{id}` : un trajet ouvert depuis la recherche ou
/// l'accueil arrive avec une liste vide. Elle est alors relue ici. État vide :
/// rien de connu, la fiche garde la puce « Mobile money » générique (aussi
/// en cas d'échec ou de 404, sans message).
class TripMobileMoneyNetworksCubit extends Cubit<List<MobileMoneyNetwork>> {
  TripMobileMoneyNetworksCubit(this._repository) : super(const []);

  final AnnouncementRepository _repository;

  /// Liste déjà connue : reprise telle quelle. Sinon, et seulement si le
  /// trajet accepte le mobile money, lecture du détail du trajet.
  Future<void> load(AnnouncementModel announcement) async {
    final known = announcement.acceptedMobileMoneyNetworks;
    if (known.isNotEmpty) {
      emit(known);
      return;
    }
    if (!announcement.acceptedPaymentMethods.contains(
      BidPaymentMethod.mobileMoney,
    )) {
      return;
    }
    try {
      final detail = await _repository.getAnnouncementDetail(announcement.id);
      // La fiche ferme le cubit quand on la quitte : pas d'`emit` après.
      if (isClosed) return;
      final networks = detail.acceptedMobileMoneyNetworks;
      if (networks.isNotEmpty) emit(networks);
    } on Object {
      // Échec réseau ou trajet introuvable : la puce générique reste.
    }
  }
}
