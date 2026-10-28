import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Moment d'où le consentement est demandé, valeur analytics comprise.
enum TrackingConsentSource {
  acceptedParcel('accepted_parcel'),
  tripScreen('trip_screen'),
  depart('depart'),
  settings('settings');

  const TrackingConsentSource(this.wire);

  final String wire;
}

/// Issue d'un changement depuis les réglages.
enum TrackingConsentOutcome { active, inactive, openedSystemSettings }

/// Réponse mémorisée : `none` tant que la feuille n'a pas été montrée.
enum TrackingConsentAnswer { none, granted, declined }

class TrackingConsentState extends Equatable {
  const TrackingConsentState({
    this.answer = TrackingConsentAnswer.none,
    this.osGranted = false,
    this.relevant = true,
  });

  final TrackingConsentAnswer answer;

  /// Autorisation de position accordée dans le système.
  final bool osGranted;

  /// Faux seulement quand les rôles du compte sont connus et sans
  /// `TRAVELER` : le réglage n'a alors aucun sens à l'écran.
  final bool relevant;

  /// Partage actif : accepté dans l'app ET autorisé dans le système.
  bool get enabled => answer == TrackingConsentAnswer.granted && osGranted;

  @override
  List<Object?> get props => [answer, osGranted, relevant];
}

/// Consentement du voyageur au partage de l'avancée de son trajet.
///
/// La feuille d'explication n'est montrée qu'une fois : « Pas maintenant » ou
/// sa fermeture valent refus mémorisé, et un refus ne bloque jamais rien.
/// Le cubit possède la décision et sa persistance ; la feuille est affichée
/// par [showSheet] (rend `true` pour Autoriser, `false` pour Pas maintenant,
/// `null` si elle est fermée par un geste).
class TrackingConsentCubit extends Cubit<TrackingConsentState> {
  TrackingConsentCubit({
    required Box<dynamic> Function() box,
    required ScanLocator locator,
    required AnalyticsService analytics,
    required Future<bool?> Function(BuildContext context) showSheet,
  }) : _box = box,
       _locator = locator,
       _analytics = analytics,
       _showSheet = showSheet,
       super(const TrackingConsentState());

  final Box<dynamic> Function() _box;
  final ScanLocator _locator;
  final AnalyticsService _analytics;
  final Future<bool?> Function(BuildContext context) _showSheet;

  List<String>? _roles;
  bool _asking = false;

  /// Rôles du compte connecté, `null` si inconnus (alimenté par l'app depuis
  /// l'état d'authentification).
  ///
  /// `null` veut dire « rôles inconnus » (état d'authentification transitoire :
  /// chargement, erreur) : le réglage reste affiché, ni la réponse, ni
  /// l'autorisation système, ni la garde de la feuille ne sont touchées.
  void updateRoles(List<String>? roles) {
    _roles = roles;
    final relevant = roles == null || roles.contains('TRAVELER');
    if (relevant == state.relevant) return;
    emit(
      TrackingConsentState(
        answer: state.answer,
        osGranted: state.osGranted,
        relevant: relevant,
      ),
    );
  }

  /// Vraie déconnexion ou changement de compte (le Hive est vidé): l'état en
  /// mémoire du compte précédent est remis à zéro. Une seule feuille ne peut
  /// plus être ouverte de toute façon: la garde est relâchée.
  void onLoggedOut() {
    _roles = null;
    _asking = false;
    emit(const TrackingConsentState());
  }

  TrackingConsentAnswer _stored() {
    try {
      return switch (_box().get(HiveService.kTrackingConsent)) {
        'granted' => TrackingConsentAnswer.granted,
        'declined' => TrackingConsentAnswer.declined,
        _ => TrackingConsentAnswer.none,
      };
    } catch (_) {
      return TrackingConsentAnswer.none;
    }
  }

  /// Lecture synchrone du consentement mémorisé : vrai seulement si le
  /// voyageur a répondu « Autoriser ». C'est la seule porte avant tout envoi
  /// de position : l'autorisation du système seule ne suffit jamais (elle est
  /// souvent déjà accordée par le scan d'un colis), et un refus ou une absence
  /// de réponse ne doivent rien laisser partir.
  bool get sharingGranted => _stored() == TrackingConsentAnswer.granted;

  Future<void> _store(bool granted) async {
    try {
      await _box().put(
        HiveService.kTrackingConsent,
        granted ? 'granted' : 'declined',
      );
    } catch (_) {
      // Préférence de confort : un échec d'écriture redemande au pire une fois.
    }
  }

  /// Relit la réponse mémorisée et l'autorisation du système.
  Future<void> refresh() async {
    final os = await _locator.isPermissionGranted();
    emit(
      TrackingConsentState(
        answer: _stored(),
        osGranted: os,
        relevant: state.relevant,
      ),
    );
  }

  /// Point d'entrée unique, appelable depuis l'acceptation d'un colis, le
  /// trajet ouvert dans la fenêtre de suivi ou le premier « Je pars ».
  ///
  /// Montre la feuille au plus une fois ; une réponse déjà donnée est
  /// simplement rendue. Rend `true` si le partage est actif (accepté et
  /// autorisé dans le système). Ne lève jamais et ne bloque aucun parcours.
  Future<bool> ensureAsked(
    BuildContext context, {
    required TrackingConsentSource source,
  }) async {
    if (_asking) return false;
    if (_stored() != TrackingConsentAnswer.none) {
      await refresh();
      return state.enabled;
    }
    return _ask(context, source);
  }

  /// Acceptation d'un colis : ne concerne que le voyageur (rôle `TRAVELER`
  /// connu ou encore inconnu).
  Future<bool> onParcelAccepted(BuildContext context) async {
    final roles = _roles;
    if (roles != null && !roles.contains('TRAVELER')) return false;
    return ensureAsked(context, source: TrackingConsentSource.acceptedParcel);
  }

  /// Interrupteur des réglages. Activer relance le parcours (feuille puis
  /// demande du système), ou ouvre les réglages du téléphone si le système ne
  /// redemandera plus. Désactiver mémorise un refus (l'autorisation du
  /// système reste à l'utilisateur).
  Future<TrackingConsentOutcome> setEnabled(
    BuildContext context,
    bool enabled,
  ) async {
    if (_asking) return TrackingConsentOutcome.inactive;
    if (!enabled) {
      await _store(false);
      await refresh();
      _logAnswered(granted: false, source: TrackingConsentSource.settings);
      return TrackingConsentOutcome.inactive;
    }
    if (await _locator.isPermanentlyDenied()) {
      await _locator.openSettings();
      return TrackingConsentOutcome.openedSystemSettings;
    }
    if (!context.mounted) return TrackingConsentOutcome.inactive;
    return await _ask(context, TrackingConsentSource.settings)
        ? TrackingConsentOutcome.active
        : TrackingConsentOutcome.inactive;
  }

  Future<bool> _ask(BuildContext context, TrackingConsentSource source) async {
    if (!context.mounted) return false;
    _asking = true;
    try {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.trackingConsentSheetShown,
          properties: {'source': source.wire},
        ),
      );
      final accepted = await _showSheet(context) ?? false;
      final granted = accepted && await _locator.requestPermission();
      await _store(granted);
      await refresh();
      _logAnswered(granted: granted, source: source);
      return granted;
    } catch (_) {
      return false;
    } finally {
      _asking = false;
    }
  }

  void _logAnswered({
    required bool granted,
    required TrackingConsentSource source,
  }) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.trackingConsentAnswered,
        properties: {'granted': granted, 'source': source.wire},
      ),
    );
  }
}
