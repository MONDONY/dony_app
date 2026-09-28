import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_header.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_parcel_sheets.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_track_panel.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validation_toast.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Fabrique du flux caméra. Les tests en injectent une qui n'ouvre pas de
/// vraie caméra ; par défaut, [QrCameraView].
typedef SuiviCameraBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String> onBidId,
      ValueListenable<bool> paused,
      ValueListenable<bool> torchOn,
    );

Widget _defaultCamera(
  BuildContext context,
  ValueChanged<String> onBidId,
  ValueListenable<bool> paused,
  ValueListenable<bool> torchOn,
) => QrCameraView(onBidId: onBidId, paused: paused, torchOn: torchOn);

/// Onglet Suivi : un seul écran, deux usages.
///
/// - « Valider une étape » (voyageur) : caméra en haut, feuille du trajet
///   en dessous. Le QR d'un colis du trajet ouvre l'étape suivante.
/// - « Suivre un colis » : numéro, QR ou « Mes envois », en lecture seule.
///
/// Un utilisateur non voyageur n'a que « Suivre », sans sélecteur ni caméra
/// ouverte (le lecteur QR s'ouvre à la demande).
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key, this.requestedMode, this.cameraBuilder});

  /// Mode imposé par l'URL (`/tracking?mode=suivre`).
  final SuiviMode? requestedMode;

  final SuiviCameraBuilder? cameraBuilder;

  /// Profil voyageur de l'utilisateur connecté, `null` pendant un état
  /// d'authentification transitoire (chargement, erreur d'une mise à jour).
  static bool? _travelerOf(AuthState state) => switch (state) {
    AuthAuthenticated(:final user) => user.isTraveler,
    AuthProfileUpdated(:final user) => user.isTraveler,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    // Un état transitoire ne reconstruit pas l'onglet : sans ce filtre, une
    // erreur de mise à jour du profil le basculait en vue expéditeur et
    // recréait la caméra.
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (_, next) => _travelerOf(next) != null,
      builder: (context, authState) {
        final canValidate = _travelerOf(authState) ?? false;
        // Clé par compte et par profil : devenir voyageur ou changer de
        // compte en cours de session recrée les blocs, donc recharge.
        return KeyedSubtree(
          key: ValueKey<(String?, bool)>((
            authState.currentUserId,
            canValidate,
          )),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SuiviCubit>(
                create: (_) => getIt<SuiviCubit>()
                  ..start(canValidate: canValidate, requested: requestedMode),
              ),
              if (canValidate) ...[
                BlocProvider<ScanHubCubit>(
                  create: (_) => getIt<ScanHubCubit>()..load(),
                ),
                // Fermé avec l'onglet : les validations en attente partent
                // alors aussitôt (SuiviValidationCubit.close).
                BlocProvider<SuiviValidationCubit>(
                  create: (_) => getIt<SuiviValidationCubit>(),
                ),
              ],
            ],
            child: _SuiviBody(
              canValidate: canValidate,
              requestedMode: requestedMode,
              cameraBuilder: cameraBuilder ?? _defaultCamera,
            ),
          ),
        );
      },
    );
  }
}

class _SuiviBody extends StatefulWidget {
  const _SuiviBody({
    required this.canValidate,
    required this.requestedMode,
    required this.cameraBuilder,
  });

  final bool canValidate;
  final SuiviMode? requestedMode;
  final SuiviCameraBuilder cameraBuilder;

  @override
  State<_SuiviBody> createState() => _SuiviBodyState();
}

class _SuiviBodyState extends State<_SuiviBody> {
  final _sheetController = DraggableScrollableController();
  final _sheetExpanded = ValueNotifier<bool>(false);
  final _cameraPaused = ValueNotifier<bool>(false);
  final _torchOn = ValueNotifier<bool>(false);
  final _numberFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  /// Onglet visible et non recouvert par une autre page.
  bool _visible = true;

  // Tailles de la feuille, recalculées à chaque mise en page.
  double _peekSize = 0.45;
  double _maxSize = 0.9;
  double _expandThreshold = 0.7;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetMoved);
    // App en arrière-plan : une validation en attente part tout de suite
    // plutôt que d'attendre un délai que personne ne regarde.
    _lifecycle = AppLifecycleListener(
      onHide: _flushValidations,
      onPause: _flushValidations,
      onResume: () {
        if (_visible) _refresh();
      },
    );
    if (widget.canValidate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SuiviCubit>().resolveDefaultMode(
          context.read<ScanHubCubit>().state,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Onglet caché (IndexedStack du shell) ou page poussée par-dessus :
    // TickerMode est coupé, la caméra aussi.
    final wasVisible = _visible;
    _visible = TickerMode.valuesOf(context).enabled;
    _updatePaused();
    // Onglet quitté ou recouvert : plus personne pour « Annuler ».
    if (!_visible) _flushValidations();
    // Retour sur l'onglet : l'IndexedStack du shell l'a gardé vivant, ses
    // données datent de sa première ouverture (trajet publié, demande
    // acceptée ailleurs depuis). Recette Redmi : « Rien à valider » restait
    // affiché jusqu'au redémarrage de l'app.
    if (_visible && !wasVisible) _refresh();
  }

  /// Rafraîchissement silencieux au retour sur l'onglet ou dans l'app.
  void _refresh() {
    if (!mounted) return;
    _reloadTrips();
    unawaited(context.read<SuiviCubit>().refreshShipments());
  }

  void _flushValidations() {
    if (!widget.canValidate || !mounted) return;
    unawaited(context.read<SuiviValidationCubit>().flush());
  }

  Set<String> get _pendingBidIds => widget.canValidate
      ? context.read<SuiviValidationCubit>().state.pendingBidIds
      : const {};

  @override
  void didUpdateWidget(covariant _SuiviBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestedMode != oldWidget.requestedMode) {
      context.read<SuiviCubit>().applyRequestedMode(widget.requestedMode);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _numberFocus.dispose();
    _sheetController.removeListener(_onSheetMoved);
    _sheetController.dispose();
    _sheetExpanded.dispose();
    _cameraPaused.dispose();
    _torchOn.dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    if (!_sheetController.isAttached) return;
    _sheetExpanded.value = _sheetController.size > _expandThreshold;
    _updatePaused();
  }

  void _updatePaused() {
    final busy = context.read<SuiviCubit>().state.busy;
    _cameraPaused.value = !_visible || busy || _sheetExpanded.value;
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    unawaited(
      _sheetController.animateTo(
        _peekSize,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _onBidId(String bidId) {
    context.read<SuiviCubit>().onQrScanned(
      bidId,
      widget.canValidate ? context.read<ScanHubCubit>().state : null,
      pendingBidIds: _pendingBidIds,
    );
  }

  /// Rafraîchit les colis sans démonter la caméra (retour d'une validation).
  void _reloadTrips() {
    if (!widget.canValidate) return;
    unawaited(context.read<ScanHubCubit>().load(silent: true));
  }

  Future<void> _handleEffect(SuiviEffect effect) async {
    final cubit = context.read<SuiviCubit>();
    switch (effect) {
      case SuiviValidateStep():
        await _validateStep(effect);
        if (!mounted) return;
        cubit.releaseScan();
      case SuiviTransitNeedsDepart(:final bid):
        DonySnackbar.show(
          context,
          message: context.l10n.suiviTransitNeedsDepart(suiviParcelLabel(bid)),
        );
        cubit.releaseScan();
      case SuiviTransitAlreadyDone(:final bid):
        DonySnackbar.show(
          context,
          message: context.l10n.suiviTransitAlreadyDone(suiviParcelLabel(bid)),
        );
        cubit.releaseScan();
      case SuiviStepPending(:final bid):
        DonySnackbar.show(
          context,
          message: context.l10n.suiviStepAlreadyPending(suiviParcelLabel(bid)),
        );
        cubit.releaseScan();
      case SuiviStepsAllDone(:final bid):
        DonySnackbar.show(
          context,
          message: context.l10n.suiviAllStepsDone(suiviParcelLabel(bid)),
        );
        cubit.releaseScan();
      case SuiviParcelOnOtherTrip(:final bid, :final trip):
        final hub = context.read<ScanHubCubit>();
        final switchTrip = await showSuiviOtherTripSheet(
          context,
          bid: bid,
          trip: trip,
        );
        if (!mounted) return;
        if (switchTrip ?? false) {
          unawaited(hub.selectTrip(trip.id, source: 'other_trip'));
        }
        cubit.releaseScan();
      case SuiviParcelUnknown(:final bidId):
        final follow = await showSuiviUnknownParcelSheet(context);
        if (!mounted) return;
        if (follow ?? false) {
          cubit.followParcel(bidId);
        } else {
          cubit.releaseScan();
        }
      case SuiviShowTimeline(
        :final bidId,
        :final corridor,
        :final arrivalInstructions,
      ):
        await showTrackingTimelineSheet(
          context,
          bidId: bidId,
          corridor: corridor,
          arrivalInstructions: arrivalInstructions,
        );
        if (!mounted) return;
        cubit.releaseScan();
    }
  }

  /// Étape d'un colis du trajet : récapitulatif si le colis vient d'un
  /// numéro, puis photo si elle est exigée, puis bandeau « Annuler » avant
  /// l'envoi. L'arrivée garde son parcours photo puis code.
  Future<void> _validateStep(SuiviValidateStep effect) async {
    final SuiviValidateStep(:bid, :step, :method) = effect;
    final hub = context.read<ScanHubCubit>();
    final validations = context.read<SuiviValidationCubit>();
    final label = suiviParcelLabel(bid);
    if (method == ScanMethod.manual) {
      final hubState = hub.state;
      if (hubState is! ScanHubLoaded) return;
      final go = await showSuiviNumberRecapSheet(
        context,
        bid: bid,
        trip: hubState.selectedTrip,
        step: step,
      );
      if (!mounted || go != true) return;
    }
    if (step == 'ARRIVEE') {
      await context.push<void>(
        '/tracking/scan/photo',
        extra: <String, dynamic>{
          'bidId': bid.id,
          'etape': step,
          'packageLabel': label,
          'scanMethod': method,
        },
      );
      if (mounted) _reloadTrips();
      return;
    }
    ScanPhotoResult? photo;
    if (effect.photoRequired) {
      photo = await context.push<ScanPhotoResult>(
        '/tracking/scan/photo',
        extra: <String, dynamic>{
          'bidId': bid.id,
          'etape': step,
          'packageLabel': label,
          'returnResult': true,
        },
      );
      if (!mounted || photo == null) return;
    }
    validations.schedule(
      bidId: bid.id,
      step: step,
      parcelLabel: label,
      method: method,
      photoPath: photo?.photoPath,
      position: photo?.position,
    );
  }

  /// Envoi d'une validation terminé : message si elle n'est pas partie
  /// directement, puis colis et derniers scans rechargés.
  void _onValidationOutcome(SuiviValidationOutcome outcome) {
    final l = context.l10n;
    final step = trackingStepLabel(l, outcome.step);
    switch (outcome) {
      case SuiviValidationSent():
        break;
      case SuiviValidationQueued(:final parcelLabel):
        DonySnackbar.show(
          context,
          message: l.suiviValidationQueued(step, parcelLabel),
          type: DonySnackbarType.warning,
        );
      case SuiviValidationFailed(:final parcelLabel, :final error):
        DonySnackbar.show(
          context,
          title: l.suiviValidationFailed(step, parcelLabel),
          message: ErrorPresenter.resolve(error, l10n: l).message,
          type: DonySnackbarType.error,
        );
    }
    _reloadTrips();
  }

  /// « QR illisible ? Saisir le numéro » : feuille dépliée sur le champ.
  Future<void> _enterNumber() async {
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        _maxSize,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    // Le champ n'existe qu'une fois la feuille dépliée : focus à la frame
    // suivante.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _numberFocus.requestFocus();
    });
  }

  void _submitNumber(String raw) {
    unawaited(
      context.read<SuiviCubit>().validateNumber(
        raw,
        context.read<ScanHubCubit>().state,
        pendingBidIds: _pendingBidIds,
      ),
    );
  }

  /// « Forcer une étape ». Transit (facultatif) : le prochain colis scanné
  /// ou saisi le valide, la feuille se replie sur la caméra. Départ et
  /// remise passent par l'identification.
  Future<void> _forceStep() async {
    final cubit = context.read<SuiviCubit>();
    final step = await showSuiviForceStepSheet(context);
    if (!mounted || step == null) return;
    if (step == 'TRANSIT') {
      cubit.forceTransit();
      _collapseSheet();
      return;
    }
    await _openIdentify(step);
  }

  Future<void> _openIdentify(String? step) async {
    final cubit = context.read<SuiviCubit>();
    if (cubit.state.busy) return;
    // Pas de scan ni de caméra pendant la saisie : l'écran d'identification
    // ouvre son propre lecteur.
    cubit.holdScans();
    await context.push<void>(
      '/tracking/scan/identify',
      extra: <String, dynamic>{'etape': step, 'focusNumber': step != null},
    );
    if (!mounted) return;
    _reloadTrips();
    cubit.releaseScan();
  }

  Future<void> _openQrPicker() async {
    final bidId = await context.push<String?>('/tracking/scan/qr-picker');
    if (!mounted || bidId == null) return;
    _onBidId(bidId);
  }

  void _openTripPicker(ScanHubLoaded hub) {
    // La feuille vit sur le navigateur racine, hors des providers : on
    // capture le cubit ici.
    final cubit = context.read<ScanHubCubit>();
    unawaited(
      DonyBottomSheet.show<void>(
        context,
        title: context.l10n.scanChooseTripTitle,
        child: SuiviTripPicker(hub: hub, onSelect: cubit.selectTrip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SuiviCubit, SuiviState>(
          listenWhen: (a, b) => a.effectId != b.effectId && b.effect != null,
          listener: (_, state) => unawaited(_handleEffect(state.effect!)),
        ),
        BlocListener<SuiviCubit, SuiviState>(
          listenWhen: (a, b) => a.busy != b.busy,
          listener: (_, _) => _updatePaused(),
        ),
        if (widget.canValidate) ...[
          BlocListener<ScanHubCubit, ScanHubState>(
            listener: (context, hub) =>
                context.read<SuiviCubit>().resolveDefaultMode(hub),
          ),
          BlocListener<SuiviValidationCubit, SuiviValidationState>(
            listenWhen: (a, b) =>
                a.outcomeId != b.outcomeId && b.outcome != null,
            listener: (_, state) => _onValidationOutcome(state.outcome!),
          ),
        ],
      ],
      child: BlocBuilder<SuiviCubit, SuiviState>(
        buildWhen: (a, b) => a.mode != b.mode || a.canValidate != b.canValidate,
        builder: (context, state) {
          if (!state.canValidate) return _senderLayout();
          final mode = state.mode;
          if (mode == null) return _lightLayout(null, const _Loading());
          // Un seul BlocBuilder pour les deux modes : la mise en page caméra
          // garde sa place dans l'arbre d'un mode à l'autre, et avec elle la
          // feuille et son contrôleur.
          return BlocBuilder<ScanHubCubit, ScanHubState>(
            builder: (context, hub) => switch (hub) {
              _ when mode == SuiviMode.suivre => _cameraLayout(mode, null),
              ScanHubLoading() => _lightLayout(mode, const _Loading()),
              ScanHubError(:final error) => _lightLayout(
                mode,
                DonyEmptyState(
                  mascotte: DonyMascotteType.erreurLegere,
                  type: DonyEmptyStateType.error,
                  title: context.l10n.scanLoadTripsErrorTitle,
                  description: ErrorPresenter.resolve(
                    error,
                    l10n: context.l10n,
                  ).message,
                  actionLabel: context.l10n.commonRetry,
                  onAction: () => context.read<ScanHubCubit>().load(),
                ),
              ),
              ScanHubEmpty() => _lightLayout(
                mode,
                DonyEmptyState(
                  iconAsset: 'scan-line',
                  title: context.l10n.suiviNothingToValidateTitle,
                  description: context.l10n.suiviNothingToValidateBody,
                  actionLabel: context.l10n.scanViewMyTripsAction,
                  onAction: () => context.push('/announcements/trips'),
                ),
              ),
              ScanHubLoaded() => _cameraLayout(mode, hub),
            },
          );
        },
      ),
    );
  }

  void _selectMode(SuiviMode mode) =>
      context.read<SuiviCubit>().selectMode(mode);

  /// Expéditeur (non voyageur) : pas de caméra ouverte, pas de sélecteur.
  Widget _senderLayout() {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SuiviHeader(onDark: false),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.sm,
                  DonySpacing.lg,
                  100 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [SuiviTrackPanel(onScanQr: _openQrPicker)],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOutCubic),
    );
  }

  /// Voyageur hors caméra : chargement, erreur, rien à valider.
  Widget _lightLayout(SuiviMode? mode, Widget body) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SuiviHeader(onDark: false, mode: mode, onModeSelected: _selectMode),
            Expanded(
              child: Center(child: SingleChildScrollView(child: body)),
            ),
          ],
        ),
      ),
    );
  }

  /// Caméra en haut, feuille persistante en dessous.
  Widget _cameraLayout(SuiviMode mode, ScanHubLoaded? hub) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      backgroundColor: DonyColors.neutral900,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: SuiviHeader(
              onDark: true,
              mode: mode,
              onModeSelected: _selectMode,
              torchOn: _torchOn,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                const frame = 180.0;
                // Zone caméra = cadre + consigne sur deux lignes, qui grandit
                // avec le texte : la feuille se replie d'autant plus bas.
                final cameraZone =
                    frame +
                    DonySpacing.xl * 2 +
                    44 * textScale.clamp(1.0, 2.0).toDouble();
                final peek = ((height - cameraZone) / height)
                    .clamp(0.3, 0.7)
                    .toDouble();
                final strip = 56 * textScale.clamp(1.0, 1.6).toDouble();
                final max = math.max(peek + 0.05, (height - strip) / height);
                _peekSize = peek;
                _maxSize = max;
                _expandThreshold = peek + (max - peek) / 2;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: widget.cameraBuilder(
                        context,
                        _onBidId,
                        _cameraPaused,
                        _torchOn,
                      ),
                    ),
                    Positioned(
                      top: DonySpacing.base,
                      left: DonySpacing.lg,
                      right: DonySpacing.lg,
                      child: Column(
                        children: [
                          const QrScanFrame(
                            size: frame,
                            color: DonyColors.blue300,
                          ),
                          const SizedBox(height: DonySpacing.base),
                          BlocBuilder<SuiviCubit, SuiviState>(
                            buildWhen: (a, b) => a.forcedStep != b.forcedStep,
                            builder: (context, state) => Text(
                              mode == SuiviMode.suivre
                                  ? l.suiviTrackCameraHint
                                  : state.forcedStep == 'TRANSIT'
                                  ? l.suiviForcedTransitCameraHint
                                  : l.suiviValidateCameraHint,
                              key: const Key('suivi-camera-hint'),
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: DonyColors.neutral0.withValues(
                                  alpha: 0.85,
                                ),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: strip,
                      child: _PausedStrip(
                        expanded: _sheetExpanded,
                        onScan: _collapseSheet,
                      ),
                    ),
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: peek,
                      minChildSize: peek,
                      maxChildSize: max,
                      snap: true,
                      builder: (context, scroll) => _SheetSurface(
                        scrollController: scroll,
                        child: hub != null
                            ? SuiviValidateContent(
                                hub: hub,
                                expanded: _sheetExpanded,
                                numberFocus: _numberFocus,
                                onChangeTrip: () => _openTripPicker(hub),
                                onValidateParcel: (BidModel _, String step) =>
                                    _openIdentify(step),
                                onEnterNumber: _enterNumber,
                                onSubmitNumber: _submitNumber,
                                onForceStep: _forceStep,
                              )
                            : const SuiviTrackPanel(),
                      ),
                    ),
                    // Validations rapides en attente, au-dessus de la
                    // feuille : sous le cadre, comme la maquette. Feuille
                    // dépliée : en bas, pour ne pas masquer le champ numéro.
                    if (hub != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: _sheetExpanded,
                        builder: (context, expanded, child) => Positioned(
                          top: expanded
                              ? null
                              : DonySpacing.base + frame + DonySpacing.base,
                          bottom: expanded
                              ? DonySpacing.base +
                                    MediaQuery.paddingOf(context).bottom
                              : null,
                          left: DonySpacing.base,
                          right: DonySpacing.base,
                          child: child!,
                        ),
                        child: const SuiviPendingValidations(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DonySpacing.xxl),
    child: CircularProgressIndicator(
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// Bandeau visible quand la feuille est tirée en haut : la caméra est en
/// pause, « Scanner » la replie.
class _PausedStrip extends StatelessWidget {
  const _PausedStrip({required this.expanded, required this.onScan});

  final ValueListenable<bool> expanded;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) {
        if (!isExpanded) return const SizedBox.shrink();
        return ColoredBox(
          color: DonyColors.neutral900,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DonyColors.blue300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    l.suiviCameraPaused,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(color: DonyColors.neutral0),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('suivi-resume-scan'),
                  onPressed: onScan,
                  icon: const DonyIcon(
                    'scan-line',
                    size: 16,
                    color: DonyColors.ink800,
                  ),
                  label: Text(l.suiviResumeScan),
                  style: FilledButton.styleFrom(
                    backgroundColor: DonyColors.neutral0,
                    foregroundColor: DonyColors.ink800,
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fond, poignée et défilement de la feuille persistante.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.scrollController, required this.child});

  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Material plutôt qu'un DecoratedBox : les tuiles (ExpansionTile) et
    // les InkWell de la feuille y peignent leur fond et leurs effets.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(DonyRadius.sheet),
      ),
      child: ListView(
        key: const Key('suivi-sheet'),
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          100 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
