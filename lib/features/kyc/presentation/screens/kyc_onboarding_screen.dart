import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycOnboardingScreen extends StatelessWidget {
  const KycOnboardingScreen({super.key});

  static const _kGreen = Color(0xFF1A6B3C);
  static const _kGreenLight = Color(0xFFEAF5EF);
  static const _kBg = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycSessionCreated) {
            context.go('/kyc/verify', extra: state.stripeUrl);
          } else if (state is KycError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildSteps(),
                  const Spacer(),
                  _buildButton(context, state),
                  const SizedBox(height: 32),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: _kGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user_outlined, color: _kGreen, size: 32),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        const Text(
          'Vérification d\'identité',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pour accéder à toutes les fonctionnalités, nous devons vérifier votre identité. Ce processus prend moins de 5 minutes.',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Column(
      children: [
        _buildStep(
          icon: Icons.credit_card_outlined,
          title: 'Pièce d\'identité',
          description: 'Passeport, carte d\'identité ou permis de conduire',
          step: '1',
        ),
        const SizedBox(height: 20),
        _buildStep(
          icon: Icons.face_outlined,
          title: 'Selfie liveness',
          description: 'Photo en temps réel pour confirmer votre identité',
          step: '2',
        ),
        const SizedBox(height: 20),
        _buildStep(
          icon: Icons.check_circle_outline,
          title: 'Vérification automatique',
          description: 'Résultat dans les 24h, souvent instantané',
          step: '3',
        ),
      ],
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String description,
    required String step,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
            child: Icon(icon, color: _kGreen, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, KycState state) {
    final isLoading = state is KycLoading;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => context.read<KycBloc>().add(const KycSessionRequested()),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Commencer la vérification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
