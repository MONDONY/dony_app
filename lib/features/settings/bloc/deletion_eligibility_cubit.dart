import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// État de l'éligibilité à la suppression de compte, vérifiée en amont pour
/// griser le bouton de confirmation et expliquer pourquoi au lieu de laisser
/// l'utilisateur tenter une suppression qui échouera côté serveur.
///
/// [canDelete] vaut `true` tant que le check n'est pas encore résolu (ou a
/// échoué) : on ne bloque jamais préventivement sur une simple erreur réseau,
/// le backend reste de toute façon la source de vérité autoritaire au moment
/// de la tentative réelle. Il se dérive donc de [blockedReasonMessage] — un
/// blocage sans motif affichable n'est pas représentable.
class DeletionEligibilityState {
  const DeletionEligibilityState({
    this.isLoading = true,
    this.blockedReasonMessage,
  });

  final bool isLoading;
  final String? blockedReasonMessage;

  bool get canDelete => blockedReasonMessage == null;
}

class DeletionEligibilityCubit extends Cubit<DeletionEligibilityState> {
  DeletionEligibilityCubit(this._repository)
      : super(const DeletionEligibilityState());

  final AccountDeletionRepository _repository;

  Future<void> check() async {
    try {
      final eligibility = await _repository.checkEligibility();
      if (!isClosed) {
        emit(DeletionEligibilityState(
          isLoading: false,
          blockedReasonMessage: eligibility.canDelete
              ? null
              : _messageFor(eligibility.blockedReasonCode),
        ));
      }
    } catch (_) {
      // Fail-open : le bouton reste actif, l'erreur réelle (le cas échéant)
      // sera de toute façon surfacée par AccountDeletionBloc à la tentative.
      if (!isClosed) {
        emit(const DeletionEligibilityState(isLoading: false));
      }
    }
  }

  String _messageFor(String? code) {
    switch (code) {
      case 'active-transactions':
        return 'Vous avez un envoi en cours de livraison, avec des fonds '
            'bloqués en séquestre. Vous pourrez supprimer votre compte dès '
            'que la livraison sera confirmée.';
      case 'wallet-balance-not-empty':
        return 'Vous avez un solde disponible sur votre wallet. '
            'Dépensez-le ou retirez-le avant de supprimer votre compte.';
      default:
        return 'La suppression n\'est pas possible pour l\'instant.';
    }
  }
}
