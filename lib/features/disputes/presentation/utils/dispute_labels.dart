import 'package:dony/l10n/l10n.dart';

/// Traductions d'affichage des valeurs backend (spec, section Traductions).
String disputeTypeLabel(AppLocalizations l, String type) => switch (type) {
  'SENDER_NO_SHOW_CONTESTED' => l.disputeTypeContestedNoShow,
  'RECIPIENT_NO_SHOW_CONTESTED' ||
  'RECIPIENT_NO_SHOW' => l.disputeTypeRecipientNoShow,
  'TRAVELER_DELIVERY_NO_SHOW_CONTESTED' ||
  'TRAVELER_DELIVERY_NO_SHOW' => l.disputeTypeDeliveryFailure,
  _ => type,
};

String disputeStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      'OPEN' => l.disputeStatusOpen,
      'RESOLVED' => l.disputeStatusResolved,
      _ => status,
    };

/// Poids d'un envoi pour [AppLocalizations.disputeParcelWeight] : entier sans
/// décimale, à la langue sinon (`formatOneDecimal`).
String disputeWeightLabel(AppLocalizations l, double kg) =>
    kg % 1 == 0 ? kg.toStringAsFixed(0) : formatOneDecimal(l, kg);
