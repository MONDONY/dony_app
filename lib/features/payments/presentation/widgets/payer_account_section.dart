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
import 'package:flutter/services.dart';
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
///
/// Quand le cubit restreint les opérateurs, les pastilles non permises sont
/// grisées et non cliquables, avec un libellé dessous. Les textes propres à
/// l'appelant se règlent ici :
/// - [disallowedOperatorLabel] : libellé sous une pastille non permise
///   (défaut « Non accepté ») ;
/// - [notAllowedMessage] : message quand le numéro est d'un opérateur non
///   permis, reçoit le nom de cet opérateur ;
/// - [numberHelper] : aide affichée sous le champ numéro ;
/// - [sectionLabel] : titre du bloc (défaut « COMPTE QUI PAIE »), l'ajout
///   d'un compte de versement y met le compte qui reçoit.
///
/// En mode imposé (`PayerAccountState.fixed`, changement de numéro), le pays
/// n'a pas de bouton pour l'effacer et seule la pastille de l'opérateur
/// imposé est montrée : seul le numéro se modifie.
class PayerAccountSection extends StatelessWidget {
  const PayerAccountSection({
    super.key,
    this.disallowedOperatorLabel,
    this.notAllowedMessage,
    this.numberHelper,
    this.sectionLabel,
  });

  final String? disallowedOperatorLabel;
  final String Function(String operatorLabel)? notAllowedMessage;
  final String? numberHelper;
  final String? sectionLabel;

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
                sectionLabel ?? l.mobileMoneyPayerSectionLabel,
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
              _ => _AccountCard(
                state: state,
                disallowedOperatorLabel: disallowedOperatorLabel,
                numberHelper: numberHelper,
              ),
            },
            _Feedback(state: state, notAllowedMessage: notAllowedMessage),
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
  const _AccountCard({
    required this.state,
    required this.disallowedOperatorLabel,
    required this.numberHelper,
  });

  final PayerAccountState state;
  final String? disallowedOperatorLabel;
  final String? numberHelper;

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
            _CountryRow(
              code: country.country,
              onClear: state.fixed ? null : cubit.clearCountry,
            )
          else if (countries != null)
            Padding(
              padding: const EdgeInsets.all(DonySpacing.md),
              child: MobileMoneyCountryField(
                countries: countries,
                currency: state.currency,
                initialUpcoming: state.unavailableCountry,
                onSelected: cubit.selectCountry,
                onCleared: () {
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
                operators: state.fixed && operator != null
                    ? [operator]
                    : country.operators,
                selected: operator?.code,
                isAllowed: state.isAllowed,
                disallowedLabel:
                    disallowedOperatorLabel ??
                    context.l10n.mobileMoneyOperatorNotAccepted,
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
                helper: numberHelper,
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

  /// `null` : pays imposé, pas de bouton pour l'effacer.
  final VoidCallback? onClear;

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
          if (onClear != null)
            IconButton(
              tooltip: l.commonClear,
              onPressed: onClear,
              icon: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
            )
          else
            // Même hauteur de ligne que celle qui porte le bouton.
            const SizedBox(height: kMinInteractiveDimension),
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
    required this.isAllowed,
    required this.disallowedLabel,
    required this.onSelect,
  });

  final List<MobileMoneyOperator> operators;
  final String? selected;
  final bool Function(MobileMoneyOperator operator) isAllowed;
  final String disallowedLabel;
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
                  disallowedLabel: isAllowed(o) ? null : disallowedLabel,
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
///
/// Avec [disallowedLabel], l'opérateur n'est pas accepté pour ce paiement : la
/// pastille est grisée (opacité 0,4), le libellé passe sous le nom, et rien
/// ne se touche ni ne s'annonce comme actif.
class _OperatorPill extends StatelessWidget {
  const _OperatorPill({
    super.key,
    required this.operator,
    required this.selected,
    required this.onTap,
    this.disallowedLabel,
  });

  final MobileMoneyOperator operator;
  final bool selected;
  final VoidCallback onTap;
  final String? disallowedLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final disallowed = disallowedLabel;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final pill = Semantics(
      button: true,
      enabled: disallowed == null,
      selected: selected,
      label: disallowed == null
          ? operator.label
          : '${operator.label}, $disallowed',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disallowed == null ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            height: disallowed == null ? 36 : null,
            padding: EdgeInsets.only(
              left: DonySpacing.xs + 2,
              right: DonySpacing.md,
              top: disallowed == null ? 0 : DonySpacing.xxs,
              bottom: disallowed == null ? 0 : DonySpacing.xxs,
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
                if (disallowed == null)
                  Text(
                    operator.label,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operator.label,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        disallowed,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return disallowed == null ? pill : Opacity(opacity: 0.4, child: pill);
  }
}

// ─── Numéro ─────────────────────────────────────────────────────────────────

/// Champ numéro, préfixé de l'indicatif du pays.
///
/// Chiffres groupés par deux (« 07 48 84 08 56 »). La saisie part telle
/// qu'affichée au cubit, qui la normalise (jamais la valeur qu'il a
/// recomposée). Le champ reprend [localNumber], groupé, seulement quand ses
/// chiffres diffèrent de la saisie : numéro mémorisé, indicatif collé
/// retiré.
class _NumberRow extends StatefulWidget {
  const _NumberRow({
    required this.countryCode,
    required this.operatorLabel,
    required this.localNumber,
    required this.checking,
    required this.onChanged,
    this.helper,
  });

  final String countryCode;
  final String operatorLabel;
  final String localNumber;
  final bool checking;
  final ValueChanged<String> onChanged;

  /// Aide sous le champ, ou `null`.
  final String? helper;

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final TextEditingController _controller = TextEditingController(
    text: _groupPhonePairs(widget.localNumber),
  );

  static final _formatter = _PhonePairsFormatter();

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  @override
  void didUpdateWidget(covariant _NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wanted = _groupPhonePairs(widget.localNumber);
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
    final field = DonyTextField(
      key: const Key('mm-number-field'),
      controller: _controller,
      label: l.mobileMoneyOperatorNumberLabel(widget.operatorLabel),
      hint: phone?.hint,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      inputFormatters: [_formatter],
      prefixWidget: phone == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(
                left: DonySpacing.base,
                right: DonySpacing.sm,
              ),
              // `prefixIcon` est étiré à 48 px de haut : sans `Center`,
              // l'indicatif se dessinait en haut de la case, plus haut que
              // le texte saisi et le texte d'aide (PROD-1G).
              child: Center(
                widthFactor: 1,
                child: Text(
                  phone.dialCode,
                  key: const Key('mm-number-dial-code'),
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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
    );
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.md),
      child: widget.helper == null
          ? field
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field,
                Padding(
                  padding: const EdgeInsets.only(
                    top: DonySpacing.sm,
                    left: DonySpacing.xs,
                  ),
                  child: Text(
                    widget.helper!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Chiffres groupés par deux, séparés d'une espace (« 0748840856 » donne
/// « 07 48 84 08 56 »). Une valeur internationale (`+`, `00`) reste telle
/// quelle : le cubit en retire l'indicatif, puis le champ la regroupe.
String _groupPhonePairs(String value) {
  final trimmed = value.trimLeft();
  if (trimmed.startsWith('+') || trimmed.startsWith('00')) return value;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i.isEven) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Regroupe la saisie du numéro par deux chiffres en gardant le curseur
/// derrière le même chiffre. Effacer l'espace devant le curseur retire le
/// chiffre qui la précède, sinon l'espace reviendrait aussitôt.
class _PhonePairsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('+') || trimmed.startsWith('00')) return newValue;

    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    var digits = text.replaceAll(RegExp(r'\D'), '');
    var digitsBeforeCursor = text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;

    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final removedSeparatorOnly =
        text.length < oldValue.text.length && digits == oldDigits;
    if (removedSeparatorOnly && digitsBeforeCursor > 0) {
      digits =
          digits.substring(0, digitsBeforeCursor - 1) +
          digits.substring(digitsBeforeCursor);
      digitsBeforeCursor -= 1;
    }

    final formatted = _groupPhonePairs(digits);
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBeforeCursor) {
      if (formatted[offset] != ' ') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

// ─── Retour sous la carte ───────────────────────────────────────────────────

class _Feedback extends StatelessWidget {
  const _Feedback({required this.state, required this.notAllowedMessage});

  final PayerAccountState state;
  final String Function(String operatorLabel)? notAllowedMessage;

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
        RecognitionStatus.notAllowed =>
          state.rejectedOperator == null
              ? null
              : _Note(
                  key: const ValueKey('notAllowed'),
                  background: cs.warningLight,
                  foreground: cs.onSurface,
                  leading: DonyIcon(
                    'circle-alert',
                    size: 18,
                    color: cs.warning,
                  ),
                  text:
                      notAllowedMessage?.call(state.rejectedOperator!.label) ??
                      l.mobileMoneyNumberOperatorNotAccepted(
                        state.rejectedOperator!.label,
                      ),
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
        // Choix manuel après reconnaissance, refusé ici (compte de
        // versement : le back exige l'opérateur du numéro).
        RecognitionStatus.overridden when !state.overrideAccepted => _Note(
          key: const ValueKey('overriddenRefused'),
          background: cs.warningLight,
          foreground: cs.onSurface,
          leading: DonyIcon('circle-alert', size: 18, color: cs.warning),
          text: l.mobileMoneyNumberNotOperator(operator.label),
        ),
        // Choix manuel après reconnaissance : respecté sans commentaire.
        RecognitionStatus.overridden ||
        RecognitionStatus.idle ||
        RecognitionStatus.checking => null,
      };
    }

    final child = content == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            key: content.key,
            padding: const EdgeInsets.only(
              top: DonySpacing.sm,
              left: DonySpacing.xs,
              right: DonySpacing.xs,
            ),
            child: content,
          );
    // Mouvement réduit : l'enfant direct. Un `AnimatedSize` à durée nulle
    // lève, en debug, « RenderAnimatedSize was mutated in its own
    // performLayout » quand la taille change.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: child,
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
