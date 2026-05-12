import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  Timer? _pollingTimer;
  Timer? _autoNavTimer;   // 1.5s delay before auto-navigating on VERIFIED
  Timer? _timeoutTimer;   // 5min hard timeout on PENDING
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
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycSessionCreated) {
          context.go('/kyc/verify', extra: state.stripeUrl);
          return;
        }
        if (state is! KycStatusLoaded) return;
          if (state.kycStatus == 'VERIFIED') {
            _stopPolling();
            // Cancellable timer: auto-navigate after a short visual delay.
            _autoNavTimer = Timer(const Duration(milliseconds: 1500), _navigateHome);
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
          return SafeArea(
            child: DonyLayout.constrained(
              context,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state is KycLoading || state is KycInitial)
                      CircularProgressIndicator(color: cs.primary)
                    else if (state is KycStatusLoaded)
                      _buildStatusContent(context, cs, tt, state)
                    else if (state is KycError)
                      _buildErrorContent(
                          cs, tt, ErrorPresenter.resolve(state.error).message),
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ),
            ),
          );
        },
      ),
    );
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
        return _buildRejectedContent(context, cs, tt);
      case 'NOT_STARTED':
        return _buildNotStartedContent(context, cs, tt);
      default:
        return _timedOut
            ? _buildTimedOutContent(context, cs, tt)
            : _buildPendingContent(context, cs, tt);
    }
  }

  Widget _buildNotStartedContent(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline_rounded, color: cs.primary, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'Vérification non démarrée',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Vous devez vérifier votre identité pour utiliser toutes les fonctionnalités de dony.',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        DonyButton(
          label: 'Commencer la vérification',
          onPressed: () => context.read<KycBloc>().add(const KycSessionRequested()),
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
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'Identité vérifiée ✓',
          style: tt.headlineLarge?.copyWith(color: cs.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Votre identité a été vérifiée avec succès. Redirection en cours…',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
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

  Widget _buildPendingContent(BuildContext context, ColorScheme cs, TextTheme tt) {
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
          child: Icon(Icons.hourglass_empty_rounded, color: cs.warning, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'Vérification en cours',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          "Cela prend généralement moins d'une minute, parfois quelques minutes. "
          'Vous pouvez fermer cet écran — vous serez notifié du résultat.',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xl),
        const _PollingIndicator(),
        const SizedBox(height: DonySpacing.xxl),
        TextButton(
          onPressed: () {
            _stopPolling();
            context.go('/home');
          },
          child: Text(
            'Continuer plus tard',
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildTimedOutContent(BuildContext context, ColorScheme cs, TextTheme tt) {
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
          child: Icon(Icons.schedule_rounded, color: cs.warning, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'La vérification prend plus de temps que prévu',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Vous pouvez fermer cet écran et revenir plus tard. '
          'Votre badge ✓ apparaîtra automatiquement dès que la vérification sera terminée.',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        DonyButton(
          label: "Retour à l'app",
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }

  Widget _buildRejectedContent(BuildContext context, ColorScheme cs, TextTheme tt) {
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
          child: Icon(Icons.cancel_outlined, color: cs.error, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'Vérification échouée',
          style: tt.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          "Nous n'avons pas pu vérifier votre identité. Assurez-vous que votre document est lisible et réessayez.",
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        DonyButton(
          label: 'Réessayer la vérification',
          onPressed: () => context.read<KycBloc>().add(const KycSessionRequested()),
        ),
      ],
    );
  }

  Widget _buildErrorContent(ColorScheme cs, TextTheme tt, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, color: cs.onSurfaceVariant, size: 64),
        const SizedBox(height: DonySpacing.base),
        Text(
          message,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xl),
        DonyButton(
          label: 'Réessayer',
          onPressed: _loadStatus,
          variant: DonyButtonVariant.ghost,
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
