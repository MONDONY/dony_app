import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String id;
  const AnnouncementDetailScreen({super.key, required this.id});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(widget.id));
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Supprimer ce trajet ?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            content: Text(
              'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.plusJakartaSans(color: kError, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Détail du trajet',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: kSurface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Trajet supprimé',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                ),
                backgroundColor: kSuccess,
              ),
            );
            context.go('/announcements');
          } else if (state is AnnouncementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: kError,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return const Center(child: CircularProgressIndicator(color: kGreenPrimary));
          }

          if (state is AnnouncementDetailLoaded) {
            final a = state.announcement;
            final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
            final canDelete = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero card — corridor + date
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF134F2D), Color(0xFF1A6B3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kGreenPrimary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Trajet',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            _StatusBadge(status: a.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              a.departureCity,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                            ),
                            Text(
                              a.arrivalCity,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white60, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('EEEE d MMMM yyyy', 'fr').format(a.departureDate),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.04, curve: Curves.easeOutCubic),

                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.scale_rounded,
                          label: 'Capacité dispo.',
                          value: '${a.availableKg.toStringAsFixed(1)} kg',
                          color: const Color(0xFF0F4C75),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.euro_rounded,
                          label: 'Prix par kg',
                          value: '${a.pricePerKg.toStringAsFixed(2)} €',
                          color: kGreenPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.inbox_rounded,
                          label: 'Demandes',
                          value: '${a.bidsCount ?? 0}',
                          color: const Color(0xFF6C3483),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 28),

                  // Actions
                  if (canEdit) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      label: const Text('Modifier ce trajet'),
                      onPressed: () => context.push(
                        '/announcements/${a.id}/edit',
                        extra: a,
                      ),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 12),
                  ],

                  if (canDelete)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kError),
                      label: Text(
                        'Supprimer ce trajet',
                        style: GoogleFonts.plusJakartaSans(color: kError, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kError),
                        foregroundColor: kError,
                      ),
                      onPressed: () async {
                        final confirmed = await _confirmDelete();
                        if (confirmed && context.mounted) {
                          context.read<AnnouncementBloc>().add(
                            AnnouncementDeleteRequested(a.id),
                          );
                        }
                      },
                    ).animate().fadeIn(delay: 200.ms),

                  if (!canEdit && !canDelete)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: kWarning, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ce trajet ne peut plus être modifié car des demandes ont été acceptées.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'ACTIVE'    => (kSuccess, 'Actif'),
      'FULL'      => (kWarning, 'Complet'),
      'COMPLETED' => (const Color(0xFF1565C0), 'Terminé'),
      'CANCELLED' => (kError, 'Annulé'),
      _           => (kTextSecondary, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}
