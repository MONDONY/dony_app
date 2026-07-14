/// Traductions d'affichage des valeurs backend (spec, section Traductions).
String disputeTypeLabel(String type) => switch (type) {
  'SENDER_NO_SHOW_CONTESTED' => 'Contestation no-show',
  _ => type,
};

String disputeStatusLabel(String status) => switch (status) {
  'OPEN' => 'En instruction',
  'RESOLVED' => 'Résolu',
  _ => status,
};
