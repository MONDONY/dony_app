import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';

/// Invitations « destinataire Yadony » (lot 4).
class RecipientInvitationDatasource {
  RecipientInvitationDatasource(this._apiClient);

  final ApiClient _apiClient;

  static const _base = '/recipient-invitations';

  /// Exactement l'un des deux. Le serveur répond toujours `202` pour un
  /// format valide, que le compte existe ou non : rien à lire en retour.
  /// `429` au-delà du quota, `422` pour un format refusé.
  Future<void> send({String? phone, String? email}) async {
    assert((phone == null) != (email == null), 'phone XOR email');
    await _apiClient.dio.post(_base, data: {'phone': ?phone, 'email': ?email});
  }

  Future<List<SentRecipientInvitation>> fetchSent() async {
    final response = await _apiClient.dio.get('$_base/sent');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SentRecipientInvitation.fromJson)
        .toList();
  }

  Future<List<IncomingRecipientInvitation>> fetchIncoming() async {
    final response = await _apiClient.dio.get('$_base/incoming');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(IncomingRecipientInvitation.fromJson)
        .toList();
  }

  /// `409` `recipient-invitation-phone-required` si le compte n'a pas de
  /// numéro de téléphone.
  Future<void> accept(String id) async {
    await _apiClient.dio.post('$_base/$id/accept');
  }

  Future<void> decline(String id) async {
    await _apiClient.dio.post('$_base/$id/decline');
  }

  /// Annulation par l'expéditeur comme retrait par l'invité : même route.
  Future<void> revoke(String id) async {
    await _apiClient.dio.delete('$_base/$id');
  }
}
