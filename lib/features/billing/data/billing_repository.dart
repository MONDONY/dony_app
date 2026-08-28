import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Accès à l'abonnement PRO côté serveur et ouverture du portail web externe
/// où il se vend et se gère.
///
/// L'ouverture d'URL calque `HelpCenterRepository.openExternal` : le lanceur
/// est injectable pour les tests, jamais appelé en dur, et l'ouverture se
/// fait toujours en navigateur externe — jamais en webview, Stripe interdit
/// ses parcours de paiement dans une vue intégrée.
class BillingRepository {
  BillingRepository(this._client, {UrlLauncherPlatform? launcher})
    : _launcher = launcher ?? UrlLauncherPlatform.instance;

  final ApiClient _client;
  final UrlLauncherPlatform _launcher;

  /// `GET /billing/subscription` répond toujours 200, jamais 404 ni 204.
  /// L'absence d'abonnement (statut `NONE`) est un cas nominal, pas une
  /// erreur : il ne faut jamais le traiter comme un échec réseau.
  Future<ProSubscriptionModel> getSubscription() async {
    try {
      final response = await _client.dio.get('/billing/subscription');
      return ProSubscriptionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<bool> openExternal(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }

    try {
      return await _launcher.launchUrl(
        uri.toString(),
        const LaunchOptions(mode: PreferredLaunchMode.externalApplication),
      );
    } catch (_) {
      return false;
    }
  }
}
