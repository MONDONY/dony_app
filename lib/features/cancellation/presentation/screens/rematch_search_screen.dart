import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RematchSearchScreen extends StatelessWidget {
  final CancellationModel cancellation;

  const RematchSearchScreen({super.key, required this.cancellation});

  @override
  Widget build(BuildContext context) {
    final suggestions = cancellation.rematchSuggestions;

    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Alternatives disponibles',
          style: GoogleFonts.sora(
              fontWeight: FontWeight.w700, fontSize: 18, color: DonyColors.dark900),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey100),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmationBanner(affectedCount: cancellation.affectedBidsCount),
            const SizedBox(height: 24),
            if (suggestions.isEmpty)
              _NoAlternatives()
            else ...[
              Text(
                '${suggestions.length} voyageur${suggestions.length > 1 ? 's' : ''} disponible${suggestions.length > 1 ? 's' : ''}',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w700, color: DonyColors.dark900),
              ),
              const SizedBox(height: 14),
              ...suggestions.asMap().entries.map((e) => _SuggestionCard(
                    suggestion: e.value,
                    index: e.key,
                  )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go('/home'),
                child: Text('Retour à l\'accueil',
                    style: GoogleFonts.sora(
                        color: DonyColors.grey400, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  final int affectedCount;
  const _ConfirmationBanner({required this.affectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DonyColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: DonyColors.success, size: 20),
              const SizedBox(width: 8),
              Text('Trajet annulé',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700, fontSize: 14, color: DonyColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$affectedCount expéditeur${affectedCount > 1 ? 's' : ''} remboursé${affectedCount > 1 ? 's' : ''} automatiquement.',
            style: GoogleFonts.sora(fontSize: 13, color: DonyColors.grey400),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final RematchSuggestionModel suggestion;
  final int index;
  const _SuggestionCard({required this.suggestion, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: DonyColors.blue100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flight_takeoff_rounded, color: DonyColors.blue400, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${suggestion.departureCity} → ${suggestion.arrivalCity}',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700, fontSize: 15, color: DonyColors.dark900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: DonyColors.grey100, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('dd MMM yyyy').format(suggestion.departureDate),
              ),
              const SizedBox(width: 12),
              _Chip(
                icon: Icons.scale_outlined,
                label: '${suggestion.availableKg} kg dispo',
              ),
              const SizedBox(width: 12),
              _Chip(
                icon: Icons.euro_rounded,
                label: '${suggestion.pricePerKg.toStringAsFixed(0)} €/kg',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(
                '/search/${suggestion.announcementId}/bid',
                extra: AnnouncementModel(
                  id: suggestion.announcementId,
                  travelerId: 'temp',
                  departureCity: suggestion.departureCity,
                  arrivalCity: suggestion.arrivalCity,
                  departureDate: suggestion.departureDate,
                  availableKg: suggestion.availableKg,
                  pricePerKg: suggestion.pricePerKg,
                  status: 'ACTIVE',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DonyColors.blue400,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Envoyer une demande',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DonyColors.grey400),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.sora(fontSize: 12, color: DonyColors.grey400)),
      ],
    );
  }
}

class _NoAlternatives extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DonyColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.search_off_rounded, color: DonyColors.warning, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Aucun voyageur disponible',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w700, color: DonyColors.dark900)),
            const SizedBox(height: 8),
            Text(
              'Aucun voyageur alternatif disponible dans les 72h sur ce corridor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400),
            ),
          ],
        ),
      ),
    );
  }
}
