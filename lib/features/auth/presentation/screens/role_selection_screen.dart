import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
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
        builder: (context, state) {
          final selectedRoles = state is AuthSelectingRoles
              ? state.selectedRoles
              : <String>{};
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.xl,
                vertical: DonySpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DonyLogo(fontSize: 44),
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
                  _RoleCard(
                    emoji: '📦',
                    title: 'Expéditeur',
                    description:
                        'J\'envoie des colis à ma famille en Afrique via des voyageurs.',
                    selected: selectedRoles.contains('SENDER'),
                    onTap: () => context
                        .read<AuthBloc>()
                        .add(const AuthRoleToggled('SENDER')),
                  ),
                  const SizedBox(height: DonySpacing.base),
                  _RoleCard(
                    emoji: '✈️',
                    title: 'Voyageur',
                    description:
                        'Je voyage vers l\'Afrique et j\'ai de l\'espace dans mes bagages.',
                    selected: selectedRoles.contains('TRAVELER'),
                    onTap: () => context
                        .read<AuthBloc>()
                        .add(const AuthRoleToggled('TRAVELER')),
                  ),
                  const Spacer(),
                  DonyButton(
                    label: 'Créer mon compte',
                    onPressed: (isLoading || selectedRoles.isEmpty)
                        ? null
                        : () => context.read<AuthBloc>().add(
                              AuthRegisterRequested(selectedRoles.toList()),
                            ),
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            if (selected) Icon(Icons.check_circle, color: cs.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
