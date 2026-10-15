/// Lien entre l'utilisateur connecté et un colis (`GET /receptions/role/{id}`).
enum ParcelRole { sender, traveler, recipient, none }

ParcelRole parcelRoleFromJson(Object? raw) => switch (raw) {
  'SENDER' => ParcelRole.sender,
  'TRAVELER' => ParcelRole.traveler,
  'RECIPIENT' => ParcelRole.recipient,
  _ => ParcelRole.none,
};
