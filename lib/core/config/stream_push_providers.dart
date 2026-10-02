import 'package:dony/core/config/environment.dart';

/// Noms des fournisseurs push déclarés dans le tableau de bord Stream Video
/// (App settings → Push providers), un jeu par app Stream.
String streamAndroidPushProviderFor(String environment) =>
    environment == 'production' ? 'firebase-prod' : 'firebase-staging';

String streamIosPushProviderFor(String environment) =>
    environment == 'production' ? 'apn-prod' : 'apn-staging';

String get streamAndroidPushProvider =>
    streamAndroidPushProviderFor(kEnvironment);

String get streamIosPushProvider => streamIosPushProviderFor(kEnvironment);
