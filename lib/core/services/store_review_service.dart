import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';

/// Avis sur la fiche Google Play / App Store, par la fenêtre native de
/// notation (`in_app_review`).
///
/// Les notes données entre utilisateurs (voyageur ↔ expéditeur) restent dans
/// Yadony ; seule cette fenêtre publie une note sur la fiche du Store. Deux
/// entrées :
/// - [requestAfterRating] : après une note de 4 ou 5 étoiles donnée à
///   l'autre partie d'un colis, le moment où l'utilisateur est le plus
///   satisfait. Jamais derrière une question « Vous aimez Yadony ? » (filtrage
///   des avis interdit par Google et Apple), jamais contre une récompense.
/// - [openStoreListing] : tuile « Noter Yadony » de l'onglet Moi, toujours
///   disponible. Elle ouvre la fiche (directement sur « Écrire un avis » côté
///   App Store) plutôt que la fenêtre : Apple n'en affiche que trois par an
///   et ne dit jamais si elle est apparue, un bouton qui ne fait rien serait
///   pire que la fiche.
///
/// Le système décide seul d'afficher la fenêtre (quota, app installée hors du
/// Play Store, TestFlight) et ne dit jamais si la personne a noté. On s'en
/// tient donc à une demande au plus tous les [cooldown], mémorisée sur
/// l'appareil dans la box `user_prefs`.
class StoreReviewService {
  StoreReviewService(
    this._prefs,
    this._analytics, {
    InAppReview? inAppReview,
    DateTime Function()? now,
    this.delay = const Duration(seconds: 1),
  }) : _inAppReview = inAppReview ?? InAppReview.instance,
       _now = now ?? DateTime.now;

  final Box<dynamic> _prefs;
  final AnalyticsService _analytics;
  final InAppReview _inAppReview;
  final DateTime Function() _now;

  /// Attente avant la fenêtre : la feuille de notation se referme et le
  /// message « Merci pour votre avis » s'affiche d'abord.
  final Duration delay;

  /// Identifiant Apple de l'app, pour ouvrir sa fiche App Store.
  static const appStoreId = '6797821239';

  static const lastRequestKey = 'store_review_last_request_at';

  /// Note minimale donnée à l'autre partie pour proposer un avis Store.
  static const minStars = 4;

  static const cooldown = Duration(days: 120);

  /// Propose la fenêtre de notation du Store après une note de [stars]
  /// étoiles donnée à l'autre partie ([roleRated] : `traveler` / `sender`).
  /// Rend `true` si la demande est partie vers le système. Ne lève jamais.
  Future<bool> requestAfterRating({
    required int stars,
    required String roleRated,
  }) async {
    if (stars < minStars) return false;
    try {
      if (!_cooldownElapsed()) return false;
      if (!await _inAppReview.isAvailable()) return false;
      // Mémorisé avant la demande : deux notes envoyées coup sur coup ne
      // déclenchent qu'une fenêtre.
      await _prefs.put(lastRequestKey, _now().toIso8601String());
      await Future<void>.delayed(delay);
      await _inAppReview.requestReview();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.storeReviewRequested,
          properties: {'stars': stars, 'role_rated': roleRated},
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre la fiche Yadony du Store de l'appareil ([source] : écran
  /// d'origine). Rend `false` si elle n'a pas pu s'ouvrir. Ne lève jamais.
  Future<bool> openStoreListing({required String source}) async {
    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.storeListingOpened,
          properties: {'source': source},
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _cooldownElapsed() {
    final raw = _prefs.get(lastRequestKey);
    final last = raw is String ? DateTime.tryParse(raw) : null;
    return last == null || _now().difference(last) >= cooldown;
  }
}
