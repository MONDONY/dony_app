import 'dart:async';

import 'package:dony/core/design/design_system.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _loadStatus() {
    context.read<KycBloc>().add(const KycStatusRefreshed());
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadStatus();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycStatusLoaded) {
            if (state.kycStatus == 'PENDING') {
              _startPolling();
            } else {
              _stopPolling();
            }
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state is KycLoading || state is KycInitial)
                    CircularProgressIndicator(color: cs.primary)
                  else if (state is KycStatusLoaded)
                    _buildStatusContent(context, cs, tt, state)
                  else if (state is KycError)
                    _buildErrorContent(cs, tt, state.message),
                ],
              ).animate().fadeIn(duration: 300.ms),
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
        return _buildVerifiedContent(context, cs, tt);
      case 'REJECTED':
        return _buildRejectedContent(context, cs, tt);
      default:
        return _buildPendingContent(cs, tt);
    }
  }

  Widget _buildVerifiedContent(BuildContext context, ColorScheme cs, TextTheme tt) {
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
          child: Icon(Icons.verified, color: cs.primary, size: 52),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xxl),
        Text(
          'Identité vérifiée ✓',
          style: tt.headlineLarge?.copyWith(color: cs.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Votre identité a été vérifiée avec succès. Vous pouvez maintenant accéder à toutes les fonctionnalités de dony.',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        DonyButton(
          label: 'Accéder à l\'app',
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }

  Widget _buildPendingContent(ColorScheme cs, TextTheme tt) {
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
          'Votre dossier est en cours d\'analyse. Vous serez notifié dès que la vérification sera terminée (généralement quelques minutes).',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xl),
        const _PollingIndicator(),
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
          'Nous n\'avons pas pu vérifier votre identité. Assurez-vous que votre document est lisible et réessayez.',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.huge),
        DonyButton(
          label: 'Réessayer la vérification',
          onPressed: () => context.go('/kyc'),
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.warning,
          ),
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
