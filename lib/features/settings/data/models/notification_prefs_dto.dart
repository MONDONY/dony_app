/// Préférences de notification, miroir de `NotificationPrefsDto` côté backend
/// (`GET` / `PUT /notifications/preferences`).
///
/// Deux vocabulaires cohabitent : l'interface et le stockage Hive utilisent des
/// clés `snake_case` (historique), le contrat serveur du `record` Java expose du
/// `camelCase`. [uiKeyToJsonKey] est le seul endroit où les deux se rencontrent.
///
/// `email_promo` n'apparaît pas ici : aucun champ correspondant n'existe côté
/// serveur, ce réglage reste donc purement local.
class NotificationPrefsDto {
  /// Clés synchronisées avec le serveur, et leur valeur par défaut. Ces défauts
  /// répliquent `NotificationPrefsDto.defaults()` du backend : un utilisateur
  /// sans ligne de préférence doit voir la même chose des deux côtés.
  static const Map<String, bool> defaults = {
    'push_activity_bids': true,
    'push_activity_negotiations': true,
    'push_messages': true,
    'push_trip_reminder': true,
    'push_promo': false,
    'push_corridor_alerts': true,
  };

  static const Map<String, String> uiKeyToJsonKey = {
    'push_activity_bids': 'pushActivityBids',
    'push_activity_negotiations': 'pushActivityNegotiations',
    'push_messages': 'pushMessages',
    'push_trip_reminder': 'pushTripReminder',
    'push_promo': 'pushPromo',
    'push_corridor_alerts': 'pushCorridorAlerts',
  };

  static bool isSynced(String uiKey) => uiKeyToJsonKey.containsKey(uiKey);

  /// Valeurs indexées par clé d'interface. Peut être partielle en lecture : un
  /// champ absent de la réponse laisse la valeur locale inchangée.
  final Map<String, bool> values;

  const NotificationPrefsDto(this.values);

  factory NotificationPrefsDto.fromJson(Map<String, dynamic> json) =>
      NotificationPrefsDto({
        for (final entry in uiKeyToJsonKey.entries)
          if (json[entry.value] is bool) entry.key: json[entry.value] as bool,
      });

  /// Sérialise **toujours les six champs**. Le `record` Java déclare des
  /// `boolean` primitifs : un champ omis y arrive à `false`, ce qui couperait
  /// silencieusement une catégorie que l'utilisateur n'a jamais touchée.
  Map<String, dynamic> toJson() => {
        for (final entry in uiKeyToJsonKey.entries)
          entry.value: values[entry.key] ?? defaults[entry.key]!,
      };
}
