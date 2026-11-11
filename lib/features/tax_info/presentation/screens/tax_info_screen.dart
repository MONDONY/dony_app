import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_form.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que l'écran montre, déduit du chargement et de la réponse du back.
enum _View { loading, failure, unavailable, summary, form }

/// Écran `/profile/tax-info` : numéro fiscal du voyageur, collecté pour la
/// déclaration DAC7 que la plateforme doit à l'administration fiscale.
///
/// Jamais bloquant : « Plus tard » ferme l'écran sans rien enregistrer. Lit
/// [TaxInfoCubit] (fourni par la route).
class TaxInfoScreen extends StatelessWidget {
  const TaxInfoScreen({super.key});

  _View _view(TaxInfoState s) => switch (s.load) {
    TaxInfoLoadStatus.loading => _View.loading,
    TaxInfoLoadStatus.failure => _View.failure,
    TaxInfoLoadStatus.unavailable => _View.unavailable,
    TaxInfoLoadStatus.ready => s.showsSummary ? _View.summary : _View.form,
  };

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocConsumer<TaxInfoCubit, TaxInfoState>(
      listenWhen: (p, c) =>
          (c.saved && !p.saved) ||
          (c.errorCode != null &&
              c.errorCode != p.errorCode &&
              // Le numéro refusé s'affiche sous le champ, pas en doublon.
              c.errorCode != kTaxInfoInvalidCode),
      listener: (context, s) {
        if (s.saved) {
          DonySnackbar.show(
            context,
            message: l.taxInfoSaved,
            type: DonySnackbarType.success,
          );
          _close(context);
          return;
        }
        DonySnackbar.show(
          context,
          message: l.taxInfoError(s.errorCode!),
          type: DonySnackbarType.error,
        );
      },
      builder: (context, s) {
        final view = _view(s);
        final fills = switch (view) {
          _View.loading || _View.failure || _View.unavailable => true,
          _ => false,
        };
        return DonyPageScaffold(
          title: l.taxInfoScreenTitle,
          scrollable: !fills,
          padding: fills
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(
                  DonyLayout.hPadding(context),
                  DonySpacing.base,
                  DonyLayout.hPadding(context),
                  DonySpacing.xl,
                ),
          stickyBottom: _bottom(context, view, s),
          body: _body(context, view, s),
        );
      },
    );
  }

  /// Boutons empilés en pleine largeur, l'action principale en haut : les deux
  /// libellés tiennent chacun sur une ligne à 360 dp, FR comme EN.
  Widget? _bottom(BuildContext context, _View view, TaxInfoState s) {
    final l = context.l10n;
    final cubit = context.read<TaxInfoCubit>();
    switch (view) {
      case _View.form:
        final editing = s.editing;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('tax_info_save'),
              label: l.taxInfoSave,
              flat: true,
              isLoading: s.submitting,
              onPressed: s.canSubmit ? () => unawaited(cubit.submit()) : null,
            ),
            const SizedBox(height: DonySpacing.xs),
            DonyButton(
              key: const Key('tax_info_later'),
              label: editing ? l.taxInfoCancelEdit : l.taxInfoLater,
              variant: DonyButtonVariant.ghost,
              onPressed: s.submitting
                  ? null
                  : () {
                      if (editing) {
                        cubit.cancelEditing();
                      } else {
                        cubit.later();
                        _close(context);
                      }
                    },
            ),
          ],
        );
      case _View.summary:
        return DonyButton(
          key: const Key('tax_info_edit'),
          label: l.taxInfoEdit,
          flat: true,
          onPressed: cubit.startEditing,
        );
      case _View.loading || _View.failure || _View.unavailable:
        return null;
    }
  }

  Widget _body(BuildContext context, _View view, TaxInfoState s) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<TaxInfoCubit>();
    switch (view) {
      case _View.loading:
        return Center(child: CircularProgressIndicator(color: cs.primary));
      case _View.failure:
        return DonyEmptyState(
          type: DonyEmptyStateType.error,
          iconAsset: 'wifi-off',
          title: l.taxInfoFailureTitle,
          description: l.taxInfoFailureBody,
          actionLabel: l.commonRetry,
          onAction: () => unawaited(cubit.load()),
        );
      case _View.unavailable:
        return DonyEmptyState(
          iconAsset: 'landmark',
          title: l.taxInfoUnavailableTitle,
          description: l.taxInfoUnavailableBody,
          actionLabel: l.taxInfoClose,
          onAction: () => _close(context),
        );
      case _View.summary:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ReasonBlock(),
            const SizedBox(height: DonySpacing.lg),
            _Summary(info: s.info!),
          ],
        );
      case _View.form:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReasonBlock(),
            SizedBox(height: DonySpacing.lg),
            TaxInfoForm(),
          ],
        );
    }
  }
}

/// Le motif en une phrase, la rassurance « rien n'est bloqué » et le lien
/// « En savoir plus » vers l'administration fiscale (navigateur externe).
class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.infoLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: DonyIcon('landmark', size: 20, color: cs.info),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.taxInfoReason, style: tt.bodyMedium),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.taxInfoNeverBlocking,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.xs),
                TextButton(
                  key: const Key('tax_info_learn_more'),
                  onPressed: () => unawaited(
                    ExternalUrlLauncher().open(kTaxInfoLearnMoreUrl),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    minimumSize: const Size(0, kDonyMinTapTarget),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l.taxInfoLearnMore,
                    maxLines: 1,
                    softWrap: false,
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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

/// Fiche des informations déjà fournies : formes masquées seulement, jamais le
/// numéro en entier.
class _Summary extends StatelessWidget {
  const _Summary({required this.info});

  final TaxInfo info;

  static const _masked = '****';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final country = info.taxCountry;
    final rows = [
      (l.taxInfoNumberLabel, info.maskedTaxIdentificationNumber ?? _masked),
      if (country != null) (l.taxInfoCountryLabel, countryName(l, country)),
      (
        l.taxInfoSummaryVatLabel,
        info.maskedVatNumber ??
            (info.vatNumberProvided ? _masked : l.taxInfoVatNone),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.taxInfoSummaryTitle,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.taxInfoSummaryBody,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        DonyCard(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: DonySpacing.lg, color: cs.outline),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        rows[i].$1,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.base),
                    Expanded(
                      flex: 4,
                      child: Text(
                        rows[i].$2,
                        textAlign: TextAlign.end,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
