import 'package:dony/app/theme.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
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
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Alternatives disponibles',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18, color: kTextPrimary),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
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
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
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
                    style: GoogleFonts.plusJakartaSans(
                        color: kTextSecondary, fontWeight: FontWeight.w600)),
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
        color: kSuccess.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSuccess.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: kSuccess, size: 20),
              const SizedBox(width: 8),
              Text('Trajet annulé',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 14, color: kSuccess)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$affectedCount expéditeur${affectedCount > 1 ? 's' : ''} remboursé${affectedCount > 1 ? 's' : ''} automatiquement.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
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
                    color: kGreenLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flight_takeoff_rounded, color: kGreenPrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${suggestion.departureCity} → ${suggestion.arrivalCity}',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 15, color: kTextPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: kBorder, height: 1),
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
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Envoyer une demande',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14)),
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
        Icon(icon, size: 14, color: kTextSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextSecondary)),
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
                color: kWarning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.search_off_rounded, color: kWarning, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Aucun voyageur disponible',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Aucun voyageur alternatif disponible dans les 72h sur ce corridor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
