import 'package:dony/l10n/l10n.dart';

/// Message affiché à côté du bouton de suppression quand le serveur refuse
/// la suppression du compte (`GET /auth/me/deletion-eligibility`,
/// `blockedReasonCode`) : seul `active-transactions` (fonds encore en
/// séquestre sur un envoi) a un message dédié, tout autre code — connu du
/// serveur mais pas encore de ce client, ou absent — retombe sur un message
/// générique. `'wallet-balance-not-empty'` n'est plus un `blockedReasonCode`
/// possible côté backend depuis Apple 5.1.1(v) : un solde wallet ne bloque
/// plus jamais la suppression (`DeletionEligibilityState.hasWalletBalance`,
/// informatif). Seul `active-transactions` atteint encore ce switch.
/// Consommé par `deletion_eligibility_cubit.dart`'s state dans
/// `delete_account_bottom_sheet.dart`.
String deletionBlockedMessage(AppLocalizations l, String? code) {
  switch (code) {
    case 'active-transactions':
      return l.deletionBlockedActiveTransactions;
    default:
      return l.deletionBlockedGeneric;
  }
}
