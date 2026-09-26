import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l.blockedUsersTitle,
          style: const TextStyle(
            fontFamily: DonyTypography.fontBody,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D1B2A),
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9ECEF)),
        ),
      ),
      body: BlocBuilder<BlockedUsersBloc, BlockedUsersState>(
        builder: (context, state) {
          if (state is BlockedUsersLoading) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              itemCount: 4,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DonySpacing.md),
              itemBuilder: (_, _) => const DonyUserCardSkeleton(),
            );
          }
          if (state is BlockedUsersError) {
            return _ErrorView(
              message: l.blockedUsersLoadError,
              onRetry: () => context.read<BlockedUsersBloc>().add(
                const BlockedUsersLoadRequested(),
              ),
            );
          }
          if (state is BlockedUsersLoaded) {
            if (state.users.isEmpty) {
              return const _EmptyView();
            }
            return _UserList(users: state.users, unlockingId: null);
          }
          if (state is BlockedUsersUnblocking) {
            return _UserList(
              users: state.currentUsers,
              unlockingId: state.userId,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users, required this.unlockingId});

  final List<BlockedUserModel> users;
  final String? unlockingId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(
            context.l10n.blockedUsersListIntro,
            style: const TextStyle(
              fontFamily: DonyTypography.fontBody,
              fontSize: 12,
              color: Color(0xFF6B7A8D),
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              final isUnlocking = unlockingId == user.userId;
              return _UserTile(user: user, isUnlocking: isUnlocking)
                  .animate()
                  .fadeIn(duration: 250.ms, delay: (60 * index).ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic);
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.isUnlocking});

  final BlockedUserModel user;
  final bool isUnlocking;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return parts[0][0].toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(AppLocalizations l, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return l.blockedUsersToday;
    if (diff.inDays == 1) return l.blockedUsersYesterday;
    if (diff.inDays < 7) return l.blockedUsersDaysAgo(diff.inDays);
    if (diff.inDays < 30) {
      return l.blockedUsersWeeksAgo((diff.inDays / 7).floor());
    }
    return l.blockedUsersOnDate(DateFormat.yMMMd(l.localeName).format(date));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final displayName = user.displayName.isEmpty
        ? l.profileUserFallback
        : user.displayName;
    final initials = _initials(displayName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Avatar initiales
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: DonyTypography.fontBody,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4338CA),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: DonyTypography.fontBody,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(l, user.blockedAt),
                  style: const TextStyle(
                    fontFamily: DonyTypography.fontBody,
                    fontSize: 11,
                    color: Color(0xFF6B7A8D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bouton Débloquer
          isUnlocking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A6B3C),
                  ),
                )
              : GestureDetector(
                  onTap: () => context.read<BlockedUsersBloc>().add(
                    BlockedUserUnblockRequested(user.userId),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE9ECEF)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.blockedUsersUnblock,
                      style: const TextStyle(
                        fontFamily: DonyTypography.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A6B3C),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child:
            Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🚫', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.blockedUsersEmptyTitle,
                      style: const TextStyle(
                        fontFamily: DonyTypography.fontBody,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B2A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.blockedUsersEmptySubtitle,
                      style: const TextStyle(
                        fontFamily: DonyTypography.fontBody,
                        fontSize: 13,
                        color: Color(0xFF6B7A8D),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyIcon('circle-alert', size: 48, color: Color(0xFF6B7A8D)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontFamily: DonyTypography.fontBody,
                fontSize: 14,
                color: Color(0xFF6B7A8D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                context.l10n.commonRetry,
                style: const TextStyle(
                  fontFamily: DonyTypography.fontBody,
                  color: Color(0xFF1A6B3C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
