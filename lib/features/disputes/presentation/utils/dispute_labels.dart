/// Traductions d'affichage des valeurs backend (spec, section Traductions).
String disputeTypeLabel(String type) => switch (type) {
  'SENDER_NO_SHOW_CONTESTED' => "Contestation d'absence",
  'RECIPIENT_NO_SHOW_CONTESTED' || 'RECIPIENT_NO_SHOW' => 'Absence du destinataire',
  'TRAVELER_DELIVERY_NO_SHOW_CONTESTED' || 'TRAVELER_DELIVERY_NO_SHOW' => 'Défaut de livraison',
  _ => type,
};

String disputeStatusLabel(String status) => switch (status) {
  'OPEN' => 'En instruction',
  'RESOLVED' => 'Résolu',
  _ => status,
};
