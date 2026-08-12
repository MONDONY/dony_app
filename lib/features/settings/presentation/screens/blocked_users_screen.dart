import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Utilisateurs bloqués',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B2A),
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
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A6B3C)),
            );
          }
          if (state is BlockedUsersError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<BlockedUsersBloc>()
                  .add(const BlockedUsersLoadRequested()),
            );
          }
          if (state is BlockedUsersLoaded) {
            if (state.users.isEmpty) {
              return const _EmptyView();
            }
            return _UserList(
              users: state.users,
              unlockingId: null,
            );
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
            'Une personne bloquée ne voit plus tes annonces et ne peut plus t\'envoyer d\'offre. Tu ne vois plus les siennes non plus.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF6B7A8D),
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Bloqué aujourd'hui";
    if (diff.inDays == 1) return 'Bloqué hier';
    if (diff.inDays < 7) return 'Bloqué il y a ${diff.inDays} jours';
    if (diff.inDays < 14) return 'Bloqué il y a 1 semaine';
    if (diff.inDays < 30) return 'Bloqué il y a ${(diff.inDays / 7).floor()} semaines';
    return 'Bloqué le ${DateFormat('d MMM yyyy', 'fr').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.displayName);

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
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4338CA),
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
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(user.blockedAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF6B7A8D),
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
                  onTap: () => context
                      .read<BlockedUsersBloc>()
                      .add(BlockedUserUnblockRequested(user.userId)),
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
                      'Débloquer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A6B3C),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚫', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              "Tu n'as bloqué personne",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D1B2A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les personnes que tu bloques apparaîtront ici.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF6B7A8D),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF6B7A8D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Réessayer',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF1A6B3C),
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
