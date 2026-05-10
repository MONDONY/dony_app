import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MyNegotiationsScreen extends StatefulWidget {
  const MyNegotiationsScreen({super.key});

  @override
  State<MyNegotiationsScreen> createState() => _MyNegotiationsScreenState();
}

class _MyNegotiationsScreenState extends State<MyNegotiationsScreen> {
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final threads = await getIt<NegotiationRepository>().findMine();
      if (mounted) {
        setState(() {
          _threads = threads;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mes négociations',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kGreenPrimary))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _threads.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: kGreenPrimary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _threads.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ThreadCard(
                          thread: _threads[i],
                          index: i,
                        ),
                      ),
                    ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.index});
  final NegotiationThread thread;
  final int index;

  Color _statusColor() => switch (thread.status) {
        NegotiationThreadStatus.open => kWarning,
        NegotiationThreadStatus.accepted => kSuccess,
        NegotiationThreadStatus.rejected => kError,
        NegotiationThreadStatus.autoRejected => kTextHint,
        NegotiationThreadStatus.expired => kTextHint,
      };

  String _statusLabel() => switch (thread.status) {
        NegotiationThreadStatus.open => 'En cours',
        NegotiationThreadStatus.accepted => 'Acceptée',
        NegotiationThreadStatus.rejected => 'Rejetée',
        NegotiationThreadStatus.autoRejected => 'Auto-rejetée',
        NegotiationThreadStatus.expired => 'Expirée',
      };

  @override
  Widget build(BuildContext context) {
    final lastMessage = thread.messages.isEmpty ? null : thread.messages.last;
    final hasUnread =
        thread.status == NegotiationThreadStatus.open && lastMessage != null;

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/negotiations/${thread.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread ? kGreenPrimary : kBorder,
              width: hasUnread ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${thread.currentPriceEur.toStringAsFixed(0)} €',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kGreenPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Round ${thread.roundsCount}/5',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (lastMessage != null) ...[
                Row(
                  children: [
                    Icon(
                      _kindIcon(lastMessage.kind),
                      size: 14,
                      color: kTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lastMessageLabel(lastMessage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Mis à jour ${DateFormat('d MMM HH:mm', 'fr').format(thread.lastActivityAt)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: kTextHint,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
  }

  IconData _kindIcon(NegotiationMessageKind kind) => switch (kind) {
        NegotiationMessageKind.proposal => Icons.send_rounded,
        NegotiationMessageKind.counter => Icons.swap_horiz_rounded,
        NegotiationMessageKind.accept => Icons.check_circle_rounded,
        NegotiationMessageKind.reject => Icons.cancel_outlined,
      };

  String _lastMessageLabel(NegotiationMessage m) {
    final price = m.proposedPriceEur != null
        ? ' — ${m.proposedPriceEur!.toStringAsFixed(0)} €'
        : '';
    return switch (m.kind) {
      NegotiationMessageKind.proposal => 'Proposition$price',
      NegotiationMessageKind.counter => 'Contre-offre$price',
      NegotiationMessageKind.accept => 'Acceptée',
      NegotiationMessageKind.reject => 'Rejetée',
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake_outlined, size: 64, color: kTextHint),
            const SizedBox(height: 16),
            Text(
              'Aucune négociation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tes négociations actives apparaîtront ici',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: kError),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
