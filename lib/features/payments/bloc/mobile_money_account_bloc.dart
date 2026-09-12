import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compte de versement mobile money du voyageur (Wave / Orange Money via
/// pawaPay) : consultation, activation et désactivation.
///
/// Style identique à `BidNegotiationBloc` : le repository ne fait que
/// passer, c'est ici que les erreurs sont déballées (`unwrapDioError`) et
/// que les events analytics sont tirés, en `unawaited`.
class MobileMoneyAccountBloc
    extends Bloc<MobileMoneyAccountEvent, MobileMoneyAccountState> {
  MobileMoneyAccountBloc(this._repository, this._analytics)
    : super(const MobileMoneyAccountInitial()) {
    on<MobileMoneyAccountRequested>(_onRequested);
    on<MobileMoneyAccountActivateRequested>(_onActivateRequested);
    on<MobileMoneyAccountDisableRequested>(_onDisableRequested);
    on<MobileMoneyAccountProvidersRequested>(_onProvidersRequested);
    on<MobileMoneyAccountProvidersCleared>(_onProvidersCleared);
    on<MobileMoneyAccountProvidersUpdateRequested>(_onProvidersUpdateRequested);
    on<MobileMoneyAccountChangeNumberRequested>(_onChangeNumberRequested);
    on<MobileMoneyAccountChangeNumberCancelled>(_onChangeNumberCancelled);
  }

  final MobileMoneyAccountRepository _repository;
  final AnalyticsService _analytics;

  static const _fallbackAccount = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.notConfigured,
  );

  /// Compte porté par l'état courant, quand il y en a un.
  MobileMoneyAccount? get _currentAccount {
    final s = state;
    return switch (s) {
      MobileMoneyAccountLoaded() => s.account,
      MobileMoneyAccountUpdating() => s.account,
      MobileMoneyAccountError() => s.account,
      MobileMoneyAccountPhoneRequired() => s.account,
      MobileMoneyAccountProvidersLoading() => s.account,
      MobileMoneyAccountProvidersLoaded() => s.account,
      MobileMoneyAccountProvidersError() => s.account,
      MobileMoneyAccountProvidersUnavailable() => s.account,
      _ => null,
    };
  }

  /// Le voyageur est-il en train de changer son numéro ? Porté d'état en
  /// état pendant le catalogue et l'activation, pour que l'écran garde le
  /// formulaire affiché sur un compte encore actif.
  bool get _editingNumber {
    final s = state;
    return switch (s) {
      MobileMoneyAccountLoaded() => s.editingNumber,
      MobileMoneyAccountUpdating() => s.editingNumber,
      MobileMoneyAccountProvidersLoading() => s.editingNumber,
      MobileMoneyAccountProvidersLoaded() => s.editingNumber,
      MobileMoneyAccountProvidersError() => s.editingNumber,
      MobileMoneyAccountProvidersUnavailable() => s.editingNumber,
      MobileMoneyAccountPhoneRequired() => s.editingNumber,
      MobileMoneyAccountError() => s.editingNumber,
      _ => false,
    };
  }

  Future<void> _onRequested(
    MobileMoneyAccountRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    emit(const MobileMoneyAccountLoading());
    try {
      final account = await _repository.get();
      emit(MobileMoneyAccountLoaded(account));
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e)));
    }
  }

  Future<void> _onActivateRequested(
    MobileMoneyAccountActivateRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    // Capturé avant l'émission de Updating : un échec doit rendre l'écran au
    // formulaire de changement de numéro s'il en venait, jamais à la vue
    // active (ni à un état vide) au premier aléa réseau.
    final editing = _editingNumber;
    emit(MobileMoneyAccountUpdating(base, editingNumber: editing));
    try {
      final account = await _repository.activate(
        phoneNumber: event.phoneNumber,
        providers: event.providers,
      );
      // Activation réussie : la vue active reprend la main, l'édition du
      // numéro est terminée.
      emit(MobileMoneyAccountLoaded(account));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyAccountActivated,
          properties: {
            'provider': account.providerLabel ?? 'inconnu',
            'providers_count': account.providers.length,
            'currency': account.currency ?? '',
          },
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      if (error.code == 'mobile-money-phone-required') {
        emit(MobileMoneyAccountPhoneRequired(base, editingNumber: editing));
      } else {
        emit(
          MobileMoneyAccountError(error, account: base, editingNumber: editing),
        );
      }
    }
  }

  Future<void> _onDisableRequested(
    MobileMoneyAccountDisableRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    emit(MobileMoneyAccountUpdating(base));
    try {
      final account = await _repository.disable();
      emit(MobileMoneyAccountLoaded(account));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyAccountDisabled,
          properties: {
            'provider': account.providerLabel ?? 'inconnu',
            'currency': account.currency ?? '',
          },
        ),
      );
    } catch (e) {
      emit(MobileMoneyAccountError(unwrapDioError(e), account: base));
    }
  }

  Future<void> _onProvidersRequested(
    MobileMoneyAccountProvidersRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    final editing = _editingNumber;
    emit(MobileMoneyAccountProvidersLoading(base, editingNumber: editing));
    try {
      final catalog = await _repository.providers(
        phoneNumber: event.phoneNumber,
      );
      emit(
        MobileMoneyAccountProvidersLoaded(
          base,
          catalog,
          editingNumber: editing,
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      // Même détection que _loadCatalogAndEmit du bloc paiement : un 404
      // signale un backend sans la route catalogue (ancien contrat, prod
      // gelée sans dony-back #296), pas un aléa réseau à signaler par un
      // bandeau d'erreur.
      if (error is NotFoundException) {
        emit(
          MobileMoneyAccountProvidersUnavailable(base, editingNumber: editing),
        );
        return;
      }
      emit(
        MobileMoneyAccountProvidersError(base, error, editingNumber: editing),
      );
    }
  }

  void _onProvidersCleared(
    MobileMoneyAccountProvidersCleared event,
    Emitter<MobileMoneyAccountState> emit,
  ) {
    final base = _currentAccount;
    if (base != null) {
      emit(MobileMoneyAccountLoaded(base, editingNumber: _editingNumber));
    }
  }

  Future<void> _onProvidersUpdateRequested(
    MobileMoneyAccountProvidersUpdateRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) async {
    final base = _currentAccount ?? _fallbackAccount;
    final editing = _editingNumber;
    emit(MobileMoneyAccountUpdating(base, editingNumber: editing));
    try {
      final account = await _repository.updateProviders(event.providers);
      emit(MobileMoneyAccountLoaded(account));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.mobileMoneyAccountActivated,
          properties: {
            'provider': account.providerLabel ?? 'inconnu',
            'providers_count': account.providers.length,
            'currency': account.currency ?? '',
            'update': true,
          },
        ),
      );
    } catch (e) {
      emit(
        MobileMoneyAccountError(
          unwrapDioError(e),
          account: base,
          editingNumber: editing,
        ),
      );
    }
  }

  void _onChangeNumberRequested(
    MobileMoneyAccountChangeNumberRequested event,
    Emitter<MobileMoneyAccountState> emit,
  ) {
    final base = _currentAccount;
    if (base != null) {
      emit(MobileMoneyAccountLoaded(base, editingNumber: true));
    }
  }

  void _onChangeNumberCancelled(
    MobileMoneyAccountChangeNumberCancelled event,
    Emitter<MobileMoneyAccountState> emit,
  ) {
    final base = _currentAccount;
    if (base != null) {
      emit(MobileMoneyAccountLoaded(base));
    }
  }
}
