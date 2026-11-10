import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Ouvre les modals vidéo du shell : `APP_OPEN` au premier écran, puis le
/// déclencheur de chaque onglet affiché (`SEARCH_TAB` … `PROFILE_TAB`).
///
/// Hébergé par `MainShell`, donc après l'inscription et l'onboarding. Les
/// campagnes sont chargées une fois par session ; un déclencheur arrivé
/// pendant qu'une feuille, une boîte de dialogue ou une demande de
/// permission du système est ouverte attend que l'écran redevienne le premier
/// plan. Jamais plus d'un modal par session.
class VideoModalHost extends StatefulWidget {
  const VideoModalHost({
    super.key,
    required this.tabIndex,
    required this.child,
    @visibleForTesting this.bloc,
    @visibleForTesting this.hasRealSession,
    @visibleForTesting this.lang,
  });

  /// Onglet affiché par le shell (index de branche du `StatefulShellRoute`).
  final int tabIndex;
  final Widget child;
  final VideoModalBloc? bloc;
  final bool Function()? hasRealSession;
  final String Function()? lang;

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
        withAppOpen: _pending.contains(VideoModalTrigger.appOpen),
      );
      // Connexion ou déconnexion pendant la session : rechargement si le
      // type de session a changé (le BLoC ignore sinon la demande).
      _load();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }

  void _load() => _bloc?.add(
    VideoModalLoadRequested(lang: _lang, realSession: _realSession),
  );

  void _arm(int tabIndex, {required bool withAppOpen}) {
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
