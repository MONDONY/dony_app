import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:dony/features/settings/presentation/widgets/unverified_contact_warning_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  /// Désactiver « profils vérifiés uniquement » ouvre le compte aux expéditeurs
  /// dont l'identité n'a pas été vérifiée : on demande une confirmation explicite
  /// avant de l'appliquer. Réactiver la protection ne demande rien, c'est le sens
  /// prudent.
  Future<void> _onContactKycOnlyChanged(
    BuildContext context,
    bool value,
  ) async {
    final bloc = context.read<PrivacySettingsBloc>();
    if (!value) {
      final accepted = await UnverifiedContactWarningSheet.show(context);
      if (accepted != true) {
        return;
      }
    }
    bloc.add(ContactKycOnlyToggled(value));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface == Colors.white
          ? const Color(0xFFF4F6F8)
          : cs.surface,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Confidentialité', style: tt.headlineLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocConsumer<PrivacySettingsBloc, PrivacySettingsState>(
        listener: (context, state) {
          if (state is PrivacySettingsLoaded && state.saveFailed) {
            DonySnackbar.show(
              context,
              message: 'Réglage non enregistré, vérifie ta connexion.',
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final loaded = state is PrivacySettingsLoaded ? state : null;
          final isLoading = state is PrivacySettingsLoading;

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
                _ProtectedNumberBanner(
                  phoneHidden: loaded?.hidePhoneNumber ?? false,
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── 2. Section "QUI PEUT ME CONTACTER" ───────────────────
                const SettingsSectionHeader('QUI PEUT ME CONTACTER'),
                SettingsFlatGroup(
                  children: [
                    _SettingsToggleRow(
                      emoji: '✅',
                      emojiBackground: const Color(0xFFE8F5EE),
                      title: 'Profils vérifiés uniquement',
                      subtitle:
                          "Seuls les utilisateurs ayant validé leur identité peuvent t'envoyer une offre",
                      // Défaut à true, comme la colonne côté serveur : afficher
                      // « désactivé » tant que le chargement n'a pas abouti
                      // ferait croire à tort que le compte est ouvert à tous.
                      value: loaded?.contactKycOnly ?? true,
                      activeColor: const Color(0xFF1A6B3C),
                      onChanged: isLoading
                          ? null
                          : (v) => _onContactKycOnlyChanged(context, v),
                    ),
                    const _SettingsRowDivider(),
                    _SettingsToggleRow(
                      emoji: '📵',
                      emojiBackground: const Color(0xFFEAF1FF),
                      title: 'Masquer mon numéro',
                      subtitle:
                          "Ton numéro n'est jamais communiqué, même après une offre acceptée. "
                          'Tes échanges passent par la messagerie Yadony.',
                      value: loaded?.hidePhoneNumber ?? false,
                      onChanged: isLoading
                          ? null
                          : (v) => context.read<PrivacySettingsBloc>().add(
                              HidePhoneNumberToggled(v),
                            ),
                    ),
                  ],
                ),
                // Rappel persistant : sans lui, l'utilisateur oublie qu'il a
                // ouvert son compte aux profils non vérifiés, un interrupteur
                // éteint étant peu bavard.
                if (loaded != null && !loaded.contactKycOnly) ...[
                  const SizedBox(height: DonySpacing.sm),
                  const _UnverifiedExposureNotice(),
                ],
                const SizedBox(height: DonySpacing.xl),

                // ── 3. Section "BLOCAGE" ──────────────────────────────────
                const SettingsSectionHeader('BLOCAGE'),
                const _BlockedUsersCard(),
                const SizedBox(height: DonySpacing.xxl),

                // ── 4. Section "AMÉLIORATION DE L'APP" ────────────────────
                const SettingsSectionHeader("AMÉLIORATION DE L'APP"),
                const _AnalyticsConsentCard(),
                const SizedBox(height: DonySpacing.xxl),

                // ── 5. Lien textuel vers Données ──────────────────────────
                Text(
                  'Pour télécharger tes données ou supprimer ton compte, va dans Paramètres › Données.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}

// ── Bandeau vert ──────────────────────────────────────────────────────────────

class _ProtectedNumberBanner extends StatelessWidget {
  const _ProtectedNumberBanner({required this.phoneHidden});

  /// Le bandeau décrit la règle réellement appliquée : promettre un échange de
  /// numéros à quelqu'un qui vient de le masquer serait faux.
  final bool phoneHidden;

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
                  phoneHidden
                      ? 'Ton numéro reste masqué'
                      : 'Ton numéro est protégé',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  phoneHidden
                      ? "Ton numéro n'est communiqué à personne, même une fois "
                            "l'accord conclu. Tes partenaires te joignent par la "
                            'messagerie Yadony, et tu peux toujours appeler le leur.'
                      : "Personne ne voit ton numéro tant qu'une offre n'est pas "
                            "acceptée. Une fois l'accord conclu, toi et ton "
                            'partenaire échangez vos numéros pour organiser la remise.',
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
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

// ── Rappel d'exposition aux profils non vérifiés ──────────────────────────────

class _UnverifiedExposureNotice extends StatelessWidget {
  const _UnverifiedExposureNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('triangle-alert', color: cs.warning, size: 16),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Les profils non vérifiés peuvent te faire des demandes. '
              "Yadony n'est pas responsable des difficultés rencontrées avec eux.",
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne de réglage à interrupteur ───────────────────────────────────────────

/// Ligne « icône + titre + description + Switch » des listes groupées de
/// Confidentialité. Un seul widget pour les trois réglages de l'écran : ils
/// partageaient jusqu'ici une mise en page recopiée à l'identique.
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.emoji,
    required this.emojiBackground,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final String emoji;
  final Color emojiBackground;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
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
              color: emojiBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Séparateur des listes groupées : aligné sur le texte, pas sur le bord, pour
/// que l'icône reste visuellement rattachée à sa ligne.
class _SettingsRowDivider extends StatelessWidget {
  const _SettingsRowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: DonySpacing.base + 36 + DonySpacing.base,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}

// ── Card consentement analytics (révocable RGPD) ──────────────────────────────

class _AnalyticsConsentCard extends StatelessWidget {
  const _AnalyticsConsentCard();

  @override
  Widget build(BuildContext context) {
    final hive = getIt<HiveService>();

    return ValueListenableBuilder<Box>(
      valueListenable: hive.listenUserPrefs(
        keys: const [HiveService.kAnalyticsConsent],
      ),
      builder: (context, box, _) {
        final enabled = box.get(HiveService.kAnalyticsConsent) == true;

        return SettingsFlatGroup(
          children: [
            _SettingsToggleRow(
              emoji: '📊',
              emojiBackground: const Color(0xFFEAF1FF),
              title: "Statistiques d'utilisation",
              subtitle:
                  "Mesure anonyme de l'usage pour améliorer l'app. "
                  'Jamais tes paiements ni ton identité.',
              value: enabled,
              onChanged: (v) async {
                // await requis : setConsent() active/désactive le SDK natif
                // PostHog de façon asynchrone (pont plateforme). Sans await,
                // le logEvent() ci-dessous peut s'exécuter avant que le SDK
                // soit réellement (dés)activé et être silencieusement ignoré.
                await getIt<AnalyticsService>().setConsent(
                  granted: v,
                  source: 'settings',
                );
                unawaited(
                  getIt<AnalyticsService>().logEvent(
                    AnalyticsEvents.analyticsConsentChanged,
                    properties: {'granted': v},
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Card utilisateurs bloqués ─────────────────────────────────────────────────

/// Carte « Utilisateurs bloqués » avec son compteur.
///
/// Porte sa propre instance de [BlockedUsersBloc] : la route Confidentialité
/// n'expose que [PrivacySettingsBloc], et le compteur n'a pas de raison de
/// remonter jusqu'à elle.
class _BlockedUsersCard extends StatefulWidget {
  const _BlockedUsersCard();

  @override
  State<_BlockedUsersCard> createState() => _BlockedUsersCardState();
}

class _BlockedUsersCardState extends State<_BlockedUsersCard> {
  late final BlockedUsersBloc _bloc;
  StreamSubscription<BlockChange>? _blockSub;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<BlockedUsersBloc>()..add(const BlockedUsersLoadRequested());
    // Abonnement côté widget : BlockedUsersBloc est une factory, chaque écran a
    // la sienne, et c'est bien cette instance-ci qu'il faut recharger quand un
    // blocage ou un déblocage aboutit ailleurs.
    _blockSub = _blockEvents()?.changes.listen((_) {
      if (!mounted) return;
      _bloc.add(const BlockedUsersLoadRequested());
    });
  }

  BlockEventsService? _blockEvents() {
    try {
      return getIt.isRegistered<BlockEventsService>()
          ? getIt<BlockEventsService>()
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BlockedUsersBloc>.value(
      value: _bloc,
      child: BlocBuilder<BlockedUsersBloc, BlockedUsersState>(
        builder: (context, state) => _BlockedUsersCardView(
          // Null pendant le chargement : la vue réserve alors la place du badge
          // au lieu de le faire apparaître d'un coup et de décaler la ligne.
          blockedCount: switch (state) {
            BlockedUsersLoaded(:final users) => users.length,
            BlockedUsersUnblocking(:final currentUsers) => currentUsers.length,
            // Échec de chargement : pas de badge plutôt qu'un squelette qui
            // tournerait indéfiniment. La liste complète reste accessible d'un
            // tap, avec son propre message d'erreur.
            BlockedUsersError() => 0,
            _ => null,
          },
        ),
      ),
    );
  }
}

class _BlockedUsersCardView extends StatelessWidget {
  const _BlockedUsersCardView({required this.blockedCount});

  /// `null` tant que la liste n'est pas connue.
  final int? blockedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final count = blockedCount;

    return GestureDetector(
      onTap: () => context.go('/settings/privacy/blocked-users'),
      child: SettingsFlatGroup(
        children: [
          Padding(
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
                if (count == null) ...[
                  // Même gabarit que le badge : la ligne ne bouge pas quand le
                  // compteur arrive, qu'il y ait des blocages ou aucun.
                  const DonySkeletonBox(width: 24, height: 22, radius: 6),
                  const SizedBox(width: DonySpacing.xs),
                ] else if (count > 0) ...[
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
                      '$count',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                ],
                const DonyIcon(
                  'chevron-right',
                  color: Color(0xFF1A6B3C),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
