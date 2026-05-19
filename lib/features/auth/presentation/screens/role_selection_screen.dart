import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.initialRole});
  final String initialRole; // 'SENDER' | 'TRAVELER'

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  void _proceed() {
    if (_selectedRole == 'TRAVELER') {
      context.read<ActiveRoleCubit>().switchToTraveler();
    } else {
      context.read<ActiveRoleCubit>().switchToSender();
    }
    context.read<AuthBloc>().add(const OnboardingCompleted());
    context.go('/auth/phone');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final mascotType = _selectedRole == 'TRAVELER'
        ? DonyMascotteType.enCourse
        : DonyMascotteType.tenantColis;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: animation, child: child),
                          ),
                          child: DonyMascotteAnimated(
                            key: ValueKey(mascotType),
                            type: mascotType,
                            size: DonyMascotteSize.md,
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.lg),
                      Text(
                        'Comment tu utilises dony ?',
                        style: tt.headlineLarge?.copyWith(color: cs.onSurface),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        'Ton profil principal — tu peux changer à tout moment',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                      ).animate().fadeIn(delay: 60.ms),
                      const SizedBox(height: DonySpacing.xl),
                      _RoleCard(
                        title: 'Expéditeur',
                        description: "J'envoie des colis à ma famille en Afrique",
                        icon: Icons.inventory_2_outlined,
                        isSelected: _selectedRole == 'SENDER',
                        onTap: () => setState(() => _selectedRole = 'SENDER'),
                      ).animate().fadeIn(delay: 120.ms).slideX(begin: 0.03),
                      const SizedBox(height: DonySpacing.sm),
                      _RoleCard(
                        title: 'Voyageur',
                        description: 'Je voyage et peux transporter des colis',
                        icon: Icons.flight_outlined,
                        isSelected: _selectedRole == 'TRAVELER',
                        onTap: () => setState(() => _selectedRole = 'TRAVELER'),
                      ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.03),
                      const SizedBox(height: DonySpacing.sm),
                      Center(
                        child: Text(
                          'Tu auras accès aux deux modes',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                padding: EdgeInsets.fromLTRB(h, DonySpacing.base, h, DonySpacing.md + bottom),
                child: DonyButton(
                  label: 'Continuer',
                  onPressed: _proceed,
                ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: DonyShadow.xs,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: DonySpacing.icon,
              height: DonySpacing.icon,
              decoration: BoxDecoration(
                color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Icon(
                icon,
                size: DonySpacing.iconSm,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(description, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
