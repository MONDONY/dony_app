import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SupportContactStatus {
  /// Lecture du numéro pas encore terminée : rien n'est affiché.
  initial,

  /// Numéro réglé dans l'admin : la carte WhatsApp est affichée.
  ready,

  /// Aucun numéro (non réglé, back sans la route, hors ligne) : pas de carte.
  hidden,
}

class SupportContactState extends Equatable {
  const SupportContactState({
    this.status = SupportContactStatus.initial,
    this.whatsappNumber,
  });

  final SupportContactStatus status;

  /// Numéro international (`+33612345678`), jamais envoyé à l'analytics.
  final String? whatsappNumber;

  @override
  List<Object?> get props => [status, whatsappNumber];
}

/// Numéro WhatsApp de l'équipe Yadony, réglé dans l'admin et servi par
/// `GET /config/support-contact`, et les gestes de contact qui en dépendent.
///
/// Un échec de lecture masque la carte sans rien afficher : le support reste
/// joignable par ses tickets, l'absence du numéro ne doit jamais bloquer
/// l'écran.
class SupportContactCubit extends Cubit<SupportContactState> {
  SupportContactCubit(
    this._config,
    this._analytics, {
    ContactLinkLauncher? launcher,
  }) : _launcher = launcher ?? ContactLinkLauncher(),
       super(const SupportContactState());

  final IConfigRepository _config;
  final AnalyticsService _analytics;
  final ContactLinkLauncher _launcher;

  /// [source] : écran qui porte la carte (`support` ou `faq`).
  Future<void> load({required String source}) async {
    try {
      final number = await _config.getSupportWhatsappNumber();
      if (isClosed) return;
      if (number == null) {
        emit(const SupportContactState(status: SupportContactStatus.hidden));
        return;
      }
      emit(
        SupportContactState(
          status: SupportContactStatus.ready,
          whatsappNumber: number,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.supportWhatsappCardShown,
          properties: {'source': source},
        ),
      );
    } catch (e) {
      AppLog.warn('support_contact_load_failed', data: {'error': '$e'});
      if (isClosed) return;
      emit(const SupportContactState(status: SupportContactStatus.hidden));
    }
  }

  /// Ouvre WhatsApp sur la conversation avec l'équipe, [message] pré-rempli.
  /// `false` : WhatsApp ne s'est pas ouvert (pas installé, numéro illisible),
  /// l'appelant montre alors la feuille de repli.
  Future<bool> openWhatsApp({
    required String message,
    required String source,
  }) async {
    final uri = whatsAppChatUri(state.whatsappNumber, message);
    final opened = uri != null && await _launcher.open(uri);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.supportWhatsappOpened,
        properties: {
          'source': source,
          'outcome': opened ? 'whatsapp' : 'fallback',
        },
      ),
    );
    return opened;
  }

  /// Ouvre la messagerie SMS sur le numéro de l'équipe. `false` : rien ne s'est
  /// ouvert.
  Future<bool> sendSms(String body) async {
    final uri = smsUri(state.whatsappNumber, body);
    final opened = uri != null && await _launcher.open(uri);
    _trackFallback('sms', opened);
    return opened;
  }

  /// Le composeur est ouvert par `dialPhoneNumber` (avec son propre repli) :
  /// le cubit ne fait que tracer le geste.
  void trackCall() => _trackFallback('call', true);

  void trackCopy() => _trackFallback('copy', true);

  void _trackFallback(String action, bool opened) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.supportContactFallbackAction,
        properties: {'action': action, 'opened': opened},
      ),
    );
  }
}
