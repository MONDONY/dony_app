import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tax_info/bloc/tax_info_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire des informations fiscales : numéro fiscal, pays d'émission du
/// numéro, numéro de TVA facultatif.
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

  @override
  void initState() {
    super.initState();
    final state = context.read<TaxInfoCubit>().state;
    _number = TextEditingController(text: state.taxNumber);
    _vat = TextEditingController(text: state.vatNumber);
    _number.addListener(_onNumberChanged);
    _vat.addListener(_onVatChanged);
  }

  @override
  void dispose() {
    _number
      ..removeListener(_onNumberChanged)
      ..dispose();
    _vat
      ..removeListener(_onVatChanged)
      ..dispose();
    super.dispose();
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
    final code = await showCountryPicker(
      context,
      title: context.l10n.taxInfoCountryLabel,
      selectedCode: current,
      showFlag: false,
    );
    if (code != null && !cubit.isClosed) cubit.updateForm(taxCountry: code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocBuilder<TaxInfoCubit, TaxInfoState>(
          buildWhen: (p, c) =>
              p.isTaxNumberInvalid != c.isTaxNumberInvalid ||
              p.serverRejectedTaxNumber != c.serverRejectedTaxNumber ||
              p.submitting != c.submitting,
          builder: (context, state) {
            // Erreur dès que le champ est non vide et invalide, ou si le
            // serveur a refusé ce numéro (et non la TVA). L'aide neutre
            // revient sinon.
            final errorText = state.isTaxNumberInvalid
                ? l.taxInfoNumberInvalid
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
                  value: code == null ? null : countryName(l, code),
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
              p.submitting != c.submitting,
          builder: (context, state) {
            final errorText = state.isVatInvalid
                ? l.taxInfoNumberInvalid
                : (state.serverRejectedVat
                      ? l.taxInfoError(kTaxInfoInvalidCode)
                      : null);
            return DonyReplayMask(
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
          },
        ),
      ],
    );
  }
}
