import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/l10n/l10n.dart';
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
  // Fonction (pas un champ figé) : les réponses de tarification interpolent
  // les valeurs courantes chargées depuis le backend, et tout le contenu suit
  // la langue active — jamais de texte traduit gardé dans le State.
  static List<_FaqSectionData> _sections(
    AppLocalizations l,
  ) => <_FaqSectionData>[
    _FaqSectionData(
      id: 'account',
      title: l.faqAccountTitle,
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          id: 'identity_required',
          q: l.faqAccountIdentityRequiredQ,
          a: l.faqAccountIdentityRequiredA,
        ),
        _FaqItem(
          id: 'identity_delay',
          q: l.faqAccountIdentityDelayQ,
          a: l.faqAccountIdentityDelayA,
        ),
        _FaqItem(
          id: 'identity_documents',
          q: l.faqAccountIdentityDocumentsQ,
          a: l.faqAccountIdentityDocumentsA,
        ),
        _FaqItem(
          id: 'without_identity',
          q: l.faqAccountWithoutIdentityQ,
          a: l.faqAccountWithoutIdentityA,
        ),
      ],
    ),
    _FaqSectionData(
      id: 'announcements',
      title: l.faqAnnouncementsTitle,
      iconAsset: 'package',
      items: [
        _FaqItem(
          id: 'publish_trip',
          q: l.faqAnnouncementsPublishTripQ,
          a: l.faqAnnouncementsPublishTripA,
        ),
        _FaqItem(
          id: 'publish_request',
          q: l.faqAnnouncementsPublishRequestQ,
          a: l.faqAnnouncementsPublishRequestA,
        ),
        _FaqItem(
          id: 'edit_request',
          q: l.faqAnnouncementsEditRequestQ,
          a: l.faqAnnouncementsEditRequestA,
        ),
      ],
    ),
    _FaqSectionData(
      id: 'payments',
      title: l.faqPaymentsTitle,
      iconAsset: 'banknote',
      items: [
        _FaqItem(
          id: 'payment_timing',
          q: l.faqPaymentsPaymentTimingQ,
          a: l.faqPaymentsPaymentTimingA,
        ),
        _FaqItem(
          id: 'refund',
          q: l.faqPaymentsRefundQ,
          a: l.faqPaymentsRefundA,
        ),
        _FaqItem(
          id: 'commission',
          q: l.faqPaymentsCommissionQ(commissionPercentLabel(l)),
          a: l.faqPaymentsCommissionA,
        ),
        _FaqItem(
          id: 'payment_security',
          q: l.faqPaymentsPaymentSecurityQ,
          a: l.faqPaymentsPaymentSecurityA,
        ),
      ],
    ),
    _FaqSectionData(
      id: 'delivery',
      title: l.faqDeliveryTitle,
      iconAsset: 'package',
      items: [
        _FaqItem(
          id: 'handover_qr',
          q: l.faqDeliveryHandoverQrQ,
          a: l.faqDeliveryHandoverQrA,
        ),
        _FaqItem(
          id: 'parcel_missing',
          q: l.faqDeliveryParcelMissingQ,
          a: l.faqDeliveryParcelMissingA,
        ),
        _FaqItem(
          id: 'delivery_delay',
          q: l.faqDeliveryDeliveryDelayQ,
          a: l.faqDeliveryDeliveryDelayA,
        ),
      ],
    ),
    _FaqSectionData(
      id: 'safety',
      title: l.faqSafetyTitle,
      iconAsset: 'shield-check',
      items: [
        _FaqItem(
          id: 'lost_parcel',
          q: l.faqSafetyLostParcelQ,
          a: l.faqSafetyLostParcelA(reimbursementCapLabel(l)),
        ),
        _FaqItem(id: 'dispute', q: l.faqSafetyDisputeQ, a: l.faqSafetyDisputeA),
        _FaqItem(
          id: 'personal_data',
          q: l.faqSafetyPersonalDataQ,
          a: l.faqSafetyPersonalDataA,
        ),
        _FaqItem(
          id: 'delete_account',
          q: l.faqSafetyDeleteAccountQ,
          a: l.faqSafetyDeleteAccountA,
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

  static List<_FaqSectionData> _filterSections(
    String rawQuery,
    AppLocalizations l,
  ) {
    final sections = _sections(l);
    final query = _normalize(rawQuery);
    if (query.isEmpty) {
      return sections;
    }

    return sections
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
    final l = context.l10n;

    return ValueListenableBuilder<double>(
      valueListenable: donyReimbursementCapListenable,
      builder: (context, _, _) => BlocBuilder<FaqBloc, FaqState>(
        builder: (context, state) {
          final sections = _filterSections(state.query, l);
          return DonyPageScaffold(
            title: l.profileHelpFaq,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.faqFindAnswerTitle,
                  style: tt.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.faqFindAnswerSubtitle,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.base),
                DonyTextField(
                  key: const Key('faq-search-field'),
                  hint: l.faqSearchHint,
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
            context.l10n.faqEmptyResultsTitle,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            context.l10n.faqEmptyResultsDescription,
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
                      context.l10n.faqContactCardTitle,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      context.l10n.faqContactCardSubtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          DonyButton(
            label: context.l10n.profileHelpContactSupport,
            variant: DonyButtonVariant.secondary,
            iconAsset: 'mail',
            onPressed: () {
              context.read<FaqBloc>().add(const FaqContactRequested());
              context.push('/support');
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
