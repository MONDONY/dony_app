import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  // `final` (pas `const`) : la question sur la commission interpole le taux
  // courant chargé depuis le backend (donyCommissionPercentLabel).
  static List<_FaqSectionData> get _sections => <_FaqSectionData>[
    const _FaqSectionData(
      title: 'Compte & identité',
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          q: 'Pourquoi la vérification d\'identité est-elle obligatoire ?',
          a: 'La vérification d\'identité est exigée par la réglementation financière européenne. Elle nous permet de lutter contre la fraude et de protéger tous les utilisateurs de yadony.',
        ),
        _FaqItem(
          q: 'Combien de temps prend la validation ?',
          a: 'La validation est généralement instantanée via Stripe Identity. En cas de vérification manuelle, le délai est de 24 à 72 h.',
        ),
        _FaqItem(
          q: 'Quels documents sont acceptés ?',
          a: "Carte nationale d'identité, passeport ou titre de séjour en cours de validité. Le document doit être lisible et non expiré.",
        ),
        _FaqItem(
          q: 'Puis-je utiliser yadony sans vérifier mon identité ?',
          a: 'Tu peux explorer les annonces sans vérifier ton identité, mais tu ne peux pas envoyer ni transporter de colis. La vérification d\'identité est indispensable pour effectuer des transactions.',
        ),
      ],
    ),
    const _FaqSectionData(
      title: 'Annonces & demandes',
      iconAsset: 'package',
      items: [
        _FaqItem(
          q: 'Comment publier un trajet en tant que voyageur ?',
          a: 'Dans l\'onglet Accueil, tape sur "Publier un trajet". Renseigne ta ville de départ, ta destination, la date et la capacité disponible (kg).',
        ),
        _FaqItem(
          q: 'Comment publier une demande d\'envoi ?',
          a: 'Dans l\'onglet Accueil, tape sur "Envoyer un colis". Décris ce que tu veux envoyer, le poids estimé et le destinataire. Les voyageurs intéressés feront des offres.',
        ),
        _FaqItem(
          q: 'Puis-je modifier ma demande après publication ?',
          a: 'Tu peux modifier une demande tant qu\'aucune offre n\'a été acceptée. Une fois un voyageur accepté, contacte le support pour toute modification.',
        ),
      ],
    ),
    _FaqSectionData(
      title: 'Paiements & remboursements',
      iconAsset: 'banknote',
      items: [
        const _FaqItem(
          q: 'Quand suis-je débité ?',
          a: 'Tu es débité à l\'acceptation du voyageur. Les fonds sont bloqués et sécurisés, et ne sont transférés au voyageur qu\'à la confirmation de livraison.',
        ),
        const _FaqItem(
          q: 'Comment se passe le remboursement en cas d\'annulation ?',
          a: 'En cas d\'annulation avant la remise du colis, tu es intégralement remboursé sous 3 à 5 jours ouvrés sur ta carte bancaire.',
        ),
        _FaqItem(
          q: 'Pourquoi une commission de $donyCommissionPercentLabel % ?',
          a: 'La commission couvre les frais de paiement sécurisé (Stripe), l\'assurance de la transaction, le support et le développement de la plateforme.',
        ),
        const _FaqItem(
          q: 'Les paiements sont-ils sécurisés ?',
          a: 'Oui. Tous les paiements transitent par Stripe, certifié PCI DSS niveau 1. Tes données bancaires ne sont jamais stockées sur nos serveurs.',
        ),
      ],
    ),
    const _FaqSectionData(
      title: 'Suivi & livraison',
      iconAsset: 'package',
      items: [
        _FaqItem(
          q: 'Comment fonctionne le QR de remise ?',
          a: 'À la remise du colis, le voyageur lit ton QR code (ou vice-versa). Cela confirme la prise en charge et déclenche le suivi. En cas d\'absence de connexion, la lecture est mémorisée et synchronisée à la reconnexion.',
        ),
        _FaqItem(
          q: 'Que faire si le colis n\'arrive pas ?',
          a: 'Ouvre un litige depuis l\'onglet "Mes litiges" dans les 48 h suivant la date de livraison prévue. Notre équipe intervient sous 24 h.',
        ),
        _FaqItem(
          q: 'Quel est le délai de livraison moyen ?',
          a: 'Le délai dépend du trajet choisi. Il est indiqué sur chaque annonce de voyageur. Compte en général 1 à 10 jours selon la destination.',
        ),
      ],
    ),
    _FaqSectionData(
      title: 'Sécurité & données',
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          q: 'Que se passe-t-il si mon colis est perdu ?',
          a: 'yadony ne couvre pas automatiquement la perte d\'un colis. En cas de perte confirmée après recherche de notre équipe, un remboursement jusqu\'à $donyReimbursementCapLabel € peut être accordé si toutes les conditions suivantes sont respectées : paiement effectué par carte via yadony (jamais en espèces) ; aucun échange ou paiement effectué en dehors de la plateforme avec le voyageur ; colis scanné via QR code yadony au dépôt et à la remise ; litige signalé dans l\'application dans les 15 jours suivant la date de livraison prévue ; contenu du colis conforme aux objets autorisés par yadony. Le remboursement n\'est jamais automatique et reste soumis à validation de l\'équipe yadony après investigation.',
        ),
        const _FaqItem(
          q: 'Que faire en cas de litige avec un voyageur ?',
          a: 'Ouvre un litige depuis ton profil → "Mes litiges". Fournis les preuves (photos, messages). Notre équipe arbitre dans les 48 h.',
        ),
        const _FaqItem(
          q: 'Mes données personnelles sont-elles protégées ?',
          a: 'Oui. Nos données sont chiffrées AES-256 au repos et TLS en transit. Nous ne vendons aucune donnée à des tiers. Conformité RGPD garantie.',
        ),
        const _FaqItem(
          q: 'Comment supprimer mon compte ?',
          a: 'Dans Paramètres → Compte → Supprimer mon compte. La suppression est définitive et irréversible après un délai légal de 30 jours.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: donyReimbursementCapListenable,
      builder: (context, _, _) => DonyPageScaffold(
        title: 'FAQ & aide',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toutes les réponses aux questions fréquentes.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xl),
            ...List.generate(_sections.length, (i) {
              return _FaqSection(data: _sections[i])
                  .animate()
                  .fadeIn(delay: (i * 80).ms, duration: 300.ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic);
            }),
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.data});

  final _FaqSectionData data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.base,
                DonySpacing.base,
                DonySpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: data.iconAsset == 'package'
                        ? const DonyEmoji.parcel(size: 18)
                        : DonyIcon(data.iconAsset, color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    data.title,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            ...data.items.map((item) => _FaqTile(item: item)),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            0,
            DonySpacing.base,
            DonySpacing.base,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: cs.primary,
          collapsedIconColor: cs.onSurfaceVariant,
          title: Text(
            item.q,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          children: [
            Text(
              item.a,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSectionData {
  const _FaqSectionData({
    required this.title,
    required this.iconAsset,
    required this.items,
  });

  final String title;
  final String iconAsset;
  final List<_FaqItem> items;
}

class _FaqItem {
  const _FaqItem({required this.q, required this.a});

  final String q;
  final String a;
}
