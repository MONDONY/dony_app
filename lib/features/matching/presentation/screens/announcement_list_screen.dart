import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
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
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.plusJakartaSans(color: kError, fontWeight: FontWeight.w700),
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
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Mes trajets',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: hasAnnouncements
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 17, color: kGreenPrimary),
                    label: Text(
                      'Nouveau trajet',
                      style: GoogleFonts.plusJakartaSans(
                        color: kGreenPrimary,
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
              backgroundColor: kGreenPrimary,
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
                backgroundColor: kError,
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
              child: CircularProgressIndicator(color: kGreenPrimary),
            );
          }

          if (state is AnnouncementError && _lastList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 56, color: kTextHint),
                    const SizedBox(height: 16),
                    Text(
                      'Impossible de charger vos trajets',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
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
                        color: kGreenLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        size: 48,
                        color: kGreenPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucun trajet publié',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Publiez votre premier trajet et commencez à transporter des colis.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn();
          }

          return RefreshIndicator(
            color: kGreenPrimary,
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
                      color: kError,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.plusJakartaSans(
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

  ({Color bg, Color text, String label, IconData icon}) get _statusStyle {
    return switch (status) {
      'ACTIVE'    => (bg: kGreenLight, text: kSuccess, label: 'Actif', icon: Icons.circle),
      'FULL'      => (bg: const Color(0xFFFFF3E0), text: kWarning, label: 'Complet', icon: Icons.circle),
      'COMPLETED' => (bg: const Color(0xFFE3F2FD), text: const Color(0xFF1565C0), label: 'Terminé', icon: Icons.check_circle),
      'CANCELLED' => (bg: const Color(0xFFFFEBEE), text: kError, label: 'Annulé', icon: Icons.cancel),
      _           => (bg: kBackground, text: kTextSecondary, label: status, icon: Icons.circle),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CityChip(city: departureCity),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: kTextSecondary),
                            ),
                            _CityChip(city: arrivalCity),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: s.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(s.icon, size: 8, color: s.text),
                            const SizedBox(width: 4),
                            Text(
                              s.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600, color: s.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_month_rounded,
                        label: DateFormat('dd MMM yyyy').format(departureDate),
                      ),
                      _InfoChip(
                        icon: Icons.scale_rounded,
                        label: '${availableKg.toStringAsFixed(1)} kg',
                      ),
                      _InfoChip(
                        icon: Icons.euro_rounded,
                        label: '${pricePerKg.toStringAsFixed(0)}/kg',
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.inbox_rounded, size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '$bidsCount demande${bidsCount != 1 ? 's' : ''} reçue${bidsCount != 1 ? 's' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Voir le détail',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGreenPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: kGreenPrimary),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 60 * index),
          ).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String city;
  const _CityChip({required this.city});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        city,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary,
        ),
      ),
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
        color: highlight ? kGreenLight : kBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: highlight ? kGreenPrimary : kTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: highlight ? kGreenPrimary : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}