import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RematchSearchScreen extends StatelessWidget {
  final CancellationModel cancellation;

  const RematchSearchScreen({super.key, required this.cancellation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final suggestions = cancellation.rematchSuggestions;

    return Scaffold(
      appBar: const DonyAppBar(
        title: 'Alternatives disponibles',
        showBackButton: false,
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.lg, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _ConfirmationBanner(
              affectedCount: cancellation.affectedBidsCount,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.xl),
            if (suggestions.isEmpty)
              const DonyEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun voyageur disponible',
                description:
                    'Aucun voyageur alternatif disponible dans les 72h sur ce corridor.',
              )
            else ...[
              Text(
                '${suggestions.length} voyageur${suggestions.length > 1 ? 's' : ''} disponible${suggestions.length > 1 ? 's' : ''}',
                style: tt.titleLarge?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: DonySpacing.base),
              ...suggestions.asMap().entries.map((e) => _SuggestionCard(
                    suggestion: e.value,
                    index: e.key,
                  )),
            ],
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Retour à l\'accueil',
              onPressed: () => context.go('/home'),
              variant: DonyButtonVariant.ghost,
            ),
          ],
            ),
          ),
        );
      }),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  final int affectedCount;
  final ColorScheme cs;
  final TextTheme tt;
  const _ConfirmationBanner({
    required this.affectedCount,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: DonyColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: DonyColors.success, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Trajet annulé',
                style: tt.titleMedium?.copyWith(color: DonyColors.success),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            '$affectedCount expéditeur${affectedCount > 1 ? 's' : ''} remboursé${affectedCount > 1 ? 's' : ''} automatiquement.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                icon: Icons.flight_takeoff_rounded,
                backgroundColor: cs.primaryContainer,
                iconColor: cs.primary,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  '${suggestion.departureCity} → ${suggestion.arrivalCity}',
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: DateFormat('dd MMM yyyy').format(suggestion.departureDate),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: DonySpacing.md),
              _Chip(
                icon: Icons.scale_outlined,
                label: '${suggestion.availableKg} kg dispo',
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: DonySpacing.md),
              _Chip(
                icon: Icons.euro_rounded,
                label: '${suggestion.pricePerKg.toStringAsFixed(0)} €/kg',
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Envoyer une demande',
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
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  const _Chip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
