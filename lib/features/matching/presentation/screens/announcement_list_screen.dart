import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<AnnouncementModel> _lastList = [];
  bool _tickerWasActive = false;

  // Détecte l'activation du tab (StatefulShellRoute.indexedStack change
  // TickerMode pour le branch inactif → actif, ce qui appelle didChangeDependencies).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.of(context);
    if (isActive && !_tickerWasActive) {
      context.read<AnnouncementBloc>().add(AnnouncementListRequested());
    }
    _tickerWasActive = isActive;
  }

  Future<bool?> _confirmDeleteDialog(BuildContext ctx) {
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Supprimer ce trajet ?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.',
          style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.sora(color: DonyColors.grey400, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.sora(color: DonyColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnnouncements = _lastList.isNotEmpty;

    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Mes trajets',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: hasAnnouncements
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 17, color: DonyColors.blue400),
                    label: Text(
                      'Nouveau trajet',
                      style: GoogleFonts.sora(
                        color: DonyColors.blue400,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => context.push('/announcements/create'),
                  ),
                ),
              ]
            : null,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      // FAB icône seule sur l'état vide pour permettre la création du premier trajet
      floatingActionButton: hasAnnouncements
          ? null
          : FloatingActionButton(
              backgroundColor: DonyColors.blue400,
              elevation: 2,
              onPressed: () => context.push('/announcements/create'),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          } else if (state is AnnouncementError && _lastList.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: DonyColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          }
        },
        builder: (context, state) {
          if (state is AnnouncementListLoaded) {
            _lastList = state.announcements;
          }

          if ((state is AnnouncementLoading || state is AnnouncementInitial) &&
              _lastList.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: DonyColors.blue400),
            );
          }

          if (state is AnnouncementError && _lastList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 56, color: DonyColors.grey200),
                    const SizedBox(height: 16),
                    Text(
                      'Impossible de charger vos trajets',
                      style: GoogleFonts.sora(
                        fontSize: 16, fontWeight: FontWeight.w600, color: DonyColors.dark900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: GoogleFonts.sora(fontSize: 13, color: DonyColors.grey400),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      onPressed: () =>
                          context.read<AnnouncementBloc>().add(AnnouncementListRequested()),
                    ),
                  ],
                ),
              ),
            );
          }

          final list = _lastList;

          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: DonyColors.blue100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        size: 48,
                        color: DonyColors.blue400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucun trajet publié',
                      style: GoogleFonts.sora(
                        fontSize: 18, fontWeight: FontWeight.w700, color: DonyColors.dark900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Publiez votre premier trajet et commencez à transporter des colis.',
                      style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn();
          }

          return RefreshIndicator(
            color: DonyColors.blue400,
            onRefresh: () async =>
                context.read<AnnouncementBloc>().add(AnnouncementListRequested()),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = list[index];
                final isCancelled = item.status == 'CANCELLED';

                return Dismissible(
                  key: ValueKey(item.id),
                  direction: isCancelled
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
                  confirmDismiss: isCancelled
                      ? (_) => _confirmDeleteDialog(context)
                      : null,
                  onDismissed: (_) {
                    setState(() {
                      _lastList = _lastList.where((a) => a.id != item.id).toList();
                    });
                    context
                        .read<AnnouncementBloc>()
                        .add(AnnouncementDeleteRequested(item.id));
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: DonyColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: _AnnouncementCard(
                    departureCity: item.departureCity,
                    arrivalCity: item.arrivalCity,
                    departureDate: item.departureDate,
                    availableKg: item.availableKg,
                    pricePerKg: item.pricePerKg,
                    status: item.status,
                    bidsCount: item.bidsCount ?? 0,
                    onTap: () async {
                      await context.push('/announcements/${item.id}');
                      if (context.mounted) {
                        context
                            .read<AnnouncementBloc>()
                            .add(AnnouncementListRequested());
                      }
                    },
                    index: index,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;
  final String status;
  final int bidsCount;
  final VoidCallback onTap;
  final int index;

  const _AnnouncementCard({
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
    required this.status,
    required this.bidsCount,
    required this.onTap,
    required this.index,
  });

  ({Color bg, Color text, String label}) get _statusStyle => switch (status) {
        'ACTIVE' => (bg: DonyColors.blue100, text: DonyColors.success, label: 'Actif'),
        'FULL' => (
          bg: const Color(0xFFFFF3E0),
          text: DonyColors.warning,
          label: 'Complet'
        ),
        'COMPLETED' => (
          bg: const Color(0xFFE3F2FD),
          text: DonyColors.blue600,
          label: 'Terminé'
        ),
        'CANCELLED' => (
          bg: const Color(0xFFFFEBEE),
          text: DonyColors.error,
          label: 'Annulé'
        ),
        _ => (bg: DonyColors.grey50, text: DonyColors.grey400, label: status),
      };

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle;
    final dateStr = DateFormat('EEE d MMM yyyy', 'fr').format(departureDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DonyColors.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône trajet (remplace l'avatar dans la vue expéditeur)
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DonyColors.blue600, DonyColors.blue400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : route + badge statut
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '$departureCity → $arrivalCity',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DonyColors.dark900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s.label,
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: s.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Ligne 2 : date
                    Text(
                      dateStr,
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: DonyColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Ligne 3 : capacité + prix + demandes + gérer
                    Row(
                      children: [
                        // Chips à gauche : flexibles pour ne pas déborder
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _InfoChip(
                                icon: Icons.scale_rounded,
                                label: '${availableKg.toStringAsFixed(0)} kg',
                              ),
                              _InfoChip(
                                icon: Icons.euro_rounded,
                                label: '${pricePerKg.toStringAsFixed(0)}/kg',
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge demandes + bouton Gérer ancrés à droite
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bidsCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inbox_rounded,
                                        size: 11, color: Color(0xFF7C3AED)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$bidsCount',
                                      style: GoogleFonts.sora(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: DonyColors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DonyColors.blue400),
                              ),
                              child: Text(
                                'Gérer →',
                                style: GoogleFonts.sora(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: DonyColors.blue400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 60 * index),
          ).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoChip({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? DonyColors.blue100 : DonyColors.grey50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: highlight ? DonyColors.blue400 : DonyColors.grey400),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: highlight ? DonyColors.blue400 : DonyColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}