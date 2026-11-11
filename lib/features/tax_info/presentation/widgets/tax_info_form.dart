import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_residence_picker.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire des informations fiscales : numéro fiscal, pays d'émission du
/// numéro, numéro de TVA facultatif.
///
/// Collecte ciblée (yadony-back #730) : numéro français contrôlé dès la
/// saisie (13 chiffres exacts), et case « Je n'ai pas de numéro fiscal » qui
/// remplace le numéro par le lieu de naissance.
///
/// La saisie vit dans [TaxInfoCubit] (le bouton « Enregistrer » de la barre
/// fixe en dépend) ; les contrôleurs de texte restent dans ce `State`, disposés
/// dans `dispose()`, jamais d'appel à `setState`. Les champs sont masqués des
/// enregistrements de session ([DonyReplayMask]).
class TaxInfoForm extends StatefulWidget {
  const TaxInfoForm({super.key});

  @override
  State<TaxInfoForm> createState() => _TaxInfoFormState();
}

class _TaxInfoFormState extends State<TaxInfoForm> {
  late final TextEditingController _number;
  late final TextEditingController _vat;
  late final TextEditingController _birthPlace;

  @override
  void initState() {
    super.initState();
    final state = context.read<TaxInfoCubit>().state;
    _number = TextEditingController(text: state.taxNumber);
    _vat = TextEditingController(text: state.vatNumber);
    _birthPlace = TextEditingController(text: state.birthPlace);
    _number.addListener(_onNumberChanged);
    _vat.addListener(_onVatChanged);
    _birthPlace.addListener(_onBirthPlaceChanged);
  }

  @override
  void dispose() {
    _number
      ..removeListener(_onNumberChanged)
      ..dispose();
    _vat
      ..removeListener(_onVatChanged)
      ..dispose();
    _birthPlace
      ..removeListener(_onBirthPlaceChanged)
      ..dispose();
    super.dispose();
  }

  void _onBirthPlaceChanged() {
    final cubit = context.read<TaxInfoCubit>();
    if (cubit.state.birthPlace != _birthPlace.text) {
      cubit.updateForm(birthPlace: _birthPlace.text);
    }
  }

  void _onNumberChanged() {
    final cubit = context.read<TaxInfoCubit>();
    if (cubit.state.taxNumber != _number.text) {
      cubit.updateForm(taxNumber: _number.text);
    }
  }

  void _onVatChanged() {
    final cubit = context.read<TaxInfoCubit>();
    if (cubit.state.vatNumber != _vat.text) {
      cubit.updateForm(vatNumber: _vat.text);
    }
  }

  Future<void> _pickCountry(String? current) async {
    final cubit = context.read<TaxInfoCubit>();
    // Catalogue de l'app et toute l'Union : le catalogue des devises seul
    // ne propose pas BG, CZ, DK, HU, PL, RO ni SE.
    final code = await showTaxResidencePicker(
      context,
      title: context.l10n.taxInfoCountryLabel,
      choices: taxIssuingCountryChoices(),
      selectedCode: current,
      analyticsName: 'tax-info/issuing-country',
    );
    if (code != null && !cubit.isClosed) cubit.updateForm(taxCountry: code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaxInfoCubit, TaxInfoState>(
      buildWhen: (p, c) =>
          p.offersNoTaxNumber != c.offersNoTaxNumber ||
          p.showsTaxNumberFields != c.showsTaxNumberFields ||
          p.asksBirthPlace != c.asksBirthPlace ||
          p.submitting != c.submitting,
      builder: (context, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.offersNoTaxNumber) ...[
            DonyCheckbox(
              key: const Key('tax_info_no_number'),
              label: context.l10n.taxInfoNoTaxNumber,
              value: s.noTaxNumber,
              enabled: !s.submitting,
              onChanged: (v) =>
                  context.read<TaxInfoCubit>().setNoTaxNumber(v ?? false),
            ),
            const SizedBox(height: DonySpacing.md),
          ],
          if (s.showsTaxNumberFields) _numberFields(context),
          if (s.asksBirthPlace) _birthPlaceField(context),
        ],
      ),
    );
  }

  Widget _birthPlaceField(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<TaxInfoCubit, TaxInfoState>(
      buildWhen: (p, c) =>
          p.serverRejected(kTaxFieldBirthPlace) !=
              c.serverRejected(kTaxFieldBirthPlace) ||
          p.submitting != c.submitting ||
          p.info != c.info,
      builder: (context, state) {
        final saved = state.info?.identity?.birthPlaceProvided ?? false;
        final error = state.serverRejected(kTaxFieldBirthPlace)
            ? l.taxInfoFieldInvalid
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyReplayMask(
              child: DonyTextField(
                key: const Key('tax_info_birth_place'),
                controller: _birthPlace,
                label: l.taxInfoBirthPlaceLabel,
                enabled: !state.submitting,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kTaxBirthPlaceMaxLength),
                ],
                errorText: error,
                errorMaxLines: 3,
              ),
            ),
            if (error == null)
              Padding(
                padding: const EdgeInsets.only(top: DonySpacing.xs),
                child: Text(
                  saved ? l.taxInfoBirthPlaceSaved : l.taxInfoBirthPlaceHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _numberFields(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocBuilder<TaxInfoCubit, TaxInfoState>(
          buildWhen: (p, c) =>
              p.isTaxNumberInvalid != c.isTaxNumberInvalid ||
              p.usesFrenchTaxNumberRule != c.usesFrenchTaxNumberRule ||
              p.serverRejectedTaxNumber != c.serverRejectedTaxNumber ||
              p.submitting != c.submitting,
          builder: (context, state) {
            // Erreur dès que le champ est non vide et invalide (numéro
            // français : 13 chiffres exacts), ou si le serveur a refusé ce
            // numéro (et non la TVA). L'aide neutre revient sinon.
            final errorText = state.isTaxNumberInvalid
                ? (state.usesFrenchTaxNumberRule
                      ? l.taxInfoNumberFrInvalid
                      : l.taxInfoNumberInvalid)
                : (state.serverRejectedTaxNumber
                      ? l.taxInfoError(kTaxInfoInvalidCode)
                      : null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyReplayMask(
                  child: DonyTextField(
                    key: const Key('tax_info_number'),
                    controller: _number,
                    label: l.taxInfoNumberLabel,
                    enabled: !state.submitting,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kTaxNumberMaxLength),
                    ],
                    // Identifiant fiscal : ni correcteur, ni suggestions, ni
                    // apprentissage du clavier ; majuscules (le back met en
                    // majuscules de toute façon).
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    textCapitalization: TextCapitalization.characters,
                    errorText: errorText,
                    errorMaxLines: 3,
                  ),
                ),
                if (errorText == null)
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.xs),
                    child: Text(
                      l.taxInfoNumberHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: DonySpacing.md),
        BlocBuilder<TaxInfoCubit, TaxInfoState>(
          buildWhen: (p, c) => p.taxCountry != c.taxCountry,
          builder: (context, state) {
            final code = state.taxCountry;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyTextField.tappable(
                  key: const Key('tax_info_country'),
                  label: l.taxInfoCountryLabel,
                  value: code == null ? null : taxCountryName(l, code),
                  trailing: DonyIcon(
                    'chevron-right',
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => _pickCountry(code),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Text(
                    l.taxInfoCountryHint,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: DonySpacing.md),
        BlocBuilder<TaxInfoCubit, TaxInfoState>(
          buildWhen: (p, c) =>
              p.isVatInvalid != c.isVatInvalid ||
              p.serverRejectedVat != c.serverRejectedVat ||
              p.submitting != c.submitting ||
              p.info != c.info ||
              p.vatNumber.trim().isEmpty != c.vatNumber.trim().isEmpty,
          builder: (context, state) {
            final errorText = state.isVatInvalid
                ? l.taxInfoNumberInvalid
                : (state.serverRejectedVat
                      ? l.taxInfoError(kTaxInfoInvalidCode)
                      : null);
            final field = DonyReplayMask(
              child: DonyTextField(
                key: const Key('tax_info_vat'),
                controller: _vat,
                label: l.taxInfoVatLabel,
                enabled: !state.submitting,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kVatNumberMaxLength),
                ],
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                textCapitalization: TextCapitalization.characters,
                errorText: errorText,
                errorMaxLines: 3,
              ),
            );
            // Numéro de TVA déjà enregistré : l'envoi du numéro fiscal sans
            // TVA l'efface (contrat du back), on le dit.
            final erases =
                errorText == null &&
                (state.info?.vatNumberProvided ?? false) &&
                state.vatNumber.trim().isEmpty;
            if (!erases) return field;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Text(
                    l.taxInfoVatWillBeErased,
                    key: const Key('tax_info_vat_erase_hint'),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
