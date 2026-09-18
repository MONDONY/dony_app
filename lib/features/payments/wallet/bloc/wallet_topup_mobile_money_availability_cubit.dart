import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Le rail mobile money est-il servi par le backend déployé ?
///
/// `false` au départ, et tant que la sonde n'a pas abouti : la tuile
/// « Mobile money » de l'écran de choix n'apparaît qu'après une réponse
/// positive. Sur une prod gelée avant le lot 2, la sonde échoue (404) et
/// l'écran reste exactement celui d'avant — carte bancaire seule — plutôt
/// que d'offrir un chemin qui finit sur un « Réessayer » sans issue.
///
/// L'échec n'est jamais une erreur pour l'utilisateur : [probe] ne lève
/// rien et n'affiche rien, l'écran reste utilisable pendant la sonde.
class WalletTopupMobileMoneyAvailabilityCubit extends Cubit<bool> {
  WalletTopupMobileMoneyAvailabilityCubit(this._repository) : super(false);

  final WalletRepository _repository;

  Future<void> probe() async {
    final available = await _repository.isMobileMoneyTopupAvailable();
    if (isClosed) return;
    emit(available);
  }
}
