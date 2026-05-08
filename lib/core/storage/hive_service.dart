import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String offlineQueueBox = 'offline_queue';
  static const String userPrefsBox = 'user_prefs';

  // Clés pour les flags "premier pas" (onboarding par rôle)
  static const String kHasPublishedAsTraveler = 'has_published_as_traveler';
  static const String kHasPublishedAsSender = 'has_published_as_sender';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(offlineQueueBox);
    await Hive.openBox(userPrefsBox);
  }

  Box<Map> get offlineQueue => Hive.box<Map>(offlineQueueBox);

  Box get userPrefs => Hive.box(userPrefsBox);
}
