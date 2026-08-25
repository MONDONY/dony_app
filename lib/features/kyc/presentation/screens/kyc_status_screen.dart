import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/kyc_rejection_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran de statut KYC, à double entrée : le parcours d'onboarding (étape
/// identité, spec §2) et le profil (vérifier son identité à tout moment,
/// hors inscription). [progress] distingue les deux — non `null` seulement
/// depuis l'onboarding, jamais lu ici via un provider ambiant : c'est
/// `router.dart` qui le construit (`readOnboardingProgress`), pour que cet
/// écran reste montable en test sans `AuthBloc`/`StripeAccountBloc` fournis.
class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key, this.progress});

  final OnboardingProgress? progress;

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  Timer? _pollingTimer;
  Timer? _autoNavTimer; // 1.5s delay before auto-navigating on VERIFIED
  Timer? _timeoutTimer; // 5min hard timeout on PENDING
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
      _startTimeoutTimer();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _autoNavTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _loadStatus() {
    context.read<KycBloc>().add(const KycStatusRefreshed());
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadStatus();
    });
  }

  // Called on voluntary exit (button) or on terminal state (VERIFIED/REJECTED).
  // Cancels all timers to prevent callbacks on a dismounted widget.
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _autoNavTimer?.cancel();
    _autoNavTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) setState(() => _timedOut = true);
      _stopPolling();
    });
  }

  // Used by the auto-nav timer — guards against dismounted context.
  void _navigateHome() {
    if (!mounted) return;
    context.read<AuthBloc>().add(const AuthCheckRequested());
    _leaveIdentityStep();
  }

  /// Étape suivante depuis l'identité : paiements si applicable, sinon
  /// l'accueil (`OnboardingProgress.routeAfter` — positionnel, pas de
  /// distinction terminée/passée : dans les deux cas l'écran suivant du
  /// parcours est le même). Hors onboarding ([widget.progress] `null`),
  /// toujours l'accueil, comme avant cette étape.
  ///
  /// Pose `onboarding_seen_at` seulement quand la destination est vraiment
  /// l'accueil — jamais quand il reste l'étape paiements à faire.
  void _leaveIdentityStep() {
    // L'instantané `widget.progress` a été pris à l'ouverture de l'écran,
    // avant toute vérification. Quand l'identité vient d'aboutir, il faut le
    // corriger : sans ça `payoutsUnlocked` resterait faux et l'étape paiements
    // serait considérée comme verrouillée juste après l'avoir déverrouillée.
    final kyc = context.read<KycBloc>().state;
    final justVerified = kyc is KycStatusLoaded && kyc.kycStatus == 'VERIFIED';
    final progress = justVerified
        ? widget.progress?.completing(OnboardingStep.identity)
        : widget.progress;
    final destination =
        progress?.routeAfter(OnboardingStep.identity) ?? '/home';
    if (progress != null && destination == '/home') {
      unawaited(
        getIt<AuthRepository>().markOnboardingSeen().catchError((_) {}),
      );
    }
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycSessionCreated) {
            // Préserve le marqueur d'onboarding : sans lui, le retour du
            // webview (`KycWebViewScreen`) perdrait `widget.progress` et
            // rendrait l'écran de statut suivant amnésique du parcours.
            context.go(
              '/kyc/verify${onboardingEntrySuffix(fromOnboarding: widget.progress != null)}',
              extra: state.stripeUrl,
            );
            return;
          }
          if (state is! KycStatusLoaded) return;
          if (state.kycStatus == 'VERIFIED') {
            _stopPolling();
            // Cancellable timer: auto-navigate after a short visual delay.
            _autoNavTimer = Timer(
              const Duration(milliseconds: 1500),
              _navigateHome,
            );
          } else if (state.kycStatus == 'NOT_STARTED') {
            // KYC not started — stop any polling that may have been running.
            _stopPolling();
          } else if (state.kycStatus == 'PENDING' && !_timedOut) {
            _startPolling();
          } else {
            _stopPolling();
          }
        },
        builder: (context, state) {
          final h = DonyLayout.hPadding(context);
          final progress = widget.progress;
          return SafeArea(
            child: DonyLayout.constrained(
              context,
              Padding(
                padding: EdgeInsets.fromLTRB(h, DonySpacing.base, h, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Uniquement depuis l'onboarding : depuis le profil, une
                    // jauge d'inscription n'aurait aucun sens.
                    if (progress != null) ...[
                      AuthFlowHeader.gauge(
                        segments: progress.segments,
                        label: 'Identité',
                      ),
                      const SizedBox(height: DonySpacing.md),
                    ],
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (state is KycLoading ||
                                        state is KycInitial)
                                      CircularProgressIndicator(
                                        color: cs.primary,
                                      )
                                    else if (state is KycStatusLoaded)
                                      _buildStatusContent(
                                        context,
                                        cs,
                                        tt,
                                        state,
                                      )
                                    else if (state is KycError)
                                      _buildErrorContent(
                                        cs,
                                        tt,
                                        ErrorPresenter.resolve(
                                          state.error,
                                        ).message,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ).animate().fadeIn(duration: 300.ms),
                    ),
                    _actionsFor(context, state),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Zone d'action commune du parcours, ancrée en bas quel que soit l'état.
  ///
  /// Les boutons vivaient au milieu de chaque contenu, à une hauteur qui
  /// changeait avec la longueur du texte : sur cet écran très aéré ils
  /// flottaient loin du pouce, et le lien « Passer » se retrouvait parfois
  /// hors de vue (retour utilisateur). Ils sont désormais construits ici, à
  /// l'écart du contenu défilant.
  Widget _actionsFor(BuildContext context, KycState state) {
    void startSession() =>
        context.read<KycBloc>().add(const KycSessionRequested());

    // Depuis le profil (progress null), il n'y a pas d'étape à passer.
    final skip = widget.progress != null ? _leaveIdentityStep : null;

    if (state is KycError) {
      return AuthFlowActions(
        primary: DonyButton(
          label: 'Réessayer',
          onPressed: _loadStatus,
          variant: DonyButtonVariant.ghost,
        ),
        onSkip: skip,
      );
    }
    if (state is! KycStatusLoaded) {
      // Chargement : la place reste réservée pour que la zone ne saute pas
      // quand l'état arrive.
      return const AuthFlowActions();
    }

    return switch (state.kycStatus) {
      // Vérifiée : l'auto-navigation part dans 1,5 s, aucune action à offrir.
      'VERIFIED' => const AuthFlowActions(),
      'REJECTED' => AuthFlowActions(
        primary: DonyButton(
          label: 'Réessayer la vérification',
          onPressed: startSession,
        ),
        onSkip: skip,
      ),
      'NOT_STARTED' => AuthFlowActions(
        primary: DonyButton(
          label: 'Commencer la vérification',
          onPressed: startSession,
        ),
        onSkip: skip,
      ),
      // Passé le délai d'attente, la reprise passe devant : une session que
      // Stripe n'a jamais reçue ne bougera plus jamais d'elle-même.
      _ when _timedOut => AuthFlowActions(
        primary: DonyButton(
          label: 'Reprendre la vérification',
          onPressed: startSession,
        ),
        skipLabel: "Retour à l'app",
        onSkip: _leaveIdentityStep,
      ),
      // En cours. La vérification peut être en examen chez Stripe, mais elle
      // peut tout aussi bien n'avoir jamais été soumise, l'utilisateur ayant
      // quitté la page avant de valider. Sans cette reprise, ce second cas
      // enferme le compte ici pour toujours : le statut reste PENDING, Stripe
      // n'a rien à examiner, et plus aucun chemin ne rouvre le formulaire.
      // Rouvrir une session déjà soumise est sans effet, le backend renvoyant
      // la session existante (`KycService.createSession` est idempotent).
      _ => AuthFlowActions(
        primary: DonyButton(
          label: 'Reprendre la vérification',
          onPressed: startSession,
          variant: DonyButtonVariant.ghost,
        ),
        skipLabel: 'Continuer plus tard',
        onSkip: () {
          _stopPolling();
          _leaveIdentityStep();
        },
      ),
    };
  }

  Widget _buildStatusContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    KycStatusLoaded state,
  ) {
    switch (state.kycStatus) {
      case 'VERIFIED':
        return _buildVerifiedContent(cs, tt);
      case 'REJECTED':
        return _buildRejectedContent(context, cs, tt, state.rejectionCode);
      case 'NOT_STARTED':
        return _buildNotStartedContent(context, cs, tt);
      default:
        return _timedOut
            ? _buildTimedOutContent(context, cs, tt)
            : _buildPendingContent(context, cs, tt);
    }
  }

  Widget _buildNotStartedContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(child: DonyIcon('user', color: cs.primary, size: 34)),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Vérification non démarrée',
          style: tt.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Vous devez vérifier votre identité pour utiliser toutes les fonctionnalités de Yadony.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Auto-navigation fires 1.5s after this widget is shown.
  Widget _buildVerifiedContent(ColorScheme cs, TextTheme tt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DonyMascotteAnimated(
          type: DonyMascotteType.securise,
          size: DonyMascotteSize.lg,
          withGlow: true,
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Identité vérifiée ✓',
          style: tt.headlineLarge?.copyWith(color: cs.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Votre identité a été vérifiée avec succès. Redirection en cours…',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      ],
    );
  }

  Widget _buildPendingContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.warningLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: DonyIcon('hourglass', color: cs.warning, size: 48),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Vérification en cours',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          "Cela prend généralement moins d'une minute, parfois quelques minutes. "
          'Vous pouvez fermer cet écran, vous serez notifié du résultat.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.lg),
        const _PollingIndicator(),
      ],
    );
  }

  Widget _buildTimedOutContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.warningLight,
            shape: BoxShape.circle,
          ),
          child: Center(child: DonyIcon('clock', color: cs.warning, size: 48)),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'La vérification prend plus de temps que prévu',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Vous pouvez fermer cet écran et revenir plus tard. '
          'Votre badge ✓ apparaîtra automatiquement dès que la vérification sera terminée.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRejectedContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    String? rejectionCode,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Center(child: DonyIcon('circle-x', color: cs.error, size: 48)),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Vérification échouée',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          kycRejectionMessage(rejectionCode),
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorContent(ColorScheme cs, TextTheme tt, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon('wifi-off', color: cs.onSurfaceVariant, size: 64),
        const SizedBox(height: DonySpacing.base),
        Text(
          message,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PollingIndicator extends StatelessWidget {
  const _PollingIndicator();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.warning),
        ),
        const SizedBox(width: DonySpacing.sm),
        Text(
          'Vérification automatique toutes les 30s',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
