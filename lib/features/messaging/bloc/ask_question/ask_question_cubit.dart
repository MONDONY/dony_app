import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// État de la tuile « Poser une question » de la feuille d'un trajet.
///
/// Les états d'issue ([AskQuestionChatReady], [AskQuestionAuthRequired],
/// [AskQuestionKycRequired], [AskQuestionUnavailable], [AskQuestionFailed])
/// ne valent que pour l'émission qui les porte : le cubit revient aussitôt à
/// [AskQuestionIdle] ou [AskQuestionHidden]. L'écran les lit dans son
/// `listener` (navigation, feuille, message), son `builder` ne lit que
/// [hidden] et [loading].
sealed class AskQuestionState {
  const AskQuestionState();

  /// La tuile n'est plus affichée.
  bool get hidden => false;

  /// Ouverture en cours : la tuile montre un indicateur et ignore l'appui.
  bool get loading => false;
}

final class AskQuestionIdle extends AskQuestionState {
  const AskQuestionIdle();
}

final class AskQuestionLoading extends AskQuestionState {
  const AskQuestionLoading();

  @override
  bool get loading => true;
}

/// Tuile retirée (trajet qui n'accepte plus de question).
final class AskQuestionHidden extends AskQuestionState {
  const AskQuestionHidden();

  @override
  bool get hidden => true;
}

/// Conversation ouverte : l'écran ferme la feuille et l'affiche.
final class AskQuestionChatReady extends AskQuestionState {
  const AskQuestionChatReady(this.conversation);

  final ConversationModel conversation;
}

/// Visiteur sans compte : l'écran propose de se connecter.
final class AskQuestionAuthRequired extends AskQuestionState {
  const AskQuestionAuthRequired();
}

/// Identité à vérifier avant de poser une question.
final class AskQuestionKycRequired extends AskQuestionState {
  const AskQuestionKycRequired(this.kycStatus);

  final String kycStatus;
}

/// Le trajet n'accepte plus de question : message, puis tuile retirée.
final class AskQuestionUnavailable extends AskQuestionState {
  const AskQuestionUnavailable();

  @override
  bool get hidden => true;
}

/// Le back ne connaît pas encore les questions (pas encore déployé) : message
/// neutre au premier appui, puis tuile retirée ; les ouvertures suivantes de
/// la feuille partent directement de [AskQuestionHidden].
final class AskQuestionUnsupported extends AskQuestionState {
  const AskQuestionUnsupported();

  @override
  bool get hidden => true;
}

/// Échec inattendu (réseau, 5xx, sourdine…) : l'écran le présente, la tuile
/// reste pour un nouvel essai.
final class AskQuestionFailed extends AskQuestionState {
  const AskQuestionFailed(this.error);

  final Object error;
}

/// Ouvre la conversation de question de l'utilisateur sur un trajet
/// (`POST /conversations/inquiry`).
///
/// Mesure : `inquiry_opened` au succès, `inquiry_open_failed` avec
/// `error_code` sur tout autre chemin (visiteur, identité, trajet fermé, back
/// sans les questions, erreur serveur). Jamais d'identifiant ni de texte.
class AskQuestionCubit extends Cubit<AskQuestionState> {
  AskQuestionCubit(
    this._repository,
    this._analytics, {
    required bool Function() hasRealSession,
  }) : _hasRealSession = hasRealSession,
       super(
         _repository.inquiryUnsupported
             ? const AskQuestionHidden()
             : const AskQuestionIdle(),
       );

  final ConversationRepository _repository;
  final AnalyticsService _analytics;

  /// Session Firebase réelle (pas un visiteur anonyme), lue au moment de
  /// l'appui comme dans la feuille du trajet.
  final bool Function() _hasRealSession;

  /// Code d'échec d'un visiteur sans compte (aucun appel réseau).
  static const errorAuthRequired = 'auth-required';

  /// Code d'échec d'une identité non vérifiée (connue localement ou 403).
  static const errorKycRequired = 'kyc-required';

  /// Appui sur la tuile. [knownKycStatus] : statut KYC connu du lecteur,
  /// `null` s'il est inconnu (le serveur tranche). Ignoré tant qu'une
  /// ouverture est en cours.
  Future<void> ask(String announcementId, {String? knownKycStatus}) async {
    if (state is! AskQuestionIdle) return;
    if (!_hasRealSession()) {
      _failed(errorAuthRequired);
      _settle(const AskQuestionAuthRequired());
      return;
    }
    if (knownKycStatus != null && knownKycStatus != 'VERIFIED') {
      _failed(errorKycRequired);
      _settle(AskQuestionKycRequired(knownKycStatus));
      return;
    }
    emit(const AskQuestionLoading());
    try {
      var conversation = await _repository.openInquiry(announcementId);
      // Fil que l'utilisateur avait supprimé de son côté : le back le rend
      // tel quel, et le parent Firestore porte `deletedAt`. Ouvert ainsi, le
      // chat passerait en lecture seule (`_DeletedByOtherParty`) : il est
      // restauré d'abord, comme `ConversationOpenBloc._open`.
      final restored = conversation.deletedBySelf;
      if (restored) {
        conversation = await _repository.restoreConversation(conversation.id);
      }
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.inquiryOpened,
          properties: {'restored': restored},
        ),
      );
      if (isClosed) return;
      _settle(AskQuestionChatReady(conversation));
    } on InquiryKycRequiredException {
      _failed(errorKycRequired);
      if (isClosed) return;
      _settle(const AskQuestionKycRequired('NOT_STARTED'));
    } on InquiryUnavailableException catch (e) {
      _failed(e.code);
      if (isClosed) return;
      emit(const AskQuestionUnavailable());
      emit(const AskQuestionHidden());
    } on InquiryUnsupportedException {
      _failed(InquiryUnsupportedException.code);
      if (isClosed) return;
      emit(const AskQuestionUnsupported());
      emit(const AskQuestionHidden());
    } catch (e) {
      _failed(unwrapDioError(e).code ?? 'unknown');
      if (isClosed) return;
      _settle(AskQuestionFailed(e));
    }
  }

  void _failed(String errorCode) => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.inquiryOpenFailed,
      properties: {'error_code': errorCode},
    ),
  );

  void _settle(AskQuestionState outcome) {
    emit(outcome);
    emit(const AskQuestionIdle());
  }
}
