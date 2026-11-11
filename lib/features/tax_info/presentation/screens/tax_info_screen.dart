import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_form.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_identity_section.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_residence_picker.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que l'écran montre, déduit du chargement et de la réponse du back.
enum _View { loading, failure, unavailable, residence, summary, form }

/// Écran `/profile/tax-info` : informations fiscales du voyageur, collectées
/// pour la déclaration DAC7 que la plateforme doit à l'administration fiscale.
///
/// Collecte ciblée (yadony-back #730, statut `collectionStatus`) :
/// - `RESIDENCE_INCONNUE` : seul le pays de résidence est demandé ;
/// - `INFO_REQUIRED` : seulement les champs manquants, les valeurs reprises
///   de la pièce d'identité en lecture seule ;
/// - `COMPLETE` : « Tout est à jour », rien à demander ;
/// - `NE_PAS_SOLLICITER` : l'écran n'est jamais proposé, il se ferme seul.
/// Sans ce statut (ancien back, DAC7 éteint) : ancien comportement (numéro
/// fiscal, pays d'émission, TVA).
///
/// Jamais bloquant : « Plus tard » ferme l'écran sans rien enregistrer. Lit
/// [TaxInfoCubit] (fourni par la route).
class TaxInfoScreen extends StatelessWidget {
  const TaxInfoScreen({super.key});

  _View _view(TaxInfoState s) => switch (s.load) {
    TaxInfoLoadStatus.loading => _View.loading,
    TaxInfoLoadStatus.failure => _View.failure,
    TaxInfoLoadStatus.unavailable => _View.unavailable,
    TaxInfoLoadStatus.ready when s.asksResidence => _View.residence,
    TaxInfoLoadStatus.ready
        when s.collection == TaxInfoCollectionStatus.nePasSolliciter =>
      _View.unavailable,
    TaxInfoLoadStatus.ready => s.showsSummary ? _View.summary : _View.form,
  };

  /// Pays hors périmètre lu à l'ouverture : l'écran se ferme seul (la route
  /// « redirige »), avec un mot d'explication. Voir [_NotConcernedCloser].
  static bool _notConcerned(TaxInfoState s) =>
      s.load == TaxInfoLoadStatus.unavailable &&
      s.collection == TaxInfoCollectionStatus.nePasSolliciter &&
      s.errorCode == null;

  static void _close(BuildContext context) {
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
          c.residenceSaves != p.residenceSaves ||
          (c.errorCode != null &&
              (c.errorCode != p.errorCode || c.errorField != p.errorField) &&
              // Un champ refusé s'affiche sous le champ, pas en doublon.
              !c.hasInlineError),
      listener: (context, s) {
        if (s.residenceSaves > 0 && !s.saved && s.errorCode == null) {
          if (s.collection == TaxInfoCollectionStatus.infoRequired) {
            DonySnackbar.show(
              context,
              message: l.taxInfoResidenceSavedMore,
              type: DonySnackbarType.success,
            );
            return;
          }
          if (s.load == TaxInfoLoadStatus.ready) {
            DonySnackbar.show(
              context,
              message: l.taxInfoResidenceSaved,
              type: DonySnackbarType.success,
            );
            _close(context);
            return;
          }
        }
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
      case _View.form when s.isTargeted && !s.editing && !s.hasEnterableInput:
        // Il ne manque que ce que l'équipe complète : rien à saisir.
        return DonyButton(
          key: const Key('tax_info_close'),
          label: l.taxInfoClose,
          flat: true,
          onPressed: () => _close(context),
        );
      case _View.form || _View.residence:
        final editing = s.editing;
        // Bouton grisé : on dit pourquoi, au lieu d'un bouton muet.
        final input = s.submitting ? null : s.firstMissingInput;
        final missing = input == null ? null : l.taxInfoMissingInput(input);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (missing != null) ...[
              Text(
                missing,
                key: const Key('tax_info_save_missing'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
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
      case _View.unavailable when _notConcerned(s):
        return const _NotConcernedCloser();
      case _View.unavailable:
        return DonyEmptyState(
          iconAsset: 'landmark',
          title: l.taxInfoUnavailableTitle,
          description: l.taxInfoUnavailableBody,
          actionLabel: l.taxInfoClose,
          onAction: () => _close(context),
        );
      case _View.residence:
        return const _ResidenceView();
      case _View.summary:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.isTargeted) const _CompleteBlock() else const _ReasonBlock(),
            const SizedBox(height: DonySpacing.lg),
            _Summary(info: s.info!),
          ],
        );
      case _View.form:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.isTargeted && !s.editing)
              _CollectHeader(state: s)
            else
              const _ReasonBlock(),
            const SizedBox(height: DonySpacing.lg),
            if (s.isTargeted) const TaxInfoIdentitySection(),
            if (s.asksTaxNumber) const TaxInfoForm(),
          ],
        );
    }
  }
}

/// Pays hors périmètre : rien à demander, l'écran n'est jamais proposé. S'il
/// est ouvert quand même (ancienne notification, lien), il se ferme dès la
/// première image, avec un mot. Un widget plutôt que le seul `listener` : la
/// lecture peut aboutir avant que l'écran l'écoute.
class _NotConcernedCloser extends StatefulWidget {
  const _NotConcernedCloser();

  @override
  State<_NotConcernedCloser> createState() => _NotConcernedCloserState();
}

class _NotConcernedCloserState extends State<_NotConcernedCloser> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DonySnackbar.show(context, message: context.l10n.taxInfoNotConcerned);
      TaxInfoScreen._close(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('tax_info_not_concerned'));
}

/// Encadré d'information de l'écran : icône à gauche, contenu à droite.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    super.key,
    required this.children,
    this.icon = 'landmark',
    this.success = false,
  });

  final List<Widget> children;
  final String icon;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = success ? cs.success : cs.info;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: success ? cs.successLight : cs.infoLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
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
            child: DonyIcon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// « En savoir plus » : lien texte sur une ligne. Emplacement de la FAQ DAC7
/// (tâche 6) ; d'ici là, la page de l'administration fiscale.
class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      key: const Key('tax_info_learn_more'),
      onPressed: () =>
          unawaited(ExternalUrlLauncher().open(kTaxInfoLearnMoreUrl)),
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size(0, kDonyMinTapTarget),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        context.l10n.taxInfoLearnMore,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// En-tête de la collecte ciblée (brouillon avocat) : l'obligation, la
/// rassurance « pas forcément d'impôt », ce qui est déjà repris de la pièce
/// et seulement ce qui manque, puis où trouver le numéro fiscal.
class _CollectHeader extends StatelessWidget {
  const _CollectHeader({required this.state});

  final TaxInfoState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = state.info!;
    final missing = l.taxInfoMissingList(info.missingFields);
    const gap = SizedBox(height: DonySpacing.sm);
    return _InfoPanel(
      children: [
        Text.rich(
          key: const Key('tax_info_collect_intro'),
          TextSpan(
            children: [
              TextSpan(text: '${l.taxInfoCollectIntro} '),
              TextSpan(
                text: l.taxInfoCollectNoTax,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          style: tt.bodyMedium,
        ),
        if (info.needsTeamFollowUp) ...[
          gap,
          Text(
            l.taxInfoTeamWillContact,
            key: const Key('tax_info_team_follow_up'),
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        if (state.hasPrefilledFromId || missing != null) ...[
          gap,
          Text(
            [
              if (state.hasPrefilledFromId) l.taxInfoCollectPrefilled,
              if (missing != null) l.taxInfoCollectMissing(missing),
            ].join(' '),
            key: const Key('tax_info_collect_missing'),
            style: tt.bodyMedium,
          ),
        ],
        if (info.isMissing(TaxInfoField.taxIdentificationNumber)) ...[
          gap,
          Text(
            l.taxInfoWhereToFind,
            key: const Key('tax_info_where_to_find'),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        gap,
        Text(
          l.taxInfoNeverBlocking,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xs),
        const _LearnMoreLink(),
      ],
    );
  }
}

/// `COMPLETE` : rien à demander.
class _CompleteBlock extends StatelessWidget {
  const _CompleteBlock();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    return _InfoPanel(
      key: const Key('tax_info_complete'),
      icon: 'circle-check',
      success: true,
      children: [
        Text(
          l.taxInfoCompleteTitle,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(l.taxInfoCompleteBody, style: tt.bodyMedium),
      ],
    );
  }
}

/// `RESIDENCE_INCONNUE` : seul le pays de résidence est demandé, parmi les
/// pays proposés par le back (`residenceCountryChoices`). Il part dans le
/// `PUT` fiscal : le pays du profil et les paiements n'en dépendent pas.
class _ResidenceView extends StatelessWidget {
  const _ResidenceView();

  Future<void> _pick(BuildContext context, String? current) async {
    final cubit = context.read<TaxInfoCubit>();
    final code = await showTaxResidencePicker(
      context,
      title: context.l10n.taxInfoResidenceLabel,
      choices: taxResidenceChoices(
        cubit.state.info?.residenceCountryChoices ?? const [],
      ),
      selectedCode: current,
    );
    if (code != null && !cubit.isClosed) {
      cubit.updateForm(residenceCountry: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPanel(
          icon: 'map-pin',
          children: [
            Text(
              l.taxInfoResidenceTitle,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(l.taxInfoResidenceBody, style: tt.bodyMedium),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.taxInfoNeverBlocking,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.lg),
        BlocBuilder<TaxInfoCubit, TaxInfoState>(
          buildWhen: (p, c) =>
              p.residenceCountry != c.residenceCountry ||
              p.submitting != c.submitting ||
              p.serverRejected(kTaxFieldResidence) !=
                  c.serverRejected(kTaxFieldResidence),
          builder: (context, s) {
            final code = s.residenceCountry;
            return DonyTextField.tappable(
              key: const Key('tax_info_residence'),
              label: l.taxInfoResidenceLabel,
              value: code == null ? null : countryName(l, code),
              errorText: s.serverRejected(kTaxFieldResidence)
                  ? l.taxInfoFieldInvalid
                  : null,
              trailing: DonyIcon('chevron-right', color: cs.onSurfaceVariant),
              onTap: s.submitting ? null : () => _pick(context, code),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: DonySpacing.xs),
          child: Text(
            l.taxInfoResidenceHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Le motif en une phrase, la rassurance « rien n'est bloqué » et le lien
/// « En savoir plus » (ancien contrat, et modification du numéro).
class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _InfoPanel(
      children: [
        Text(l.taxInfoReason, style: tt.bodyMedium),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.taxInfoNeverBlocking,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xs),
        const _LearnMoreLink(),
      ],
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
