import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Identité du voyageur pour la collecte ciblée (yadony-back #730) :
///
/// - les valeurs connues en lecture seule, groupées par origine (pièce
///   vérifiée ou profil), avec « Ce n'est plus mon adresse » sous l'adresse
///   reprise de la pièce, seule valeur remplaçable ;
/// - les champs à saisir, seulement ceux qui manquent : nom et prénom, date de
///   naissance, adresse (rue, complément, code postal, ville ; le pays est
///   celui de résidence).
///
/// Les contrôleurs de texte vivent dans ce `State` (disposés dans
/// `dispose()`), la saisie dans [TaxInfoCubit] ; jamais de `setState`. Les
/// valeurs sont masquées des enregistrements de session ([DonyReplayMask]).
class TaxInfoIdentitySection extends StatefulWidget {
  const TaxInfoIdentitySection({super.key});

  @override
  State<TaxInfoIdentitySection> createState() => _TaxInfoIdentitySectionState();
}

class _TaxInfoIdentitySectionState extends State<TaxInfoIdentitySection> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _street;
  late final TextEditingController _line2;
  late final TextEditingController _postal;
  late final TextEditingController _city;
  late final List<(TextEditingController, VoidCallback)> _bindings;

  @override
  void initState() {
    super.initState();
    final s = context.read<TaxInfoCubit>().state;
    _first = TextEditingController(text: s.firstName);
    _last = TextEditingController(text: s.lastName);
    _street = TextEditingController(text: s.street);
    _line2 = TextEditingController(text: s.line2);
    _postal = TextEditingController(text: s.postalCode);
    _city = TextEditingController(text: s.city);
    _bindings = [
      (_first, () => _push(_first, (c) => c.firstName, firstName: _first.text)),
      (_last, () => _push(_last, (c) => c.lastName, lastName: _last.text)),
      (_street, () => _push(_street, (c) => c.street, street: _street.text)),
      (_line2, () => _push(_line2, (c) => c.line2, line2: _line2.text)),
      (
        _postal,
        () => _push(_postal, (c) => c.postalCode, postalCode: _postal.text),
      ),
      (_city, () => _push(_city, (c) => c.city, city: _city.text)),
    ];
    for (final (controller, listener) in _bindings) {
      controller.addListener(listener);
    }
  }

  @override
  void dispose() {
    for (final (controller, listener) in _bindings) {
      controller
        ..removeListener(listener)
        ..dispose();
    }
    super.dispose();
  }

  /// Pousse la saisie au cubit si elle a changé (une sélection ou un
  /// déplacement du curseur réveille aussi l'écouteur).
  void _push(
    TextEditingController controller,
    String Function(TaxInfoState) current, {
    String? firstName,
    String? lastName,
    String? street,
    String? line2,
    String? postalCode,
    String? city,
  }) {
    final cubit = context.read<TaxInfoCubit>();
    if (current(cubit.state) == controller.text) return;
    cubit.updateForm(
      firstName: firstName,
      lastName: lastName,
      street: street,
      line2: line2,
      postalCode: postalCode,
      city: city,
    );
  }

  /// « Ce n'est plus mon adresse » annulé : les champs se vident avec l'état.
  void _keepAddress(TaxInfoCubit cubit) {
    cubit.keepAddress();
    for (final c in [_street, _line2, _postal, _city]) {
      c.clear();
    }
  }

  Future<void> _pickBirthDate(DateTime? current) async {
    final cubit = context.read<TaxInfoCubit>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(today.year - 30),
      firstDate: kTaxOldestBirthDate,
      lastDate: today,
      initialDatePickerMode: DatePickerMode.year,
      helpText: context.l10n.taxInfoBirthDateLabel,
    );
    if (picked != null && !cubit.isClosed) {
      cubit.updateForm(
        birthDate: DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaxInfoCubit, TaxInfoState>(
      buildWhen: (p, c) =>
          p.info != c.info ||
          p.asksName != c.asksName ||
          p.asksBirthDate != c.asksBirthDate ||
          p.asksAddress != c.asksAddress ||
          p.replacingAddress != c.replacingAddress ||
          p.birthDate != c.birthDate ||
          p.submitting != c.submitting ||
          p.errorCode != c.errorCode ||
          p.errorField != c.errorField,
      builder: (context, s) {
        final known = _known(context, s);
        final children = <Widget>[
          for (final group in known) ...[
            group,
            const SizedBox(height: DonySpacing.lg),
          ],
          if (s.asksName) ...[
            _nameFields(context, s),
            const SizedBox(height: DonySpacing.lg),
          ],
          if (s.asksBirthDate) ...[
            _birthDateField(context, s),
            const SizedBox(height: DonySpacing.lg),
          ],
          if (s.asksAddress) ...[
            _addressFields(context, s),
            const SizedBox(height: DonySpacing.lg),
          ],
        ];
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  /// Cartes des valeurs connues : d'abord celles de la pièce vérifiée, puis
  /// celles du profil.
  List<Widget> _known(BuildContext context, TaxInfoState s) {
    final l = context.l10n;
    final info = s.info;
    final identity = info?.identity;
    if (info == null) return const [];
    final fromId = <_KnownRow>[];
    final fromProfile = <_KnownRow>[];
    void add(TaxInfoSource? source, _KnownRow row) =>
        (source == TaxInfoSource.didit ? fromId : fromProfile).add(row);

    final name = identity?.fullName;
    if (!s.asksName && name != null) {
      add(identity!.nameSource, _KnownRow(l.taxInfoNameLabel, name));
    }
    final birth = identity?.birthDate;
    if (!s.asksBirthDate && birth != null) {
      add(
        identity!.birthDateSource,
        _KnownRow(
          l.taxInfoBirthDateLabel,
          DateFormat.yMMMMd(l.localeName).format(birth),
        ),
      );
    }
    final address = identity?.address;
    if (!s.asksAddress && address != null) {
      add(
        identity!.addressSource,
        _KnownRow(
          l.taxInfoAddressLabel,
          _addressText(l, address),
          action: identity.addressReplaceable
              ? _LinkAction(
                  key: const Key('tax_info_not_my_address'),
                  label: l.taxInfoNotMyAddress,
                  onTap: context.read<TaxInfoCubit>().replaceAddress,
                )
              : null,
        ),
      );
    }
    // Numéro déjà fourni, autre chose manque : rappel en forme masquée.
    final masked = info.maskedTaxIdentificationNumber;
    if (info.provided &&
        !info.isMissing(TaxInfoField.taxIdentificationNumber) &&
        masked != null) {
      fromProfile.add(_KnownRow(l.taxInfoNumberLabel, masked));
    }
    return [
      if (fromId.isNotEmpty)
        _KnownCard(
          key: const Key('tax_info_known_id'),
          title: l.taxInfoKnownTitle,
          locked: true,
          rows: fromId,
        ),
      if (fromProfile.isNotEmpty)
        _KnownCard(
          key: const Key('tax_info_known_profile'),
          title: l.taxInfoKnownProfileTitle,
          locked: false,
          rows: fromProfile,
        ),
    ];
  }

  String _addressText(AppLocalizations l, TaxInfoAddress a) {
    final country = a.country;
    return [
      a.street,
      if (a.line2 != null) a.line2!,
      '${a.postalCode} ${a.city}'.trim(),
      if (country != null) countryName(l, country),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String? _fieldError(AppLocalizations l, TaxInfoState s, String field) =>
      s.serverRejected(field) ? l.taxInfoFieldInvalid : null;

  Widget _text({
    required Key key,
    required TextEditingController controller,
    required String label,
    required TaxInfoState s,
    required int maxLength,
    required String? errorText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.words,
    TextInputAction action = TextInputAction.next,
  }) => DonyReplayMask(
    child: DonyTextField(
      key: key,
      controller: controller,
      label: label,
      enabled: !s.submitting,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: action,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      autocorrect: false,
      errorText: errorText,
      errorMaxLines: 3,
    ),
  );

  Widget _nameFields(BuildContext context, TaxInfoState s) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          key: const Key('tax_info_first_name'),
          controller: _first,
          label: l.taxInfoFirstNameLabel,
          s: s,
          maxLength: kTaxNameMaxLength,
          errorText: _fieldError(l, s, kTaxFieldFirstName),
        ),
        const SizedBox(height: DonySpacing.md),
        _text(
          key: const Key('tax_info_last_name'),
          controller: _last,
          label: l.taxInfoLastNameLabel,
          s: s,
          maxLength: kTaxNameMaxLength,
          errorText: _fieldError(l, s, kTaxFieldLastName),
        ),
      ],
    );
  }

  Widget _birthDateField(BuildContext context, TaxInfoState s) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final day = s.birthDate;
    return DonyReplayMask(
      child: DonyTextField.tappable(
        key: const Key('tax_info_birth_date'),
        label: l.taxInfoBirthDateLabel,
        value: day == null ? null : DateFormat.yMMMMd(l.localeName).format(day),
        errorText: _fieldError(l, s, kTaxFieldBirthDate),
        trailing: DonyIcon('calendar', color: cs.onSurfaceVariant),
        onTap: s.submitting ? null : () => _pickBirthDate(day),
      ),
    );
  }

  Widget _addressFields(BuildContext context, TaxInfoState s) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final country = s.info?.residenceCountry;
    final cubit = context.read<TaxInfoCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.taxInfoAddressLabel,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        _text(
          key: const Key('tax_info_street'),
          controller: _street,
          label: l.taxInfoStreetLabel,
          s: s,
          maxLength: kTaxStreetMaxLength,
          errorText: _fieldError(l, s, kTaxFieldStreet),
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: DonySpacing.md),
        _text(
          key: const Key('tax_info_line2'),
          controller: _line2,
          label: l.taxInfoLine2Label,
          s: s,
          maxLength: kTaxLine2MaxLength,
          errorText: _fieldError(l, s, kTaxFieldLine2),
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: DonySpacing.md),
        _text(
          key: const Key('tax_info_postal_code'),
          controller: _postal,
          label: l.taxInfoPostalCodeLabel,
          s: s,
          maxLength: kTaxPostalCodeMaxLength,
          errorText: _fieldError(l, s, kTaxFieldPostalCode),
          capitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: DonySpacing.md),
        _text(
          key: const Key('tax_info_city'),
          controller: _city,
          label: l.taxInfoCityLabel,
          s: s,
          maxLength: kTaxCityMaxLength,
          errorText: _fieldError(l, s, kTaxFieldCity),
          action: TextInputAction.done,
        ),
        if (country != null)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.xs),
            child: Text(
              l.taxInfoAddressCountry(countryName(l, country)),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        if (s.replacingAddress)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _LinkAction(
              key: const Key('tax_info_keep_address'),
              label: l.taxInfoKeepAddress,
              onTap: s.submitting ? null : () => _keepAddress(cubit),
            ),
          ),
      ],
    );
  }
}

class _KnownRow {
  const _KnownRow(this.label, this.value, {this.action});

  final String label;
  final String value;
  final Widget? action;
}

/// Carte des valeurs connues, non modifiables ici. [locked] : valeurs de la
/// pièce vérifiée (cadenas devant le titre).
class _KnownCard extends StatelessWidget {
  const _KnownCard({
    super.key,
    required this.title,
    required this.locked,
    required this.rows,
  });

  final String title;
  final bool locked;
  final List<_KnownRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (locked) ...[
              DonyIcon('lock', size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
            ],
            Expanded(
              child: Text(
                title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyCard(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: DonySpacing.lg, color: cs.outline),
                Text(
                  rows[i].label,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.xxs),
                DonyReplayMask(
                  child: Text(
                    rows[i].value,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (rows[i].action != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: rows[i].action,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Lien texte sur une ligne (jamais coupé ni rétréci).
class _LinkAction extends StatelessWidget {
  const _LinkAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size(0, kDonyMinTapTarget),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
