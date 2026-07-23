import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Rôle de publication : détermine tout le contenu (illustration, couleur,
/// engagements, destination du CTA) de [PublishIntroScreen].
enum PublishIntroRole { trip, parcel }

/// Écran d'introduction affiché avant le formulaire de publication.
///
/// Il rappelle la condition d'accès (identité vérifiée) et situe les
/// responsabilités du rôle avant d'ouvrir le formulaire. Le même écran sert
/// aux deux flux — voyageur (bleu) et expéditeur (terracotta) — pilotés par
/// [role].
class PublishIntroScreen extends StatelessWidget {
  const PublishIntroScreen({super.key, required this.role});

  final PublishIntroRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final config = _IntroConfig.of(role, cs);

    final authState = context.watch<AuthBloc>().state;
    final user = switch (authState) {
      final AuthAuthenticated s => s.user,
      final AuthProfileUpdated s => s.user,
      _ => null,
    };
    final verified = user?.isKycVerified ?? false;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const DonyAppBarBackButton(),
        title: Text(
          config.title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
              ),
              child:
                  Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Hero(asset: config.asset),
                          const SizedBox(height: DonySpacing.base),
                          _ConditionCallout(
                            verified: verified,
                            verifiedText: config.verifiedText,
                            onVerify: () => _startKyc(context, user),
                          ),
                          // Rappel voyageur : activer Stripe pour encaisser par carte —
                          // se masque tout seul si le compte est déjà opérationnel.
                          if (role == PublishIntroRole.trip)
                            const _StripeReminder(),
                          const SizedBox(height: DonySpacing.lg),
                          _SectionHeader(
                            iconAsset: config.sectionIcon,
                            accent: config.accent,
                            title: config.engagementsTitle,
                          ),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            config.engagementsIntro,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.md),
                          for (final rule in config.rules) ...[
                            _RuleRow(rule: rule, accent: config.accent),
                            const SizedBox(height: DonySpacing.sm),
                          ],
                          const SizedBox(height: DonySpacing.sm),
                          _WhyCard(
                            title: config.whyTitle,
                            bullets: config.whyBullets,
                            accent: config.accent,
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.03, curve: Curves.easeOutCubic),
            ),
          ),
          _CtaBar(
            verified: verified,
            accentVariant: config.buttonVariant,
            onContinue: () => config.onContinue(context),
            onVerify: () => _startKyc(context, user),
          ),
        ],
      ),
    );
  }

  void _startKyc(BuildContext context, UserModel? user) {
    KycRequiredBottomSheet.show(
      context,
      kycStatus: user?.kycStatus ?? 'NOT_STARTED',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config par rôle
// ─────────────────────────────────────────────────────────────────────────────

class _IntroConfig {
  const _IntroConfig({
    required this.title,
    required this.asset,
    required this.accent,
    required this.buttonVariant,
    required this.verifiedText,
    required this.sectionIcon,
    required this.engagementsTitle,
    required this.engagementsIntro,
    required this.rules,
    required this.whyTitle,
    required this.whyBullets,
    required this.onContinue,
  });

  final String title;
  final String asset;
  final Color accent;
  final DonyButtonVariant buttonVariant;
  final String verifiedText;
  final String sectionIcon;
  final String engagementsTitle;
  final String engagementsIntro;
  final List<_Rule> rules;
  final String whyTitle;
  final List<String> whyBullets;
  final void Function(BuildContext) onContinue;

  static _IntroConfig of(PublishIntroRole role, ColorScheme cs) {
    switch (role) {
      case PublishIntroRole.trip:
        return _IntroConfig(
          title: 'Publier un trajet',
          asset: 'assets/illustrations/publier_trajet.png',
          accent: cs.primary,
          buttonVariant: DonyButtonVariant.primary,
          verifiedText:
              'Identité vérifiée. Vous pouvez publier votre trajet en toute '
              'sécurité.',
          sectionIcon: 'route',
          engagementsTitle: 'Vos engagements de voyageur',
          engagementsIntro: 'En publiant, vous vous engagez à :',
          rules: const [
            _Rule(
              'user',
              'Transporter le colis **vous-même**, sans le '
                  'confier à un tiers.',
            ),
            _Rule(
              'calendar',
              'Respecter la **date** et l\'**itinéraire** '
                  'annoncés.',
            ),
            _Rule(
              'qr-code',
              '**Scanner le QR** à la remise et à la '
                  'livraison.',
            ),
            _Rule(
              'shield-check',
              'N\'accepter que des **contenus autorisés**, '
                  'jamais d\'objet illicite.',
            ),
            _Rule(
              'handshake',
              'Remettre le colis **au bon destinataire**, en '
                  'main propre.',
            ),
          ],
          whyTitle: 'Pourquoi publier',
          whyBullets: const [
            'Visible par des milliers d\'expéditeurs de la diaspora.',
            'Rentabilisez vos kilos libres à chaque voyage.',
            'Bâtissez une réputation avec les avis reçus.',
          ],
          onContinue: (context) =>
              context.push('/trips/create', extra: const CreateTripArgs()),
        );
      case PublishIntroRole.parcel:
        return _IntroConfig(
          title: 'Envoyer un colis',
          asset: 'assets/illustrations/envoie_colis.png',
          accent: cs.secondary,
          buttonVariant: DonyButtonVariant.accent,
          verifiedText:
              'Identité vérifiée. Vous pouvez publier votre demande d\'envoi '
              'en toute sécurité.',
          sectionIcon: 'package',
          engagementsTitle: 'Vos engagements d\'expéditeur',
          engagementsIntro: 'En envoyant un colis, vous certifiez :',
          rules: const [
            _Rule(
              'circle-check',
              'N\'envoyer que des **contenus licites** et '
                  'autorisés.',
            ),
            _Rule(
              'ban',
              'Aucun **objet interdit** (espèces, armes, produits '
                  'dangereux…).',
            ),
            _Rule('tag', 'Déclarer la **valeur réelle** du colis (max 500 €).'),
            _Rule(
              'square-pen',
              '**Emballer soigneusement** et décrire '
                  'précisément le contenu.',
            ),
            _Rule(
              'handshake',
              'Être présent à la **remise** et indiquer le '
                  'bon destinataire.',
            ),
          ],
          whyTitle: 'Comment ça marche',
          whyBullets: const [
            'Un voyageur transporte votre colis dans ses bagages.',
            'Paiement sécurisé, libéré à la livraison confirmée.',
            'Suivi par QR de la remise jusqu\'à la réception.',
          ],
          onContinue: (context) => PackageRequestCreateWizard.show(context),
        );
    }
  }
}

/// Un engagement : une icône + un texte où `**...**` marque les segments gras.
class _Rule {
  const _Rule(this.iconAsset, this.text);
  final String iconAsset;
  final String text;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    // Le cadre épouse le ratio carré de l'illustration : elle remplit toute la
    // largeur, sans bande de fond sur les côtés ni rognage du contenu.
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(asset, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }
}

class _ConditionCallout extends StatelessWidget {
  const _ConditionCallout({
    required this.verified,
    required this.verifiedText,
    required this.onVerify,
  });

  final bool verified;
  final String verifiedText;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (verified) {
      return _CalloutShell(
        bg: cs.successLight,
        iconBg: cs.success,
        iconAsset: 'circle-check',
        child: Text.rich(
          _boldSpans(verifiedText, tt.bodyMedium!, cs.onSurface),
          style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.45),
        ),
      );
    }

    // Non vérifié : tout l'encart est tapable et lance le portail KYC.
    return InkWell(
      onTap: onVerify,
      borderRadius: BorderRadius.circular(16),
      child: _CalloutShell(
        bg: cs.warningLight,
        iconBg: cs.warning,
        iconAsset: 'circle-alert',
        child: Text.rich(
          TextSpan(
            style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.45),
            children: [
              const TextSpan(text: 'Avant de publier, votre '),
              TextSpan(
                text: 'identité doit être vérifiée',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: '. Rendez-vous dans '),
              TextSpan(
                text: 'Profil › Vérifications',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.warning,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: ' pour la valider (2 min).'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalloutShell extends StatelessWidget {
  const _CalloutShell({
    required this.bg,
    required this.iconBg,
    required this.iconAsset,
    required this.child,
  });

  final Color bg;
  final Color iconBg;
  final String iconAsset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: DonyIcon(iconAsset, size: 15, color: DonyColors.neutral0),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Rappel promotionnel (voyageur) : configurer Stripe pour encaisser par carte.
/// Ne s'affiche que si le compte Connect n'est pas encore opérationnel.
class _StripeReminder extends StatelessWidget {
  const _StripeReminder();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      builder: (context, state) {
        final show =
            state is StripeAccountReady && state.accountStatus.needsOnboarding;
        if (!show) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final radius = BorderRadius.circular(16);

        return Padding(
          padding: const EdgeInsets.only(top: DonySpacing.base),
          // Teinte primary légère par-dessus la surface courante : lisible en
          // clair comme en sombre (pas de couleur claire figée).
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: radius,
              border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: () {
                  unawaited(
                    getIt<AnalyticsService>().logEvent(
                      AnalyticsEvents.publishIntroStripeReminderTapped,
                    ),
                  );
                  context.push('/connect/onboarding/intro');
                },
                child: Padding(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const DonyIcon(
                          'credit-card',
                          size: 17,
                          color: DonyColors.neutral0,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activez les paiements par carte',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configurez votre compte Stripe pour que vos '
                              'expéditeurs paient par carte, et recevez plus de '
                              'colis.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DonyIcon(
                          'chevron-right',
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.iconAsset,
    required this.accent,
    required this.title,
  });

  final String iconAsset;
  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: accent),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.accent});
  final _Rule rule;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.sm + 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadow.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: DonyIcon(rule.iconAsset, size: 17, color: accent),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                _boldSpans(rule.text, tt.bodyMedium!, cs.onSurface),
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({
    required this.title,
    required this.bullets,
    required this.accent,
  });

  final String title;
  final List<String> bullets;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: DonyShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          for (final b in bullets) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DonyIcon('sparkles', size: 14, color: accent),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      b,
                      style: tt.bodySmall?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.verified,
    required this.accentVariant,
    required this.onContinue,
    required this.onVerify,
  });

  final bool verified;
  final DonyButtonVariant accentVariant;
  final VoidCallback onContinue;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            DonySpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (verified)
                DonyButton(
                  label: 'Continuer',
                  iconRightAsset: 'arrow-right',
                  variant: accentVariant,
                  onPressed: onContinue,
                )
              else ...[
                DonyButton(
                  label: 'Vérifier mon identité',
                  iconAsset: 'lock',
                  variant: accentVariant,
                  onPressed: onVerify,
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  'Le bouton devient « Continuer » une fois l\'identité '
                  'vérifiée.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Construit un [TextSpan] où les segments entourés de `**` sont en gras.
TextSpan _boldSpans(String text, TextStyle base, Color color) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) {
      continue;
    }
    final bold = i.isOdd;
    spans.add(
      TextSpan(
        text: parts[i],
        style: base.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    );
  }
  return TextSpan(children: spans);
}
