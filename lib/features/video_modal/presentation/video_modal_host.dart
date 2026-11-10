import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Délai entre l'arrivée sur l'écran (onglet ou ouverture de l'app) et
/// l'ouverture du modal : la personne voit d'abord l'écran. Pas de délai pour
/// les modals posés devant un formulaire (`VideoModalGate`) : on ne fait pas
/// attendre quelqu'un qui vient de toucher « Publier ».
const kVideoModalOpenDelay = Duration(seconds: 2);

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
class VideoModalHost extends StatefulWidget {
  const VideoModalHost({
    super.key,
    required this.tabIndex,
    required this.child,
    @visibleForTesting this.bloc,
    @visibleForTesting this.hasRealSession,
    @visibleForTesting this.lang,
    @visibleForTesting this.openDelay = kVideoModalOpenDelay,
  });

  /// Onglet affiché par le shell (index de branche du `StatefulShellRoute`).
  final int tabIndex;
  final Widget child;
  final VideoModalBloc? bloc;
  final bool Function()? hasRealSession;
  final String Function()? lang;
  final Duration openDelay;

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
      if (s.status == VideoModalStatus.ready) _schedule();
    });
    _lifecycle = AppLifecycleListener(onResume: _schedule);
    _arm(widget.tabIndex, withAppOpen: !bloc.state.appOpenConsumed);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S'abonne à la route : réessaie quand l'écran redevient le premier plan
    // (feuille de consentement ou de note refermée, page dépilée).
    ModalRoute.of(context);
    _schedule();
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

  @override
  Widget build(BuildContext context) => widget.child;
}
