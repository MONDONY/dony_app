import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dony/core/error/app_exception.dart';

export 'referral_event.dart';
export 'referral_state.dart';

class ReferralBloc extends Bloc<ReferralEvent, ReferralState> {
  ReferralBloc(this._repository, this._analytics) : super(const ReferralInitial()) {
    on<ReferralLoadRequested>(_onLoadRequested);
    on<ReferralCodeCopied>(_onCodeCopied);
    on<ReferralShared>(_onShared);
    on<ReferralRedeemRequested>(_onRedeemRequested);
  }

  final ReferralRepository _repository;
  final AnalyticsService _analytics;

  Future<void> _onLoadRequested(
    ReferralLoadRequested event,
    Emitter<ReferralState> emit,
  ) async {
    if (state is! ReferralLoaded) emit(const ReferralLoading());
    try {
      final info = await _repository.getMyReferral();
      emit(ReferralLoaded(info));
    } catch (e) {
      emit(ReferralError(unwrapDioError(e)));
    }
  }

  Future<void> _onCodeCopied(
    ReferralCodeCopied event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is ReferralLoaded) {
      await Clipboard.setData(ClipboardData(text: current.info.code));
      // Re-emit the same loaded state so BlocListener can detect the copy action
      emit(ReferralLoaded(current.info));
    }
  }

  Future<void> _onShared(
    ReferralShared event,
    Emitter<ReferralState> emit,
  ) async {
    final current = state;
    if (current is ReferralLoaded) {
      await Share.share(
        'Salut ! Utilise mon code dony : ${current.info.code} et reçois ton 1er envoi avec 5€ de réduction. ${current.info.shareUrl}',
      );
      unawaited(_analytics.logEvent(
        AnalyticsEvents.referralShared,
        properties: {'channel': 'share_sheet'},
      ));
    }
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
