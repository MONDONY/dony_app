import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Délai entre l'arrivée sur l'écran (onglet ou ouverture de l'app) et
/// l'ouverture du modal : la personne voit d'abord l'écran. Pas de délai pour
/// les modals posés devant un formulaire (`VideoModalGate`) : on ne fait pas
/// attendre quelqu'un qui vient de toucher « Publier ».
const kVideoModalOpenDelay = Duration(seconds: 2);

/// Un moment d'action qui n'a pas pu s'ouvrir (écran recouvert, saisie en
/// cours) est réessayé à cet intervalle, puis abandonné après
/// [kVideoModalMomentMaxAge] : un modal « paiement réussi » n'a plus de sens
/// quelques minutes plus tard.
const kVideoModalMomentRetry = Duration(seconds: 1);
const kVideoModalMomentMaxAge = Duration(minutes: 2);

/// Ouvre les modals vidéo du shell : `APP_OPEN` au premier écran, puis le
/// déclencheur de chaque onglet affiché (`SEARCH_TAB` … `PROFILE_TAB`).
///
/// Hébergé par `MainShell`, donc après l'inscription et l'onboarding. Les
/// campagnes sont chargées une fois par session ; un déclencheur arrivé
/// pendant qu'une feuille, une boîte de dialogue ou une demande de
/// permission du système est ouverte attend que l'écran redevienne le premier
/// plan. Le modal s'ouvre [kVideoModalOpenDelay] après l'arrivée sur l'écran,
/// une fois revérifié que l'écran est toujours le premier plan. Jamais plus
/// d'un modal par session.
///
/// Écoute aussi les moments d'action (`VideoModalMoments`) : livraison,
/// paiement, publication, recherche, favori, formulaire quitté… Mêmes règles
/// que les écrans : un modal par lancement, jamais par-dessus une autre
/// fenêtre ni pendant une saisie, [kVideoModalOpenDelay] après le moment, avec
/// revérification du premier plan. Un moment ouvre le modal sur l'écran qui
/// l'a émis tant qu'il est monté, sinon sur l'écran du shell.
class VideoModalHost extends StatefulWidget {
  const VideoModalHost({
    super.key,
    required this.tabIndex,
    required this.child,
    @visibleForTesting this.bloc,
    @visibleForTesting this.hasRealSession,
    @visibleForTesting this.lang,
    @visibleForTesting this.openDelay = kVideoModalOpenDelay,
    @visibleForTesting this.moments,
    @visibleForTesting this.momentRetry = kVideoModalMomentRetry,
    @visibleForTesting this.momentMaxAge = kVideoModalMomentMaxAge,
    @visibleForTesting this.clock,
  });

  /// Onglet affiché par le shell (index de branche du `StatefulShellRoute`).
  final int tabIndex;
  final Widget child;
  final VideoModalBloc? bloc;
  final bool Function()? hasRealSession;
  final String Function()? lang;
  final Duration openDelay;
  final VideoModalMoments? moments;
  final Duration momentRetry;
  final Duration momentMaxAge;
  final DateTime Function()? clock;

  @override
  State<VideoModalHost> createState() => _VideoModalHostState();
}

class _VideoModalHostState extends State<VideoModalHost> {
  VideoModalBloc? _bloc;
  StreamSubscription<VideoModalState>? _subscription;
  AppLifecycleListener? _lifecycle;

  /// Déclencheurs survenus et pas encore évalués (écran pas au premier plan,
  /// campagnes pas encore chargées).
  Set<VideoModalTrigger> _pending = {};
  bool _scheduled = false;

  /// Déclencheurs évalués dont le modal attend la fin du délai d'ouverture.
  Timer? _delayTimer;
  Set<VideoModalTrigger> _delayed = {};

  /// Moments d'action émis et pas encore ouverts, du plus ancien au plus
  /// récent.
  StreamSubscription<VideoModalMomentSignal>? _momentSub;
  final List<VideoModalMomentSignal> _moments = [];
  bool _momentScheduled = false;
  Timer? _momentTimer;
  Timer? _momentRetryTimer;

  /// Au plus ce nombre de moments en attente : les plus anciens partent.
  static const _maxQueuedMoments = 8;

  VideoModalMoments get _momentService =>
      widget.moments ?? VideoModalMoments.instance;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  bool get _realSession =>
      (widget.hasRealSession ??
      () => getItSafe<FirebaseSessionProbe>()?.hasRealSession ?? false)();

  String get _lang => (widget.lang ?? () => AppL10n.localeName)();

  @override
  void initState() {
    super.initState();
    final bloc = widget.bloc ?? getItSafe<VideoModalBloc>();
    if (bloc == null || bloc.isClosed) return;
    _bloc = bloc;
    _subscription = bloc.stream.listen((s) {
      if (s.status == VideoModalStatus.ready) {
        _schedule();
        _scheduleMoments();
      }
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _schedule();
        _scheduleMoments();
      },
    );
    _momentSub = _momentService.signals.listen(_onMoment);
    _arm(widget.tabIndex, withAppOpen: !bloc.state.appOpenConsumed);
    _load();
    // Première ouverture après un changement de version : le moment attend
    // que les campagnes soient chargées.
    unawaited(_momentService.checkAppUpdated());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S'abonne à la route : réessaie quand l'écran redevient le premier plan
    // (feuille de consentement ou de note refermée, page dépilée).
    ModalRoute.of(context);
    _schedule();
    _scheduleMoments();
  }

  @override
  void didUpdateWidget(VideoModalHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      _arm(
        widget.tabIndex,
        withAppOpen:
            _pending.contains(VideoModalTrigger.appOpen) ||
            _delayed.contains(VideoModalTrigger.appOpen),
      );
      // Connexion ou déconnexion pendant la session : rechargement si le
      // type de session a changé (le BLoC ignore sinon la demande).
      _load();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _momentTimer?.cancel();
    _momentRetryTimer?.cancel();
    unawaited(_momentSub?.cancel());
    unawaited(_subscription?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }

  void _load() => _bloc?.add(
    VideoModalLoadRequested(lang: _lang, realSession: _realSession),
  );

  void _arm(int tabIndex, {required bool withAppOpen}) {
    // L'écran a changé : le délai repart à zéro sur le nouvel écran.
    _delayTimer?.cancel();
    _delayTimer = null;
    _delayed = {};
    final tab = VideoModalTrigger.forShellTab(tabIndex);
    _pending = {if (withAppOpen) VideoModalTrigger.appOpen, ?tab};
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _pending.isEmpty || _bloc == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _tryShow();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _tryShow() {
    final bloc = _bloc;
    if (!mounted || bloc == null || bloc.isClosed || _pending.isEmpty) return;
    final state = bloc.state;
    if (state.shownThisSession) {
      _pending = {};
      return;
    }
    if (state.status != VideoModalStatus.ready) return;
    // Campagnes chargées pour un autre type de session (connexion pendant la
    // session) ou une autre langue : on recharge et on attend.
    if (state.loadedForRealSession != _realSession ||
        state.loadedLang != _lang) {
      _load();
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!isVideoModalFrontmost(context)) return;
    final triggers = _pending;
    _pending = {};
    if (triggers.contains(VideoModalTrigger.appOpen)) {
      bloc.add(const VideoModalAppOpenConsumedRequested());
    }
    if (state.candidateFor(triggers) == null) return;
    _delayTimer?.cancel();
    _delayed = triggers;
    final tab = widget.tabIndex;
    _delayTimer = Timer(widget.openDelay, () => _afterDelay(triggers, tab));
  }

  /// Fin du délai : revérifie que rien n'a changé (écran, session, autre
  /// fenêtre ouverte) avant d'ouvrir le modal. Un écran passé au second plan
  /// remet les déclencheurs en attente : le délai repartira à son retour.
  void _afterDelay(Set<VideoModalTrigger> triggers, int tab) {
    _delayTimer = null;
    _delayed = {};
    final bloc = _bloc;
    if (!mounted || bloc == null || bloc.isClosed) return;
    // Autre onglet : `_arm` a déjà repris la main.
    if (widget.tabIndex != tab) return;
    final state = bloc.state;
    if (state.shownThisSession) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final sameSession =
        state.status == VideoModalStatus.ready &&
        state.loadedForRealSession == _realSession &&
        state.loadedLang == _lang;
    if (!sameSession ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        !isVideoModalFrontmost(context)) {
      _pending = {..._pending, ...triggers};
      _schedule();
      return;
    }
    final campaign = state.candidateFor(triggers);
    if (campaign == null) return;
    final trigger = triggers.firstWhere(
      (t) => t != VideoModalTrigger.appOpen && campaign.triggers.contains(t),
      orElse: () => VideoModalTrigger.appOpen,
    );
    unawaited(
      VideoModalPresenter.present(
        context,
        bloc: bloc,
        campaign: campaign,
        trigger: trigger,
      ),
    );
  }

  // ── Moments d'action ──────────────────────────────────────────────────────

  void _onMoment(VideoModalMomentSignal signal) {
    if (!mounted || _bloc == null) return;
    // Un paiement réussi après un échec : le modal d'échec n'a plus lieu.
    if (signal.moment.trigger == VideoModalTrigger.paymentSucceeded) {
      _moments.removeWhere(
        (s) => s.moment.trigger == VideoModalTrigger.paymentFailed,
      );
    }
    // Le même moment déjà en attente (recherche relancée, favori rebasculé).
    if (_moments.any((s) => s.moment == signal.moment)) return;
    _moments.add(signal);
    if (_moments.length > _maxQueuedMoments) _moments.removeAt(0);
    _scheduleMoments();
  }

  void _scheduleMoments() {
    if (_momentScheduled || _moments.isEmpty || _bloc == null) return;
    _momentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _momentScheduled = false;
      _tryShowMoments();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _tryShowMoments() {
    final bloc = _bloc;
    if (!mounted || bloc == null || bloc.isClosed || _moments.isEmpty) return;
    final now = _now();
    _moments.removeWhere(
      (s) => now.difference(s.emittedAt) > widget.momentMaxAge,
    );
    final state = bloc.state;
    if (state.shownThisSession) {
      _moments.clear();
      return;
    }
    // Campagnes pas encore prêtes : l'état `ready` relancera l'évaluation.
    if (state.status != VideoModalStatus.ready) return;
    if (state.loadedForRealSession != _realSession ||
        state.loadedLang != _lang) {
      _load();
      return;
    }
    // Aucune campagne pour ce moment (déclencheur, seuil, corridor) : rien
    // n'est à attendre.
    _moments.removeWhere((s) => state.candidateForMoment(s.moment) == null);
    if (_moments.isEmpty) return;
    if (_momentTimer != null) return;
    _momentRetryTimer?.cancel();
    _momentRetryTimer = null;
    if (_pickMoment(state) != null) {
      _momentTimer = Timer(widget.openDelay, _afterMomentDelay);
    } else {
      // Écran recouvert, saisie en cours ou app en arrière-plan : on réessaie.
      _momentRetryTimer = Timer(widget.momentRetry, () {
        _momentRetryTimer = null;
        _tryShowMoments();
      });
    }
  }

  /// Fin du délai : revérifie que rien n'a changé avant d'ouvrir le modal.
  void _afterMomentDelay() {
    _momentTimer = null;
    final bloc = _bloc;
    if (!mounted || bloc == null || bloc.isClosed) return;
    final state = bloc.state;
    if (state.shownThisSession) {
      _moments.clear();
      return;
    }
    final sameSession =
        state.status == VideoModalStatus.ready &&
        state.loadedForRealSession == _realSession &&
        state.loadedLang == _lang;
    final pick = sameSession ? _pickMoment(state) : null;
    if (pick == null) {
      _tryShowMoments();
      return;
    }
    _moments.remove(pick.signal);
    unawaited(_presentMoment(bloc, pick));
  }

  Future<void> _presentMoment(
    VideoModalBloc bloc,
    ({
      VideoModalMomentSignal signal,
      BuildContext context,
      VideoModalCampaign campaign,
    })
    pick,
  ) async {
    final moment = pick.signal.moment;
    final service = _momentService;
    await VideoModalPresenter.present(
      pick.context,
      bloc: bloc,
      campaign: pick.campaign,
      trigger: moment.trigger,
    );
    // Compteur de consultations remis à zéro une fois le modal affiché.
    final tripId = moment.tripId;
    if (tripId != null && !bloc.isClosed && bloc.state.shownThisSession) {
      unawaited(service.resetTripViews(tripId));
    }
  }

  /// Le moment à ouvrir maintenant : parmi ceux dont l'écran (celui qui l'a
  /// émis tant qu'il est monté, sinon le shell) est au premier plan, celui de
  /// la campagne la plus prioritaire, à égalité le plus ancien. `null` si
  /// l'app n'est pas au premier plan, si la personne saisit du texte ou si
  /// aucun écran n'est libre.
  ({
    VideoModalMomentSignal signal,
    BuildContext context,
    VideoModalCampaign campaign,
  })?
  _pickMoment(VideoModalState state) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return null;
    }
    if (isVideoModalUserTyping()) return null;
    ({
      VideoModalMomentSignal signal,
      BuildContext context,
      VideoModalCampaign campaign,
    })?
    best;
    for (final signal in _moments) {
      final campaign = state.candidateForMoment(signal.moment);
      if (campaign == null) continue;
      final origin = signal.origin;
      final BuildContext? target = origin != null && origin.mounted
          ? origin
          : (mounted ? context : null);
      if (target == null || !isVideoModalFrontmost(target)) continue;
      if (best == null || campaign.priority > best.campaign.priority) {
        best = (signal: signal, context: target, campaign: campaign);
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
