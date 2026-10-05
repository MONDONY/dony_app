import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/receptions/data/models/reception.dart';

/// Colis à recevoir de l'utilisateur connecté (lot 2 destinataire).
class ReceptionRemoteDatasource {
  ReceptionRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  /// Liens `PENDING` ou `CONFIRMED`, colis actifs ou remis depuis peu.
  Future<List<Reception>> fetchReceptions() async {
    final response = await _apiClient.dio.get('/receptions');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Reception.fromJson)
        .toList();
  }

  /// 404 quand le lien n'existe pas, a été refusé ou que le colis a disparu.
  Future<Reception> fetchReception(String bidId) async {
    final response = await _apiClient.dio.get('/receptions/$bidId');
    return Reception.fromJson(response.data as Map<String, dynamic>);
  }

  /// « Oui, c'est pour moi » : rend le colis à jour, idempotent.
  Future<Reception> confirm(String bidId) async {
    final response = await _apiClient.dio.post('/receptions/$bidId/confirm');
    return Reception.fromJson(response.data as Map<String, dynamic>);
  }

  /// Le destinataire confirmé note le voyageur après livraison (FLUTTER-CA) :
  /// 201. 403 `reception-not-recipient`, 409 `reception-rating-not-allowed`
  /// (colis pas livré) ou `reception-already-rated`, 422 validation.
  /// Commentaire omis quand il est vide.
  Future<void> rateTraveler(
    String bidId, {
    required int stars,
    String? comment,
  }) async {
    await _apiClient.dio.post(
      '/receptions/$bidId/rating',
      data: {'stars': stars, 'comment': ?comment},
    );
  }

  /// « Ce n'est pas pour moi » : 204, 409 si le lien est déjà confirmé.
  Future<void> decline(String bidId) async {
    await _apiClient.dio.post('/receptions/$bidId/decline');
  }
}
