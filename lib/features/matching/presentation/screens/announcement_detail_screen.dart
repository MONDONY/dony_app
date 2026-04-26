import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/core/design/design_system.dart';
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

  Future<bool> _confirmDelete({bool isCancelled = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Supprimer ce trajet ?',
              style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            content: Text(
              isCancelled
                  ? 'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'
                  : 'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.',
              style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.sora(color: DonyColors.grey400, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.sora(color: DonyColors.error, fontWeight: FontWeight.w700),
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
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Détail du trajet',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: DonyColors.white,
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
                  style: GoogleFonts.sora(fontWeight: FontWeight.w500),
                ),
                backgroundColor: DonyColors.success,
              ),
            );
            context.pop();
          } else if (state is AnnouncementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: DonyColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return const Center(child: CircularProgressIndicator(color: DonyColors.blue400));
          }

          if (state is AnnouncementDetailLoaded) {
            final a = state.announcement;
            final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
            final isCancelled = a.status == 'CANCELLED';
            final canDelete = (a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0) || isCancelled;

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
                        colors: [DonyColors.blue600, DonyColors.blue400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: DonyColors.blue400.withValues(alpha: 0.3),
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
                              style: GoogleFonts.sora(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            _StatusBadge(status: a.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              a.departureCity,
                              style: GoogleFonts.sora(
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
                              style: GoogleFonts.sora(
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
                              style: GoogleFonts.sora(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (a.departureTime != null || a.arrivalTime != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (a.departureTime != null) ...[
                                const Icon(Icons.flight_takeoff_rounded, color: Colors.white60, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  a.departureTime!,
                                  style: GoogleFonts.sora(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (a.departureTime != null && a.arrivalTime != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '→',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                                  ),
                                ),
                              if (a.arrivalTime != null) ...[
                                const Icon(Icons.flight_land_rounded, color: Colors.white60, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  a.arrivalTime!,
                                  style: GoogleFonts.sora(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.04, curve: Curves.easeOutCubic),

                  // Lieux de remise
                  if (a.departureLocation != null || a.arrivalLocation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DonyColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DonyColors.grey100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lieux de remise',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: DonyColors.grey400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (a.departureLocation != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: DonyColors.blue400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.departureLocation!,
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: DonyColors.dark900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (a.arrivalLocation != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: DonyColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    a.arrivalLocation!,
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: DonyColors.dark900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 80.ms),
                  ],

                  const SizedBox(height: 16),

                  // Stats row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 40 - 24) / 3 > 100 
                          ? (MediaQuery.of(context).size.width - 40 - 24) / 3 
                          : double.infinity,
                        child: _StatCard(
                          icon: Icons.scale_rounded,
                          label: 'Capacité dispo.',
                          value: '${a.availableKg.toStringAsFixed(1)} kg',
                          color: const Color(0xFF0F4C75),
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 40 - 24) / 3 > 100 
                          ? (MediaQuery.of(context).size.width - 40 - 24) / 3 
                          : double.infinity,
                        child: _StatCard(
                          icon: Icons.euro_rounded,
                          label: 'Prix par kg',
                          value: '${a.pricePerKg.toStringAsFixed(2)} €',
                          color: DonyColors.blue400,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 40 - 24) / 3 > 100 
                          ? (MediaQuery.of(context).size.width - 40 - 24) / 3 
                          : double.infinity,
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
                  // Voir les demandes — toujours visible si le statut est ACTIVE
                  if (a.status == 'ACTIVE') ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.inbox_rounded, color: Colors.white, size: 18),
                      label: Text('Voir les demandes (${a.bidsCount ?? 0})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DonyColors.blue400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/announcements/${a.id}/bids'),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 12),
                  ],

                  if (canEdit) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Modifier ce trajet'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push(
                        '/announcements/${a.id}/edit',
                        extra: a,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 12),
                  ],

                  if (!canDelete && a.status == 'ACTIVE') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: DonyColors.error),
                      label: Text(
                        'Annuler ce trajet',
                        style: GoogleFonts.sora(color: DonyColors.error, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: DonyColors.error),
                        foregroundColor: DonyColors.error,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/announcements/${a.id}/cancel'),
                    ).animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 12),
                  ],

                  if (canDelete)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: DonyColors.error),
                      label: Text(
                        'Supprimer ce trajet',
                        style: GoogleFonts.sora(color: DonyColors.error, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: DonyColors.error),
                        foregroundColor: DonyColors.error,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(isCancelled: isCancelled);
                        if (confirmed && context.mounted) {
                          context.read<AnnouncementBloc>().add(
                            AnnouncementDeleteRequested(a.id),
                          );
                        }
                      },
                    ).animate().fadeIn(delay: 300.ms),

                  if (!canEdit && !canDelete && a.status != 'ACTIVE')
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: DonyColors.warning, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ce trajet ne peut plus être modifié.',
                              style: GoogleFonts.sora(
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
      'ACTIVE'    => (DonyColors.success, 'Actif'),
      'FULL'      => (DonyColors.warning, 'Complet'),
      'COMPLETED' => (DonyColors.blue600, 'Terminé'),
      'CANCELLED' => (DonyColors.error, 'Annulé'),
      _           => (DonyColors.grey400, status),
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
        style: GoogleFonts.sora(
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
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DonyColors.grey100),
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
            style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: DonyColors.dark900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.sora(fontSize: 11, color: DonyColors.grey400),
          ),
        ],
      ),
    );
  }
}
