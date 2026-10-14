import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

export 'referral_event.dart';
export 'referral_state.dart';

class ReferralBloc extends Bloc<ReferralEvent, ReferralState> {
  ReferralBloc(
    this._repository,
    this._analytics, {
    ContactLinkLauncher? linkLauncher,
  }) : _linkLauncher = linkLauncher ?? ContactLinkLauncher(),
       super(const ReferralInitial()) {
    on<ReferralLoadRequested>(_onLoadRequested);
    on<ReferralRefereesRequested>(_onRefereesRequested);
    on<ReferralRewardChosen>(_onRewardChosen);
    on<ReferralCodeCopied>(_onCodeCopied);
    on<ReferralLinkCopied>(_onLinkCopied);
    on<ReferralShared>(_onShared);
    on<ReferralRedeemRequested>(_onRedeemRequested);
  }

  final ReferralRepository _repository;
  final AnalyticsService _analytics;
  final ContactLinkLauncher _linkLauncher;

  Future<void> _onLoadRequested(
    ReferralLoadRequested event,
    Emitter<ReferralState> emit,
  ) async {
    if (state is! ReferralLoaded) emit(const ReferralLoading());
    // Les filleuls viennent d'un endpoint distinct : son échec (ou son
    // absence sur un back antérieur) ne doit jamais faire tomber l'écran.
    final refereesFuture = event.includeReferees
        ? _fetchReferees(0)
        : Future<_RefereesResult?>.value();
    try {
      final info = await _repository.getMyReferral();
      final referees = await refereesFuture;
      final current = state;
      final base = current is ReferralLoaded
          ? current.copyWith(info: info)
          : ReferralLoaded(info);
      emit(referees == null ? base : referees.applyTo(base));
    } catch (e) {
      // Le futur des filleuls ne lève jamais (erreurs capturées), mais on
      // l'attend pour ne pas laisser de requête orpheline.
      await refereesFuture;
      if (state is ReferralLoaded) {
        // Rafraîchissement silencieux raté : on garde ce qui est affiché.
        return;
      }
      emit(ReferralError(unwrapDioError(e)));
    }
  }

  Future<void> _onRefereesRequested(
    ReferralRefereesRequested event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is! ReferralLoaded) return;
    if (event.reset) {
      emit(current.copyWith(refereesStatus: RefereesStatus.loading));
      final result = await _fetchReferees(0);
      final latest = state;
      if (latest is ReferralLoaded) emit(result.applyTo(latest));
      return;
    }
    if (current.refereesLast || current.loadingMoreReferees) return;
    emit(current.copyWith(loadingMoreReferees: true));
    final result = await _fetchReferees(current.refereesPage + 1);
    final latest = state;
    if (latest is! ReferralLoaded) return;
    if (result.status != RefereesStatus.loaded) {
      // Échec d'une page suivante : la liste déjà affichée reste en place.
      emit(latest.copyWith(loadingMoreReferees: false));
      return;
    }
    emit(
      latest.copyWith(
        referees: [...latest.referees, ...result.referees],
        refereesPage: result.page,
        refereesLast: result.last,
        loadingMoreReferees: false,
      ),
    );
  }

  Future<_RefereesResult> _fetchReferees(int page) async {
    try {
      final result = await _repository.getReferees(page: page);
      return _RefereesResult(
        RefereesStatus.loaded,
        referees: result.content,
        page: result.page,
        last: result.last,
      );
    } catch (e) {
      final error = unwrapDioError(e);
      return _RefereesResult(
        error is NotFoundException
            ? RefereesStatus.unavailable
            : RefereesStatus.error,
      );
    }
  }

  Future<void> _onRewardChosen(
    ReferralRewardChosen event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is! ReferralLoaded || current.isChoosingReward) return;
    emit(current.copyWith(choosingInvitationId: event.invitationId));
    try {
      final updated = await _repository.chooseReward(
        event.invitationId,
        event.choice,
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.referralRewardChosen,
          properties: {'choice': event.choice.wire},
        ),
      );
      final latest = state;
      if (latest is! ReferralLoaded) return;
      emit(
        latest.copyWith(
          referees: _replace(latest.referees, updated),
          clearChoosing: true,
          rewardResult: updated,
        ),
      );
      // Compteurs (pendingRewardCount…) à jour, sans écran de chargement.
      add(const ReferralLoadRequested());
    } catch (e) {
      final error = unwrapDioError(e);
      final latest = state;
      if (latest is! ReferralLoaded) return;
      emit(latest.copyWith(clearChoosing: true, rewardError: error));
      // Déjà choisie ailleurs, ou plus disponible : la liste affichée est
      // périmée, on la relit pour retirer la carte « Récompense disponible ».
      if (error is ConflictException || error is NotFoundException) {
        add(const ReferralRefereesRequested(reset: true));
      }
    }
  }

  List<Referee> _replace(List<Referee> referees, Referee updated) {
    var found = false;
    final next = referees.map((referee) {
      if (referee.invitationId != updated.invitationId) return referee;
      found = true;
      return updated;
    }).toList();
    return found ? next : [updated, ...referees];
  }

  Future<void> _onCodeCopied(
    ReferralCodeCopied event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is ReferralLoaded) {
      await Clipboard.setData(ClipboardData(text: current.info.code));
      // Re-emit the same loaded state so BlocListener can detect the copy action
      emit(current.copyWith());
    }
  }

  Future<void> _onLinkCopied(
    ReferralLinkCopied event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is! ReferralLoaded) return;
    await Clipboard.setData(ClipboardData(text: current.info.shareUrl));
    _logShared(ReferralShareChannel.copyLink);
  }

  Future<void> _onShared(
    ReferralShared event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is! ReferralLoaded) return;
    if (event.channel == ReferralShareChannel.whatsapp) {
      final opened = await _linkLauncher.open(whatsAppShareUri(event.message));
      if (opened) {
        _logShared(ReferralShareChannel.whatsapp);
        return;
      }
      // WhatsApp absent : la feuille de partage du système prend le relais.
    }
    await Share.share(
      event.message,
      sharePositionOrigin: event.sharePositionOrigin,
    );
    _logShared(ReferralShareChannel.shareSheet);
  }

  void _logShared(ReferralShareChannel channel) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.referralShared,
        properties: {'channel': channel.wire},
      ),
    );
  }

  Future<void> _onRedeemRequested(
    ReferralRedeemRequested event,
    Emitter<ReferralState> emit,
  ) async {
    emit(const ReferralRedeemLoading());
    try {
      await _repository.redeemCode(event.code);
      emit(const ReferralRedeemed());
    } catch (e) {
      emit(ReferralRedeemError(unwrapDioError(e)));
    }
  }
}

class _RefereesResult {
  const _RefereesResult(
    this.status, {
    this.referees = const [],
    this.page = 0,
    this.last = true,
  });

  final RefereesStatus status;
  final List<Referee> referees;
  final int page;
  final bool last;

  ReferralLoaded applyTo(ReferralLoaded state) => switch (status) {
    RefereesStatus.loaded => state.copyWith(
      referees: referees,
      refereesStatus: status,
      refereesPage: page,
      refereesLast: last,
      loadingMoreReferees: false,
    ),
    // Échec : on garde une liste déjà affichée plutôt que de l'effacer.
    _ when state.refereesStatus == RefereesStatus.loaded => state,
    _ => state.copyWith(refereesStatus: status, referees: const []),
  };
}
