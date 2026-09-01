import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void showSenderPublicProfileSheet(
  BuildContext context,
  SenderPublicProfile sender,
) {
  DonyBottomSheet.show<void>(
    context,
    title: 'Profil expéditeur',
    child: _SenderPublicProfileContent(sender: sender),
  );
}

class _SenderPublicProfileContent extends StatelessWidget {
  const _SenderPublicProfileContent({required this.sender});

  final SenderPublicProfile sender;

  /// Identifiant du compte connecté, ou `null` si personne n'est connecté ou si
  /// l'`AuthBloc` n'est pas dans l'arbre.
  String? _currentUserId(BuildContext context) {
    try {
      // currentUserId couvre AuthAuthenticated ET AuthProfileUpdated : tester
      // le seul AuthAuthenticated raterait l'état émis après une maj de profil.
      return context.read<AuthBloc>().state.currentUserId;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // `SenderPublicProfile.guest` ne porte pas d'identifiant : sans cible, pas
    // de blocage possible. Et on ne se bloque pas soi-même.
    final canBlock =
        sender.id.isNotEmpty && sender.id != _currentUserId(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        children: [
          if (canBlock)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Plus d\'options',
                icon: DonyIcon('ellipsis', color: cs.onSurfaceVariant),
                onPressed: () => showBlockMenu(
                  context,
                  userId: sender.id,
                  displayName: sender.displayName,
                ),
              ),
            ),
          DonyAvatar(
            name: sender.displayName,
            imageUrl: sender.avatarUrl,
            size: DonyAvatarSize.xl,
            verified: sender.kycVerified,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            sender.displayName,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (sender.kycVerified) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DonyIcon('badge-check', color: cs.primary, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Identité vérifiée',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: sender.totalRatings > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DonyIcon('star', color: cs.warning, size: 22),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        sender.averageRating.toStringAsFixed(1),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        '· ${sender.totalRatings} avis',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DonyIcon('user', color: cs.onSurfaceVariant, size: 18),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        'Nouveau membre',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
