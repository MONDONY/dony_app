import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoleModePill extends StatelessWidget {
  const RoleModePill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRoleCubit, ActiveRole>(
      builder: (context, activeRole) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: DonyColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: DonyColors.ink900.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillTab(
                    emoji: '🧭',
                    isActive: activeRole == ActiveRole.traveler,
                    onTap: () => context.read<ActiveRoleCubit>().switchToTraveler(),
                  ),
                  _PillTab(
                    emoji: '📦',
                    isActive: activeRole == ActiveRole.sender,
                    onTap: () => context.read<ActiveRoleCubit>().switchToSender(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.emoji,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? DonyColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
