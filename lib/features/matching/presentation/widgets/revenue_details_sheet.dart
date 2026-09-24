import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/revenue_details_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Feuille « Revenus » du hub Activités : un accordéon par devise, chaque
/// livraison dans la devise de son paiement. Aucune conversion ici, c'est
/// tout l'objet : la tuile, elle, porte un total converti (préfixé « ≈ »).
///
/// L'état plié/déplié vit dans la feuille, pas dans le cubit : il ne survit
/// pas à sa fermeture et ne concerne aucun autre écran.
class RevenueDetailsSheet extends StatefulWidget {
  const RevenueDetailsSheet({
    super.key,
    required this.period,
    this.approximateTotal,
  });

  final StatsPeriod period;

  /// Valeur affichée sur la tuile quand elle est convertie (ex. « ≈ 1 419 € »).
  /// Nul quand la tuile n'a rien converti : aucun rappel à faire.
  final String? approximateTotal;

  static Future<void> show(
    BuildContext context, {
    required StatsPeriod period,
    String? approximateTotal,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<void>(
      context,
      title: l.activityRevenueTitle,
      subtitle: period.detailLabel(l),
      wrapper: (child) => BlocProvider<RevenueDetailsCubit>(
        create: (_) => getIt<RevenueDetailsCubit>()..load(period),
        child: child,
      ),
      child: RevenueDetailsSheet(
        period: period,
        approximateTotal: approximateTotal,
      ),
    );
  }

  @override
  State<RevenueDetailsSheet> createState() => _RevenueDetailsSheetState();
}

class _RevenueDetailsSheetState extends State<RevenueDetailsSheet> {
  /// Codes devise des groupes pliés. Tout est ouvert à l'ouverture.
  final Set<String> _collapsed = {};

  void _toggle(String currency) {
    setState(() {
      if (!_collapsed.remove(currency)) {
        _collapsed.add(currency);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevenueDetailsCubit, RevenueDetailsState>(
      builder: (context, state) => switch (state.status) {
        RevenueDetailsStatus.initial ||
        RevenueDetailsStatus.loading => const _LoadingBody(),
        RevenueDetailsStatus.error => _ErrorBody(
          onRetry: () =>
              context.read<RevenueDetailsCubit>().load(widget.period),
        ),
        RevenueDetailsStatus.loaded => _LoadedBody(
          details: state.details!,
          collapsed: _collapsed,
          onToggle: _toggle,
          approximateTotal: widget.approximateTotal,
        ),
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        DonyListCardSkeleton(detailLines: 3),
        SizedBox(height: DonySpacing.base),
        DonyListCardSkeleton(),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        DonyEmptyState(
          type: DonyEmptyStateType.error,
          iconAsset: 'circle-alert',
          title: l.activityDetailUnavailable,
          description: l.activityRevenueErrorBody,
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
        ),
        // Un DonyChip et non un DonyButton : un bouton n'a sa place que dans
        // le pied collant d'une feuille, et cet état-là n'en a pas besoin.
        DonyChip(
          key: const Key('revenue-retry'),
          label: l.commonRetry,
          selected: false,
          onTap: onRetry,
        ),
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.details,
    required this.collapsed,
    required this.onToggle,
    required this.approximateTotal,
  });

  final RevenueDetailsModel details;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;
  final String? approximateTotal;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    if (details.groups.isEmpty) {
      return DonyEmptyState(
        iconAsset: 'wallet',
        title: l.activityEmptyPeriodTitle,
        description: l.activityRevenueEmptyBody,
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs,
            DonySpacing.sm,
            DonySpacing.xs,
            DonySpacing.md,
          ),
          child: Text(
            l.activityDeliveries(details.deliveries),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        for (final group in details.groups) ...[
          _CurrencyGroupCard(
            group: group,
            expanded: !collapsed.contains(group.currency),
            onToggle: () => onToggle(group.currency),
          ),
          const SizedBox(height: DonySpacing.base),
        ],
        if (approximateTotal != null) _ConversionNote(total: approximateTotal!),
      ],
    );
  }
}

String _kg(double v) {
  // Arrondir d'abord à une décimale, puis juger l'entier sur la valeur
  // arrondie : sinon 2.04 (arrondi ultérieur à 1 décimale donnerait 2.0)
  // passait le test `v % 1 == 0` sur la valeur brute et s'affichait « 2,0 kg ».
  final rounded = double.parse(v.toStringAsFixed(1));
  final text = rounded % 1 == 0
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kg';
}

/// Un groupe = une devise. L'en-tête porte le sous-total et plie les lignes.
class _CurrencyGroupCard extends StatelessWidget {
  const _CurrencyGroupCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  final RevenueGroupModel group;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    // `fromCode` (nullable) distingue une devise reconnue d'un code inconnu ;
    // `fromCodeOrDefault` reste réservé au seul formatage du montant, qui a
    // besoin d'un symbole et d'un nombre de décimales même par défaut. Sans
    // cette distinction, un code hors catalogue s'affichait « EUR »/« Euro »
    // pour un paiement qui n'en est pas un, et deux groupes (le vrai EUR et
    // la devise inconnue) portaient tous deux le nom « Euro ».
    final knownCurrency = SupportedCurrency.fromCode(group.currency);
    final currency = SupportedCurrency.fromCodeOrDefault(group.currency);
    final pillCode = knownCurrency?.code ?? group.currency;
    final displayName = knownCurrency?.name(l) ?? group.currency;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : DonyDuration.base;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            // `excludeSemantics` efface aussi l'action tap de l'InkWell :
            // sans celle-ci, VoiceOver/TalkBack ne peuvent ni plier ni déplier.
            onTap: onToggle,
            label:
                '$displayName, ${l.activityDeliveries(group.deliveries)}, '
                '${CurrencyFormatter.format(group.total, currency)}',
            // Le label ci-dessus dit déjà tout : sans ça, un lecteur d'écran
            // annonce le label puis relit pastille, nom, compteur et montant
            // une seconde fois via les Text enfants.
            excludeSemantics: true,
            child: Material(
              color: cs.surfaceContainerLow,
              child: InkWell(
                key: Key('revenue-group-${group.currency}'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  child: Row(
                    children: [
                      _CurrencyPill(code: pillCode),
                      const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: tt.titleSmall?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              l.activityDeliveries(group.deliveries),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        CurrencyFormatter.format(group.total, currency),
                        style: tt.headlineMedium?.copyWith(
                          color: cs.success,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: duration,
                        curve: DonyCurve.easeOut,
                        child: DonyIcon(
                          'chevron-down',
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // `AnimatedSize` reste imposé par la spec, mais le contenu doit
          // rester monté pour glisser : un enfant échangé (Column ↔ SizedBox
          // vide) apparaît/disparaît d'un coup pendant que la boîte anime sa
          // taille. `Align(heightFactor:)` fait varier la hauteur rendue du
          // même arbre, `ClipRect` coupe le débord pendant la transition.
          // `ExcludeSemantics`/`IgnorePointer` neutralisent le contenu replié
          // (annonce et tap) sans le démonter.
          AnimatedSize(
            duration: duration,
            curve: DonyCurve.easeOut,
            alignment: Alignment.topCenter,
            child: ClipRect(
              key: Key('revenue-group-${group.currency}-items'),
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: expanded ? 1 : 0,
                child: ExcludeSemantics(
                  excluding: !expanded,
                  child: IgnorePointer(
                    ignoring: !expanded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: cs.outline),
                        for (var i = 0; i < group.items.length; i++) ...[
                          _RevenueItemRow(
                            item: group.items[i],
                            currency: currency,
                          ),
                          if (i < group.items.length - 1)
                            Divider(
                              height: 1,
                              indent: DonySpacing.base,
                              color: cs.outline,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _RevenueItemRow extends StatelessWidget {
  const _RevenueItemRow({required this.item, required this.currency});

  final RevenueItemModel item;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final date = DateFormat.MMMd(l.localeName).format(item.date);
    final weight = item.weightKg;
    final meta = [
      date,
      if (weight != null) _kg(weight),
      item.rail.label(l),
    ].join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.sm + DonySpacing.xxs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.departureCity} → ${item.arrivalCity}',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    meta,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Text(
              CurrencyFormatter.format(item.amount, currency),
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappelle que la tuile porte un total converti, indicatif.
class _ConversionNote extends StatelessWidget {
  const _ConversionNote({required this.total});

  final String total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.md + DonySpacing.xxs,
        DonySpacing.md,
        DonySpacing.md + DonySpacing.xxs,
        DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: DonyIcon('info', size: 16, color: cs.primary),
          ),
          const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          Expanded(
            child: Text(
              context.l10n.activityRevenueConversionNote(total),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
