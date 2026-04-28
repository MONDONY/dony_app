import 'package:dony/core/constants/app_assets.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isSender = false;
  bool _isTraveler = false;

  bool get _canProceed => _isSender || _isTraveler;

  void _register() {
    final roles = <String>[
      if (_isSender) 'SENDER',
      if (_isTraveler) 'TRAVELER',
    ];
    context.read<AuthBloc>().add(AuthRegisterRequested(roles));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/auth/pin-setup');
          } else if (state is AuthError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.xl,
              vertical: DonySpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(AppAssets.logo, height: 48),
                const SizedBox(height: DonySpacing.xxl),
                Text(
                  'Je suis...',
                  style: tt.headlineLarge?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  'Choisissez un ou plusieurs rôles. Vous pourrez toujours en ajouter plus tard.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 40),
                _buildRoleCard(
                  context: context,
                  emoji: '📦',
                  title: 'Expéditeur',
                  description:
                      'J\'envoie des colis à ma famille en Afrique via des voyageurs.',
                  selected: _isSender,
                  onTap: () => setState(() => _isSender = !_isSender),
                ),
                const SizedBox(height: DonySpacing.base),
                _buildRoleCard(
                  context: context,
                  emoji: '✈️',
                  title: 'Voyageur',
                  description:
                      'Je voyage vers l\'Afrique et j\'ai de l\'espace dans mes bagages.',
                  selected: _isTraveler,
                  onTap: () => setState(() => _isTraveler = !_isTraveler),
                ),
                const Spacer(),
                _buildRegisterButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String emoji,
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(DonySpacing.lg),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surface,
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleLarge?.copyWith(
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    description,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: cs.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return DonyButton(
          label: 'Créer mon compte',
          onPressed: (isLoading || !_canProceed) ? null : _register,
          isLoading: isLoading,
        );
      },
    );
  }
}
