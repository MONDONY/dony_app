import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';

/// Modification d'un colis accepté (`/bids/{bidId}/amendments`). L'expéditeur
/// compose ([options], [quote]), demande ([create], puis [confirmAuthorization]
/// pour la carte) ou retire ([cancel]) ; le voyageur répond ([accept] puis
/// [confirmCommission] en espèces, ou [decline]) et constate à la remise que
/// les kilos manquent ([notBrought]). Erreurs RFC 7807 (`amendment-*`).
class BidAmendmentRemoteDatasource {
  const BidAmendmentRemoteDatasource(this._client);

  final ApiClient _client;

  String _base(String bidId) => '/bids/$bidId/amendments';

  /// Kilos libres, articles de la grille et moyens de paiement proposables.
  Future<AmendmentOptions> options(String bidId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '${_base(bidId)}/options',
    );
    return AmendmentOptions.fromJson(response.data!);
  }

  /// Devis : le brut à payer pour [addedKg] et [items] (identifiant d'article
  /// de grille vers quantité). Lecture pure, rien n'est créé.
  Future<double> quote(
    String bidId, {
    required double addedKg,
    required Map<String, int> items,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/quote',
      data: {'addedKg': addedKg, 'items': _lines(items)},
    );
    return (response.data!['grossAmount'] as num).toDouble();
  }

  /// Demande de l'expéditeur (201), payée par [method]. Carte : la réponse
  /// porte de quoi ouvrir la PaymentSheet qui autorise le montant.
  Future<AmendmentCheckout> create(
    String bidId, {
    required double addedKg,
    required Map<String, int> items,
    required BidPaymentMethod method,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      _base(bidId),
      data: {
        'addedKg': addedKg,
        'items': _lines(items),
        'paymentMethod': method.apiValue,
      },
    );
    return AmendmentCheckout.fromJson(response.data!);
  }

  /// Carte : après la PaymentSheet, le serveur relit l'autorisation chez
  /// Stripe et présente la demande au voyageur. Rejouable.
  Future<BidAmendment> confirmAuthorization(String bidId, String id) =>
      _send('POST', bidId, '$id/confirm-authorization');

  /// L'expéditeur retire sa demande tant que le voyageur ne l'a pas acquise.
  Future<BidAmendment> cancel(String bidId, String id) =>
      _send('DELETE', bidId, id);

  /// Le voyageur refuse : le colis garde ses kilos d'origine.
  Future<BidAmendment> decline(String bidId, String id) =>
      _send('POST', bidId, '$id/decline');

  /// À la remise, les kilos ajoutés ne sont pas là : la modification acquise
  /// est annulée et remboursée.
  Future<BidAmendment> notBrought(String bidId, String id) =>
      _send('POST', bidId, '$id/not-brought');

  /// Espèces : valide la commission après la 3DS. Rejouable.
  Future<BidAmendment> confirmCommission(String bidId, String id) =>
      _send('POST', bidId, '$id/commission/confirm');

  /// Le voyageur accepte. Rail espèces seulement : [commissionSource] et
  /// [fundingCurrency] disent d'où prélever la commission ; sans eux le corps
  /// reste vide (le back applique ses défauts). La vue rendue porte le
  /// `commissionClientSecret` quand la carte demande une 3DS.
  Future<BidAmendment> accept(
    String bidId,
    String id, {
    SupplementCommissionSource? commissionSource,
    String? fundingCurrency,
  }) async {
    final funding = fundingCurrency?.trim().toUpperCase();
    final body = {
      'commissionSource': ?commissionSource?.apiValue,
      if (funding != null && funding.isNotEmpty) 'fundingCurrency': funding,
    };
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/$id/accept',
      data: body.isEmpty ? null : body,
    );
    final json = response.data!;
    return BidAmendment.fromJson(
      json['amendment'] as Map<String, dynamic>,
    ).withCommissionClientSecret(json['commissionClientSecret'] as String?);
  }

  /// Articles envoyés en `[{gridItemId, quantity}]`, quantités nulles écartées.
  List<Map<String, Object>> _lines(Map<String, int> items) => [
    for (final entry in items.entries)
      if (entry.value > 0) {'gridItemId': entry.key, 'quantity': entry.value},
  ];

  Future<BidAmendment> _send(String method, String bidId, String path) async {
    final response = await _client.dio.request<Map<String, dynamic>>(
      '${_base(bidId)}/$path',
      options: Options(method: method),
    );
    return BidAmendment.fromJson(response.data!);
  }
}
