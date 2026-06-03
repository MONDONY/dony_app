import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface == Colors.white
          ? const Color(0xFFF4F6F8)
          : cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Confidentialité',
          style: tt.headlineLarge,
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocBuilder<PrivacySettingsBloc, PrivacySettingsState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Bandeau vert informatif ────────────────────────────
                _ProtectedNumberBanner(),
                const SizedBox(height: DonySpacing.xl),

                // ── 2. Section "QUI PEUT ME CONTACTER" ───────────────────
                _SectionLabel('QUI PEUT ME CONTACTER'),
                const SizedBox(height: DonySpacing.sm),
                _KycToggleCard(state: state),
                const SizedBox(height: DonySpacing.xl),

                // ── 3. Section "BLOCAGE" ──────────────────────────────────
                _SectionLabel('BLOCAGE'),
                const SizedBox(height: DonySpacing.sm),
                _BlockedUsersCard(),
                const SizedBox(height: DonySpacing.xxl),

                // ── 4. Section "AMÉLIORATION DE L'APP" ────────────────────
                _SectionLabel("AMÉLIORATION DE L'APP"),
                const SizedBox(height: DonySpacing.sm),
                const _AnalyticsConsentCard(),
                const SizedBox(height: DonySpacing.xxl),

                // ── 5. Lien textuel vers Données ──────────────────────────
                Text(
                  'Pour télécharger tes données ou supprimer ton compte, va dans Paramètres › Données.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}

// ── Bandeau vert ──────────────────────────────────────────────────────────────

class _ProtectedNumberBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134F2D), Color(0xFF1A6B3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 22)),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton numéro est protégé',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  "Personne ne voit ton numéro tant qu'une offre n'est pas acceptée. "
                  "Une fois l'accord conclu, toi et ton partenaire échangez vos numéros "
                  "pour organiser la remise.",
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card toggle KYC ──────────────────────────────────────────────────────────

class _KycToggleCard extends StatelessWidget {
  const _KycToggleCard({required this.state});
  final PrivacySettingsState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isLoading = state is PrivacySettingsLoading;
    final contactKycOnly = state is PrivacySettingsLoaded
        ? (state as PrivacySettingsLoaded).contactKycOnly
        : false;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            // Icône dans container vert clair
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('✅', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profils vérifiés uniquement',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Seuls les utilisateurs ayant validé leur identité (KYC) peuvent t'envoyer une offre",
                    style: tt.bodySmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Switch(
              value: contactKycOnly,
              activeColor: const Color(0xFF1A6B3C),
              onChanged: isLoading
                  ? null
                  : (v) => context
                      .read<PrivacySettingsBloc>()
                      .add(ContactKycOnlyToggled(v)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card consentement analytics (révocable RGPD) ──────────────────────────────

class _AnalyticsConsentCard extends StatelessWidget {
  const _AnalyticsConsentCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hive = getIt<HiveService>();

    return ValueListenableBuilder<Box>(
      valueListenable:
          hive.listenUserPrefs(keys: const [HiveService.kAnalyticsConsent]),
      builder: (context, box, _) {
        final enabled = box.get(HiveService.kAnalyticsConsent) == true;

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('📊', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: DonySpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Statistiques d'utilisation",
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Mesure anonyme de l'usage pour améliorer l'app. "
                        "Jamais tes paiements ni ton identité.",
                        style: tt.bodySmall?.copyWith(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Switch(
                  value: enabled,
                  onChanged: (v) {
                    getIt<AnalyticsService>()
                        .setConsent(granted: v, source: 'settings');
                    unawaited(getIt<AnalyticsService>().logEvent(
                      AnalyticsEvents.analyticsConsentChanged,
                      properties: {'granted': v},
                    ));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Card utilisateurs bloqués ─────────────────────────────────────────────────

class _BlockedUsersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Le compteur sera 0 jusqu'à l'implémentation de Task 10
    const int blockedCount = 0;

    return GestureDetector(
      onTap: () => context.go('/settings/privacy/blocked-users'),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Row(
            children: [
              // Icône dans container rouge clair
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🚫', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: DonySpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Utilisateurs bloqués',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gérer les personnes que tu as bloquées',
                      style: tt.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              if (blockedCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Text(
                    '$blockedCount',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF1A6B3C),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Text(
      label,
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
