import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycOnboardingScreen extends StatelessWidget {
  const KycOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycSessionCreated) {
            context.go('/kyc/verify', extra: state.stripeUrl);
          } else if (state is KycError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: DonySpacing.huge),
                  _buildHeader(cs, tt),
                  const SizedBox(height: DonySpacing.huge),
                  _buildSteps(cs, tt),
                  const Spacer(),
                  _buildButton(context, state),
                  const SizedBox(height: DonySpacing.xxl),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.verified_user_outlined, color: cs.primary, size: 32),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: DonySpacing.xl),
        Text(
          'Vérification d\'identité',
          style: tt.headlineLarge,
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Pour accéder à toutes les fonctionnalités, nous devons vérifier votre identité. Ce processus prend moins de 5 minutes.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        _buildStep(
          cs,
          tt,
          icon: Icons.credit_card_outlined,
          title: 'Pièce d\'identité',
          description: 'Passeport, carte d\'identité ou permis de conduire',
        ),
        const SizedBox(height: DonySpacing.lg),
        _buildStep(
          cs,
          tt,
          icon: Icons.face_outlined,
          title: 'Selfie liveness',
          description: 'Photo en temps réel pour confirmer votre identité',
        ),
        const SizedBox(height: DonySpacing.lg),
        _buildStep(
          cs,
          tt,
          icon: Icons.check_circle_outline,
          title: 'Vérification automatique',
          description: 'Résultat dans les 24h, souvent instantané',
        ),
      ],
    );
  }

  Widget _buildStep(
    ColorScheme cs,
    TextTheme tt, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, KycState state) {
    return DonyButton(
      label: 'Commencer la vérification',
      onPressed: () => context.read<KycBloc>().add(const KycSessionRequested()),
      isLoading: state is KycLoading,
    );
  }
}
