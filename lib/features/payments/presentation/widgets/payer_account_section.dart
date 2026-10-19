import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_country_field.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bloc « compte qui paie » : pays, puis opérateur, puis numéro, regroupés
/// dans une carte à lignes séparées (maquettes v3, écrans 1 à 4).
///
/// Lit le [PayerAccountCubit] du contexte. Chaque ligne n'apparaît qu'une
/// fois la précédente remplie ; le retour de la reconnaissance du numéro
/// (reconnu, opérateur changé, non reconnu, vérification impossible) s'affiche
/// sous la carte. En état `legacy` (back sans catalogue des pays), rien n'est
/// rendu : l'appelant garde son ancien champ.
class PayerAccountSection extends StatelessWidget {
  const PayerAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayerAccountCubit, PayerAccountState>(
      builder: (context, state) {
        if (state.status == PayerAccountStatus.legacy) {
          return const SizedBox.shrink();
        }
        final l = context.l10n;
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: DonySpacing.xs,
                bottom: DonySpacing.sm,
              ),
              child: Text(
                l.mobileMoneyPayerSectionLabel,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            switch (state.status) {
              PayerAccountStatus.loading => const KeyedSubtree(
                key: Key('payer-account-loading'),
                child: MobileMoneyNetworksSkeleton(),
              ),
              PayerAccountStatus.error => DonyStatusBanner(
                type: DonyStatusBannerType.error,
                message: l.errorGenericTitle,
                action: TextButton(
                  onPressed: () => context.read<PayerAccountCubit>().load(),
                  child: Text(l.commonRetry),
                ),
              ),
              _ => _AccountCard(state: state),
            },
            _Feedback(state: state),
          ],
        );
      },
    );
  }
}

/// Apparition d'une ligne : fondu et léger glissé, 250 ms, coupés quand la
/// réduction du mouvement est active. La clé rejoue l'entrée quand la ligne
/// change de contenu (autre pays, autre opérateur).
Widget _reveal(BuildContext context, Widget child, {Key? key}) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return KeyedSubtree(key: key, child: child);
  }
  return child
      .animate(key: key)
      .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
      .slideY(
        begin: 0.04,
        end: 0,
        duration: 250.ms,
        curve: Curves.easeOutCubic,
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.state});

  final PayerAccountState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PayerAccountCubit>();
    final country = state.country;
    final operator = state.operator;
    final countries = state.countries;
    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (country != null)
            _CountryRow(code: country.country, onClear: cubit.clearCountry)
          else if (countries != null)
            Padding(
              padding: const EdgeInsets.all(DonySpacing.md),
              child: MobileMoneyCountryField(
                countries: countries,
                initialUpcoming: state.unavailableCountry,
                onSelected: cubit.selectCountry,
                onUpcomingMatch: (code) {
                  if (cubit.state.unavailableCountry != code) {
                    cubit.selectCountry(code);
                  }
                },
                onUpcomingLost: () {
                  if (cubit.state.unavailableCountry != null) {
                    cubit.clearCountry();
                  }
                },
              ),
            ),
          if (country != null) ...[
            const Divider(height: 1),
            _reveal(
              context,
              _OperatorRow(
                operators: country.operators,
                selected: operator?.code,
                onSelect: cubit.selectOperator,
              ),
              key: ValueKey('mm-operator-row-${country.country}'),
            ),
          ],
          if (country != null && operator != null) ...[
            const Divider(height: 1),
            _reveal(
              context,
              _NumberRow(
                countryCode: country.country,
                operatorLabel: operator.label,
                localNumber: state.localNumber,
                checking: state.recognition == RecognitionStatus.checking,
                onChanged: cubit.phoneChanged,
              ),
              key: ValueKey('mm-number-row-${country.country}'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Pays choisi ────────────────────────────────────────────────────────────

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.code, required this.onClear});

  final String code;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: DonySpacing.base,
        right: DonySpacing.xs,
        top: DonySpacing.xs,
        bottom: DonySpacing.xs,
      ),
      child: Row(
        children: [
          MobileMoneyCountryFlag(code: code),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.mobileMoneyCountryLabel,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  countryName(l, code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.commonClear,
            onPressed: onClear,
            icon: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Opérateur ──────────────────────────────────────────────────────────────

class _OperatorRow extends StatelessWidget {
  const _OperatorRow({
    required this.operators,
    required this.selected,
    required this.onSelect,
  });

  final List<MobileMoneyOperator> operators;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.mobileMoneyOperatorLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.sm,
            children: [
              for (final o in operators)
                _OperatorPill(
                  key: Key('mm-operator-${o.code}'),
                  operator: o,
                  selected: o.code == selected,
                  onTap: () => onSelect(o.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastille d'opérateur : marque + nom. La zone tactile fait 44 px de haut,
/// la pastille visible 36.
class _OperatorPill extends StatelessWidget {
  const _OperatorPill({
    super.key,
    required this.operator,
    required this.selected,
    required this.onTap,
  });

  final MobileMoneyOperator operator;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Semantics(
      button: true,
      selected: selected,
      label: operator.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            height: 36,
            padding: const EdgeInsets.only(
              left: DonySpacing.xs + 2,
              right: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.10),
                      cs.surface,
                    )
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(
                color: selected ? cs.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyBrandMark(brand: operator.brand, size: 24),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  operator.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Numéro ─────────────────────────────────────────────────────────────────

/// Champ numéro, préfixé de l'indicatif du pays.
///
/// La saisie brute part telle quelle au cubit (jamais la valeur qu'il a
/// recomposée). Le champ reprend [localNumber] seulement quand ses chiffres
/// diffèrent de la saisie : numéro mémorisé, indicatif collé retiré.
class _NumberRow extends StatefulWidget {
  const _NumberRow({
    required this.countryCode,
    required this.operatorLabel,
    required this.localNumber,
    required this.checking,
    required this.onChanged,
  });

  final String countryCode;
  final String operatorLabel;
  final String localNumber;
  final bool checking;
  final ValueChanged<String> onChanged;

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.localNumber,
  );

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  @override
  void didUpdateWidget(covariant _NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wanted = widget.localNumber;
    if (_digits(_controller.text) != _digits(wanted)) {
      _controller.value = TextEditingValue(
        text: wanted,
        selection: TextSelection.collapsed(offset: wanted.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final phone = phoneCountryForCode(widget.countryCode);
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.md),
      child: DonyTextField(
        key: const Key('mm-number-field'),
        controller: _controller,
        label: l.mobileMoneyOperatorNumberLabel(widget.operatorLabel),
        hint: phone?.hint,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        onChanged: widget.onChanged,
        prefixWidget: phone == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(
                  left: DonySpacing.base,
                  right: DonySpacing.sm,
                ),
                child: Text(
                  phone.dialCode,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
        suffixIcon: widget.checking
            ? Padding(
                padding: const EdgeInsets.all(DonySpacing.md),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ─── Retour sous la carte ───────────────────────────────────────────────────

class _Feedback extends StatelessWidget {
  const _Feedback({required this.state});

  final PayerAccountState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final operator = state.operator;

    final Widget? content;
    if (state.unavailableCountry != null && state.country == null) {
      content = _Note(
        key: const ValueKey('upcoming'),
        background: cs.infoLight,
        foreground: cs.onSurface,
        leading: DonyIcon('info', size: 18, color: cs.info),
        text: l.mobileMoneyCountryUnavailableNotice,
      );
    } else if (operator == null) {
      content = null;
    } else {
      content = switch (state.recognition) {
        RecognitionStatus.recognized => Row(
          key: const ValueKey('recognized'),
          children: [
            DonyIcon('circle-check', size: 16, color: cs.success),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                l.mobileMoneyNumberRecognized(operator.label),
                style: tt.bodySmall?.copyWith(
                  color: cs.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        RecognitionStatus.autoSwitched => _Note(
          key: const ValueKey('switched'),
          background: cs.infoLight,
          foreground: cs.onSurface,
          leading: DonyBrandMark(brand: operator.brand, size: 20),
          text: l.mobileMoneyOperatorSwitched(operator.label),
        ),
        RecognitionStatus.unrecognized => _Note(
          key: const ValueKey('unrecognized'),
          background: cs.warningLight,
          foreground: cs.onSurface,
          leading: DonyIcon('circle-alert', size: 18, color: cs.warning),
          text: l.mobileMoneyNumberUnrecognized,
        ),
        RecognitionStatus.failed => _Note(
          key: const ValueKey('failed'),
          background: cs.warningLight,
          foreground: cs.onSurface,
          leading: DonyIcon('wifi-off', size: 18, color: cs.warning),
          text: l.mobileMoneyRecognitionFailed,
          action: TextButton(
            onPressed: () =>
                context.read<PayerAccountCubit>().retryRecognition(),
            child: Text(l.commonRetry),
          ),
        ),
        // Choix manuel après reconnaissance : respecté sans commentaire.
        RecognitionStatus.overridden ||
        RecognitionStatus.idle ||
        RecognitionStatus.checking => null,
      };
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: content == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: content.key,
                padding: const EdgeInsets.only(
                  top: DonySpacing.sm,
                  left: DonySpacing.xs,
                  right: DonySpacing.xs,
                ),
                child: content,
              ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    super.key,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.text,
    this.action,
  });

  final Color background;
  final Color foreground;
  final Widget leading;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm + 2,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                text,
                style: tt.bodySmall?.copyWith(color: foreground),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
