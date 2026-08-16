import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';

class NegotiationRepository {
  const NegotiationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NegotiationThread> start({
    required String packageRequestId,
    required double proposedPriceEur,
    required DateTime travelerTravelDate,
    required double travelerAvailableKg,
    String? travelerAnnouncementId,
    String? body,
    bool createDedicatedTrip = false,
    Map<String, dynamic>? dedicatedTripPayload,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations',
      data: {
        'packageRequestId': packageRequestId,
        'proposedPriceEur': proposedPriceEur,
        'travelerTravelDate': travelerTravelDate.toIso8601String().substring(
          0,
          10,
        ),
        'travelerAvailableKg': travelerAvailableKg,
        'travelerAnnouncementId': ?travelerAnnouncementId,
        'body': ?body,
        'createDedicatedTrip': createDedicatedTrip,
        'dedicatedTrip': ?dedicatedTripPayload,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<List<NegotiationThread>> findMine() async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/negotiations/me',
    );
    return (response.data ?? <dynamic>[])
        .map((e) => NegotiationThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NegotiationThread> getById(String id) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/negotiations/$id',
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<NegotiationThread> counter(
    String id, {
    required double proposedPriceEur,
    String? body,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/counter',
      data: {'proposedPriceEur': proposedPriceEur, 'body': ?body},
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<NegotiationThread> accept(String id, {String? body}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/accept',
      data: {'body': ?body},
    );
    return NegotiationThread.fromJson(response.data!);
  }

  Future<void> reject(String id, {String? reason}) async {
    await _apiClient.dio.post<void>(
      '/negotiations/$id/reject',
      data: {'reason': ?reason},
    );
  }

  /// Ends the negotiation thread (either party). Terminal, mirrors [reject].
  Future<void> cancel(String id, {String? reason}) async {
    await _apiClient.dio.post<void>(
      '/negotiations/$id/cancel',
      data: reason == null ? null : {'reason': reason},
    );
  }

  /// Traveler links a trip (existing announcement) to an AWAITING_TRIP thread.
  /// Backend validates corridor + date window match the request.
  /// Thread moves to AWAITING_PAYMENT.
  Future<NegotiationThread> submitTrip(
    String id, {
    required String travelerAnnouncementId,
    required PaymentMethod paymentMethod,
    bool useCardForCommission = false,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/submit-trip',
      data: {
        'travelerAnnouncementId': travelerAnnouncementId,
        'paymentMethod': paymentMethod.wireName,
        'useCardForCommission': useCardForCommission,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Traveler creates a brand-new "dedicated" trip linked exclusively to this
  /// thread's package_request. Locked fields (corridor, weight, transport mode,
  /// agreed price) are derived server-side from the request — only the editable
  /// fields are sent. Thread atomically transitions AWAITING_TRIP → AWAITING_PAYMENT.
  Future<NegotiationThread> createDedicatedTrip(
    String threadId, {
    required DateTime departureDate,
    String? departureTime,
    String? arrivalTime,
    required Map<String, dynamic> pickupAddress,
    required Map<String, dynamic> deliveryAddress,
    String? description,
    List<String>? acceptedContentTypes,
    List<String>? refusedTypes,
    required PaymentMethod paymentMethod,
    bool useCardForCommission = false,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$threadId/create-dedicated-trip',
      data: {
        'departureDate': departureDate.toIso8601String().substring(0, 10),
        'departureTime': ?departureTime,
        'arrivalTime': ?arrivalTime,
        'pickupAddress': pickupAddress,
        'deliveryAddress': deliveryAddress,
        'description': ?description,
        'acceptedContentTypes': ?acceptedContentTypes,
        'refusedTypes': ?refusedTypes,
        'paymentMethod': paymentMethod.wireName,
        'useCardForCommission': useCardForCommission,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Sender initiates the Stripe escrow payment for an AWAITING_PAYMENT thread.
  /// Returns the Stripe clientSecret to confirm via PaymentSheet on Flutter side.
  /// The thread is finalized to ACCEPTED async via webhook. [promoCode] optionnel :
  /// s'il ne s'applique plus (expiré/épuisé entre l'aperçu et le paiement), le
  /// backend retombe silencieusement sur le taux sans promo (jamais bloquant).
  Future<
    ({
      String clientSecret,
      String paymentIntentId,
      double amountEur,
      String currencyCode,
      List<String> paymentMethodTypes,
    })
  >
  initiatePayment(String id, {String? promoCode}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/initiate-payment',
      queryParameters: promoCode != null && promoCode.isNotEmpty
          ? {'promoCode': promoCode}
          : null,
    );
    final data = response.data!;
    return (
      clientSecret: data['clientSecret'] as String,
      paymentIntentId: data['stripePaymentIntentId'] as String,
      amountEur: (data['amount'] as num).toDouble(),
      currencyCode: data['currency'] as String? ?? 'EUR',
      paymentMethodTypes:
          (data['paymentMethodTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Devis transparent avant paiement : net voyageur, commission Yadony (taux +
  /// montant), total, et prévisualisation d'un code promo optionnel.
  Future<NegotiationQuote> quote(String id, {String? promoCode}) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/negotiations/$id/quote',
      queryParameters: promoCode != null && promoCode.isNotEmpty
          ? {'promoCode': promoCode}
          : null,
    );
    return NegotiationQuote.fromJson(response.data!);
  }

  /// Sender confirms payment (Stripe paymentIntentId or placeholder) for an
  /// AWAITING_PAYMENT thread. Thread → ACCEPTED, competing threads → AUTO_REJECTED.
  /// In production this is called after Stripe.instance.presentPaymentSheet succeeds;
  /// the webhook may also finalize automatically — calling this is idempotent.
  Future<NegotiationThread> checkout(
    String id, {
    required String paymentIntentId,
    PaymentMethod? paymentMethod,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/checkout',
      data: {
        'paymentIntentId': paymentIntentId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod.wireName,
      },
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Sender refuses the linked trip on an AWAITING_PAYMENT thread.
  /// Thread transitions back to AWAITING_TRIP so the traveler can link another.
  Future<NegotiationThread> refuseTrip(String id, {String? reason}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/refuse-trip',
      data: reason != null && reason.isNotEmpty ? {'reason': reason} : null,
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Traveler changes the trip already linked to an OPEN thread (before
  /// payment), swapping it for another of their announcements. Mirrors
  /// [submitTrip] but for a thread that already has a trip — used by the new
  /// "change trip" flow, distinct from the legacy `AWAITING_TRIP` recovery
  /// loop still served by [submitTrip].
  Future<NegotiationThread> changeTrip(
    String threadId, {
    required String travelerAnnouncementId,
  }) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/negotiations/$threadId/trip',
      data: {'travelerAnnouncementId': travelerAnnouncementId},
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Sends a nudge on this thread to prompt the other party to act.
  /// Backend validates whether the current viewer is allowed to nudge.
  Future<NegotiationThread> nudge(String id) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/nudge',
    );
    return NegotiationThread.fromJson(response.data!);
  }

  /// Traveler settles the Yadony commission for a cash-agreed offer the
  /// sender already accepted. Nothing is sealed until this succeeds: the
  /// sender's acceptance alone doesn't finalize a cash deal.
  ///
  /// The 409 (solde insuffisant) and 422 (échec) portent un corps
  /// exploitable : ce sont des issues métier porteuses des montants à
  /// afficher, pas des erreurs de transport. On détecte donc l'issue métier
  /// par le **code HTTP**, jamais par la forme du corps — exactement comme
  /// `BidRemoteDatasource.acceptBidWithCommission` (`bid_remote_datasource.
  /// dart:218-223`).
  ///
  /// Nuance propre à cet endpoint : plusieurs voyageurs peuvent régler en
  /// même temps, seul le premier gagne. La garde de course renvoie donc,
  /// elle aussi, un 409 (`thread/not-awaiting-commission`,
  /// `request/already-accepted`) — mais en RFC 7807, dont le champ `status`
  /// est l'entier HTTP (409), pas le statut métier `String` attendu par
  /// [AcceptanceResponse.fromJson]. On ne parse donc le corps comme
  /// [AcceptanceResponse] que si `status` y est bien une chaîne ; sinon on
  /// laisse le `DioException` d'origine remonter tel quel — l'intercepteur
  /// global (`api_client.dart`) l'a déjà enrichi d'un `ConflictException`
  /// exploitable via `unwrapDioError`, exactement comme pour la course
  /// webhook Stripe gérée dans `NegotiationBloc._onCheckout`.
  Future<AcceptanceResponse> settleCommission(
    String threadId, {
    String commissionSource = 'WALLET_FIRST',
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/negotiations/$threadId/settle-commission',
        queryParameters: {'commissionSource': commissionSource},
      );
      return AcceptanceResponse.fromJson(response.data!);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if ((code == 409 || code == 422) &&
          data is Map<String, dynamic> &&
          data['status'] is String) {
        return AcceptanceResponse.fromJson(data);
      }
      rethrow;
    }
  }

  /// Confirms a commission settlement after a successful 3D Secure
  /// authentication. Mirrors `BidRemoteDatasource.confirmCommissionAcceptance`:
  /// the backend returns 422 with `ConfirmResponse(accepted: false, error:
  /// ...)` when the confirmation fails post-3DS, and that body must be parsed
  /// rather than surfaced as a transport error.
  Future<ConfirmResponse> confirmCommission(String threadId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/negotiations/$threadId/confirm-commission',
      );
      return ConfirmResponse.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422 && e.response?.data != null) {
        return ConfirmResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  /// Traveler explicitly declines to settle the commission: the request is
  /// released immediately for another traveler instead of waiting out the
  /// settlement deadline.
  Future<void> declineCommission(String threadId) async {
    await _apiClient.dio.post<void>(
      '/negotiations/$threadId/decline-commission',
    );
  }
}
