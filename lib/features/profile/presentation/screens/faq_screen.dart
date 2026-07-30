import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  // `final` (pas `const`) : les réponses de tarification interpolent les
  // valeurs courantes chargées depuis le backend.
  static List<_FaqSectionData> get _sections => <_FaqSectionData>[
    const _FaqSectionData(
      id: 'account',
      title: 'Compte & identité',
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          id: 'identity_required',
          q: 'Pourquoi la vérification d\'identité est-elle obligatoire ?',
          a: 'Elle peut être demandée par nos partenaires de paiement et par les obligations applicables à certaines transactions. Elle nous permet aussi de lutter contre la fraude et de protéger les utilisateurs de Yadony.',
        ),
        _FaqItem(
          id: 'identity_delay',
          q: 'Combien de temps prend la validation ?',
          a: 'La validation est souvent réalisée en quelques minutes via Stripe Identity. Si une vérification manuelle est nécessaire, le délai peut être plus long.',
        ),
        _FaqItem(
          id: 'identity_documents',
          q: 'Quels documents sont acceptés ?',
          a: "Carte nationale d'identité, passeport ou titre de séjour en cours de validité. Le document doit être lisible et non expiré.",
        ),
        _FaqItem(
          id: 'without_identity',
          q: 'Puis-je utiliser Yadony sans vérifier mon identité ?',
          a: 'Tu peux explorer les annonces sans vérifier ton identité. Certaines actions, notamment envoyer, transporter ou recevoir des paiements, peuvent nécessiter une vérification.',
        ),
      ],
    ),
    const _FaqSectionData(
      id: 'announcements',
      title: 'Annonces & demandes',
      iconAsset: 'package',
      items: [
        _FaqItem(
          id: 'publish_trip',
          q: 'Comment publier un trajet en tant que voyageur ?',
          a: 'Depuis Accueil ou Activités, choisis "Publier un trajet". Renseigne la ville de départ, la destination, la date et la capacité disponible.',
        ),
        _FaqItem(
          id: 'publish_request',
          q: 'Comment publier une demande d\'envoi ?',
          a: 'Depuis Accueil ou Activités, choisis "Envoyer un colis". Décris le colis, son poids estimé et le destinataire. Les voyageurs compatibles pourront proposer une offre.',
        ),
        _FaqItem(
          id: 'edit_request',
          q: 'Puis-je modifier ma demande après publication ?',
          a: 'Tu peux modifier une demande tant qu\'aucune offre n\'a été acceptée. Après acceptation, contacte le support si une information importante doit être corrigée.',
        ),
      ],
    ),
    _FaqSectionData(
      id: 'payments',
      title: 'Paiements & remboursements',
      iconAsset: 'banknote',
      items: [
        const _FaqItem(
          id: 'payment_timing',
          q: 'Quand suis-je débité ?',
          a: 'Pour un paiement par carte, les fonds sont sécurisés lors de l\'acceptation puis libérés selon l\'avancement de la livraison. Pour les espèces et le Mobile Money, suis les indications affichées au moment de choisir le moyen de paiement.',
        ),
        const _FaqItem(
          id: 'refund',
          q: 'Comment se passe le remboursement en cas d\'annulation ?',
          a: 'Le remboursement dépend du moyen de paiement et du moment de l\'annulation. Un paiement par carte est recrédité sur le moyen utilisé après traitement. Pour le Mobile Money, le délai dépend de l\'opérateur. En espèces, Yadony ne détient pas les fonds et ne peut pas effectuer automatiquement le remboursement.',
        ),
        _FaqItem(
          id: 'commission',
          q: 'Pourquoi une commission de $donyCommissionPercentLabel % ?',
          a: 'La commission contribue aux frais de paiement, au support, à la prévention de la fraude et au développement de la plateforme.',
        ),
        const _FaqItem(
          id: 'payment_security',
          q: 'Les paiements sont-ils sécurisés ?',
          a: 'Les paiements en ligne sont traités par les prestataires indiqués dans l\'application. Yadony ne stocke pas les données complètes de ta carte. Un paiement en espèces n\'est pas placé sous séquestre : ne paie jamais en dehors du parcours convenu dans l\'application.',
        ),
      ],
    ),
    const _FaqSectionData(
      id: 'delivery',
      title: 'Suivi & livraison',
      iconAsset: 'package',
      items: [
        _FaqItem(
          id: 'handover_qr',
          q: 'Comment fonctionne le QR de remise ?',
          a: 'À la remise du colis, le QR code confirme la prise en charge et déclenche le suivi. Sans connexion, la lecture est mémorisée sur l\'appareil puis synchronisée à la reconnexion.',
        ),
        _FaqItem(
          id: 'parcel_missing',
          q: 'Que faire si le colis n\'arrive pas ?',
          a: 'Ouvre un litige depuis "Mes litiges" dès que tu constates le problème. Ajoute les photos, messages et informations de suivi disponibles. Les délais applicables sont rappelés dans le parcours de signalement.',
        ),
        _FaqItem(
          id: 'delivery_delay',
          q: 'Quel est le délai de livraison moyen ?',
          a: 'Le délai dépend du trajet choisi et de la date annoncée par le voyageur. Vérifie toujours les informations du trajet avant d\'accepter une offre.',
        ),
      ],
    ),
    _FaqSectionData(
      id: 'safety',
      title: 'Sécurité & données',
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          id: 'lost_parcel',
          q: 'Que se passe-t-il si mon colis est perdu ?',
          a: 'Yadony ne couvre pas automatiquement la perte d\'un colis. Après investigation, un remboursement jusqu\'à $donyReimbursementCapLabel € peut être accordé si toutes les conditions sont respectées :\n\n• paiement par carte effectué dans Yadony ;\n• aucun paiement ou accord conclu hors plateforme ;\n• QR codes de dépôt et de remise utilisés ;\n• litige ouvert dans les 15 jours suivant la date prévue ;\n• contenu conforme aux objets autorisés.\n\nToute décision reste soumise à la validation de l\'équipe Yadony.',
        ),
        const _FaqItem(
          id: 'dispute',
          q: 'Que faire en cas de litige avec un voyageur ?',
          a: 'Ouvre "Mes litiges" depuis ton profil et fournis les éléments utiles : photos, messages et suivi. Notre équipe examine ensuite le dossier et te tient informé dans l\'application.',
        ),
        const _FaqItem(
          id: 'personal_data',
          q: 'Mes données personnelles sont-elles protégées ?',
          a: 'Yadony applique des mesures de sécurité pour protéger les données et ne vend pas tes informations personnelles. Tu peux consulter la politique de confidentialité et gérer tes préférences dans Paramètres.',
        ),
        const _FaqItem(
          id: 'delete_account',
          q: 'Comment supprimer mon compte ?',
          a: 'Dans Paramètres → Données et compte → Supprimer mon compte, tu peux choisir une pause réversible de 30 jours ou une suppression immédiate définitive. Une transaction en cours peut temporairement bloquer la suppression.',
        ),
      ],
    ),
  ];

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[àâäáãå]'), 'a')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[ñ]'), 'n')
        .replaceAll(RegExp('[òóôöõ]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ýÿ]'), 'y');
  }

  static List<_FaqSectionData> _filterSections(String rawQuery) {
    final query = _normalize(rawQuery);
    if (query.isEmpty) {
      return _sections;
    }

    return _sections
        .map((section) {
          final sectionMatches = _normalize(section.title).contains(query);
          final items = sectionMatches
              ? section.items
              : section.items
                    .where(
                      (item) =>
                          _normalize(item.q).contains(query) ||
                          _normalize(item.a).contains(query),
                    )
                    .toList();
          return section.copyWith(items: items);
        })
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HelpCenterBloc>().add(const HelpCenterOpenRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: donyReimbursementCapListenable,
      builder: (context, _, _) => BlocBuilder<FaqBloc, FaqState>(
        builder: (context, state) {
          final sections = _filterSections(state.query);
          return DonyPageScaffold(
            title: 'FAQ & aide',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trouver une réponse',
                  style: tt.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Recherche une réponse ou parcours les catégories.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.base),
                DonyTextField(
                  key: const Key('faq-search-field'),
                  hint: 'Rechercher dans l’aide',
                  prefixWidget: Padding(
                    padding: const EdgeInsets.all(DonySpacing.md),
                    child: DonyIcon(
                      'search',
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (query) =>
                      context.read<FaqBloc>().add(FaqSearchChanged(query)),
                ),
                const SizedBox(height: DonySpacing.xl),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: sections.isEmpty
                      ? const _FaqEmptyState(key: Key('faq-empty-state'))
                      : Column(
                          key: ValueKey(state.query),
                          children: List.generate(sections.length, (i) {
                            return _FaqSection(data: sections[i])
                                .animate()
                                .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                                .slideY(
                                  begin: 0.04,
                                  curve: Curves.easeOutCubic,
                                );
                          }),
                        ),
                ),
                const SizedBox(height: DonySpacing.md),
                const _ContactSupportCard(),
              ],
            ),
          );
        },
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
          boxShadow: DonyShadows.card,
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: data.iconAsset == 'package'
                        ? const DonyEmoji.parcel(size: 18)
                        : DonyIcon(data.iconAsset, color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      data.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...data.items.map(
              (item) => _FaqTile(categoryId: data.id, item: item),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.categoryId, required this.item});

  final String categoryId;
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
          onExpansionChanged: (expanded) {
            if (expanded) {
              context.read<FaqBloc>().add(
                FaqQuestionOpened(categoryId: categoryId, questionId: item.id),
              );
            }
          },
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.a,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqEmptyState extends StatelessWidget {
  const _FaqEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: DonyIcon('search-x', color: cs.primary),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'Aucun résultat',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Essaie avec d\'autres mots-clés ou contacte notre équipe.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  const _ContactSupportCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon('headset', color: cs.primary, size: 28),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu n’as pas trouvé ta réponse ?',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      'Notre équipe est là pour t’aider.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          DonyButton(
            label: 'Contacter le support',
            variant: DonyButtonVariant.secondary,
            iconAsset: 'mail',
            onPressed: () {
              context.read<FaqBloc>().add(const FaqContactRequested());
              context.push('/profile/help/contact');
            },
          ),
        ],
      ),
    );
  }
}

class _FaqSectionData {
  const _FaqSectionData({
    required this.id,
    required this.title,
    required this.iconAsset,
    required this.items,
  });

  final String id;
  final String title;
  final String iconAsset;
  final List<_FaqItem> items;

  _FaqSectionData copyWith({List<_FaqItem>? items}) {
    return _FaqSectionData(
      id: id,
      title: title,
      iconAsset: iconAsset,
      items: items ?? this.items,
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.id, required this.q, required this.a});

  final String id;
  final String q;
  final String a;
}
