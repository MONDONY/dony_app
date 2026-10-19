import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';

/// Supplément de prix à la remise (`/bids/{bidId}/supplements`). Le voyageur
/// demande ([options], [quote], [create], [withdraw]), l'expéditeur répond
/// ([accept] puis [confirmPayment] pour la carte, ou [decline]). Erreurs
/// RFC 7807 : voir `ErrorCatalog` (`supplement-*`).
class BidSupplementRemoteDatasource {
  const BidSupplementRemoteDatasource(this._client);

  final ApiClient _client;

  String _base(String bidId) => '/bids/$bidId/supplements';

  /// Bornes du net, montants suggérés et rail du colis (voyageur).
  Future<SupplementOptions> options(String bidId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '${_base(bidId)}/options',
    );
    return SupplementOptions.fromJson(response.data!);
  }

  /// Devis d'un net : commission Yadony et total payé par l'expéditeur.
  /// Lecture pure, rien n'est créé.
  Future<SupplementQuote> quote(String bidId, double netAmount) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/quote',
      data: {'netAmount': netAmount},
    );
    return SupplementQuote.fromJson(response.data!);
  }

  /// Photo du colis, déposée avec les photos de suivi du voyageur
  /// (`POST /storage/upload/tracking`) : la clé rendue commence par
  /// `tracking/<bidId>/`, comme l'exige le back.
  Future<String> uploadPhoto(String bidId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'supplement.jpg',
      ),
      'bidId': bidId,
    });
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/storage/upload/tracking',
      data: formData,
    );
    return response.data!['key'] as String;
  }

  /// Demande du voyageur (201). Le serveur fige la commission et le brut,
  /// prévient l'expéditeur et bloque le scan de remise.
  ///
  /// Colis payé en espèces : la commission du supplément est prélevée au
  /// voyageur à la demande, depuis [commissionSource] (solde par défaut côté
  /// back) et, pour le solde, le portefeuille de complément
  /// [fundingCurrency]. Avec la carte, la demande peut revenir en
  /// `COMMISSION_PENDING` avec `commissionClientSecret` (3DS). Les deux champs
  /// ne partent que s'ils sont posés : un back antérieur les ignore.
  Future<BidSupplement> create(
    String bidId, {
    required double netAmount,
    required BidSupplementReason reason,
    String? reasonText,
    String? gridItemLabel,
    required String photoKey,
    SupplementCommissionSource? commissionSource,
    String? fundingCurrency,
  }) async {
    final text = reasonText?.trim();
    final label = gridItemLabel?.trim();
    final funding = fundingCurrency?.trim().toUpperCase();
    final response = await _client.dio.post<Map<String, dynamic>>(
      _base(bidId),
      data: {
        'netAmount': netAmount,
        'reasonCode': reason.apiValue,
        if (text != null && text.isNotEmpty) 'reasonText': text,
        if (label != null && label.isNotEmpty) 'gridItemLabel': label,
        'photoKey': photoKey,
        'commissionSource': ?commissionSource?.apiValue,
        if (funding != null && funding.isNotEmpty) 'fundingCurrency': funding,
      },
    );
    return BidSupplement.fromJson(response.data!);
  }

  /// Espèces : valide la commission d'une demande en `COMMISSION_PENDING`,
  /// après la 3DS ou pour reprendre un débit resté sans réponse (502/503 à
  /// la création ; même clé côté back, jamais de second débit). Rend la vue
  /// du voyageur : `PROPOSED` une fois prélevée, ou encore
  /// `COMMISSION_PENDING` avec un nouveau `commissionClientSecret`.
  Future<BidSupplement> confirmCommission(
    String bidId,
    String supplementId,
  ) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/$supplementId/commission/confirm',
    );
    return BidSupplement.fromJson(response.data!);
  }

  /// Supplément affiché sur la fiche du colis (`GET /bids/{bidId}`, champ
  /// `supplement`) : la demande en cours, sinon la dernière. `null` sans
  /// supplément ou avec un back antérieur.
  Future<BidSupplement?> current(String bidId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/bids/$bidId',
    );
    final raw = response.data?['supplement'];
    return raw is Map<String, dynamic> ? BidSupplement.fromJson(raw) : null;
  }

  /// Le voyageur retire sa demande tant que l'expéditeur n'a pas payé.
  Future<BidSupplement> withdraw(String bidId, String supplementId) async {
    final response = await _client.dio.delete<Map<String, dynamic>>(
      '${_base(bidId)}/$supplementId',
    );
    return BidSupplement.fromJson(response.data!);
  }

  /// L'expéditeur refuse : le voyageur transporte au prix prévu ou refuse le
  /// colis, sans pénalité.
  Future<BidSupplement> decline(String bidId, String supplementId) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/$supplementId/decline',
    );
    return BidSupplement.fromJson(response.data!);
  }

  /// L'expéditeur accepte et paie. Carte : le serveur crée (ou recycle) le
  /// PaymentIntent du supplément et rend de quoi ouvrir la feuille de
  /// paiement ; `clientSecret` nul quand il n'y a plus rien à payer.
  Future<SupplementCheckout> accept(String bidId, String supplementId) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/$supplementId/accept',
    );
    return SupplementCheckout.fromJson(response.data!);
  }

  /// Filet client après la feuille de paiement : le serveur relit le
  /// PaymentIntent chez Stripe et passe le supplément payé s'il a réussi.
  /// Rejouable, doublé par le webhook Stripe.
  Future<BidSupplement> confirmPayment(
    String bidId,
    String supplementId,
  ) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '${_base(bidId)}/$supplementId/confirm-payment',
    );
    return BidSupplement.fromJson(response.data!);
  }
}
