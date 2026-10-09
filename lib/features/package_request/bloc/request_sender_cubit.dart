import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ligne « expéditeur » en tête de la fiche publique d'une demande, côté
/// voyageur (FLUTTER-GF).
sealed class RequestSenderState {
  const RequestSenderState();
}

/// Profil en cours de chargement : la fiche affiche un squelette.
final class RequestSenderLoading extends RequestSenderState {
  const RequestSenderLoading();
}

/// Profil chargé, au format du résumé déjà servi par les cartes de liste.
final class RequestSenderLoaded extends RequestSenderState {
  const RequestSenderLoaded(this.sender);

  final SenderPublicProfile sender;
}

/// Rien à afficher : visiteur sans compte, expéditeur sans identifiant,
/// profil masqué (404 d'un compte bloqué) ou échec réseau. La ligne est
/// secondaire, elle disparaît sans message.
final class RequestSenderHidden extends RequestSenderState {
  const RequestSenderHidden();
}

/// Charge le profil public de l'expéditeur (`GET /users/{id}/profile-public`).
class RequestSenderCubit extends Cubit<RequestSenderState> {
  RequestSenderCubit(this._repository, this._analytics)
    : super(const RequestSenderLoading());

  final ProfileRepository _repository;
  final AnalyticsService _analytics;

  /// [canRead] : `false` pour un visiteur sans compte, que la route refuse
  /// (rôles SENDER/TRAVELER exigés) : inutile de l'appeler.
  Future<void> load(String senderId, {required bool canRead}) async {
    if (senderId.isEmpty || !canRead) {
      emit(const RequestSenderHidden());
      return;
    }
    emit(const RequestSenderLoading());
    try {
      final p = await _repository.getProfilePublic(senderId);
      if (isClosed) return;
      emit(
        RequestSenderLoaded(
          SenderPublicProfile(
            id: p.userId.isEmpty ? senderId : p.userId,
            // Vide pour un invité sans nom : l'affichage prend le repli
            // traduit (senderFallbackName).
            displayName: p.displayName,
            averageRating: p.averageRating,
            totalRatings: p.ratingCount,
            kycVerified: p.kycVerified,
            avatarUrl: p.avatarUrl,
            incidentCount: p.senderIncidentCount,
          ),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const RequestSenderHidden());
    }
  }

  /// Tap sur la ligne : ouverture du résumé du profil.
  void trackOpened() => unawaited(
    _analytics.logEvent(AnalyticsEvents.packageRequestSenderOpened),
  );
}
