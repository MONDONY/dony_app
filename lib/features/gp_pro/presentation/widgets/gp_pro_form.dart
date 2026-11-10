import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_frequency_chips.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_pieces_section.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire de demande GP Pro : fréquence, raison sociale, numéro et pays
/// d'immatriculation de l'entreprise (obligatoires), justificatifs
/// (facultatifs), phrase RGPD.
///
/// Le bouton d'envoi vit dans la barre fixe de l'écran : il reçoit la
/// soumission par [onSubmitReady]. La saisie vit dans [GpProCubit] (le bouton
/// en dépend) ; les contrôleurs de texte restent dans ce `State`, disposés dans
/// `dispose()`, jamais d'appel à `setState`.
class GpProForm extends StatefulWidget {
  const GpProForm({required this.onSubmitReady, super.key});

  final ValueChanged<VoidCallback> onSubmitReady;

  /// Longueur maximale de la raison sociale (contrat back).
  static const maxBusinessName = 80;

  @override
  State<GpProForm> createState() => _GpProFormState();
}

class _GpProFormState extends State<GpProForm> {
  late final TextEditingController _name;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<GpProCubit>();
    // Le formulaire peut être reconstruit (retour du suivi à « Refaire une
    // demande ») : la saisie déjà gardée par le cubit est reprise.
    _name = TextEditingController(text: cubit.state.businessName);
    _number = TextEditingController(text: cubit.state.registrationNumber);
    _name.addListener(_onNameChanged);
    _number.addListener(_onNumberChanged);
    widget.onSubmitReady(cubit.submit);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    _number
      ..removeListener(_onNumberChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() =>
      context.read<GpProCubit>().updateBusiness(name: _name.text);

  void _onNumberChanged() => context.read<GpProCubit>().updateBusiness(
    registrationNumber: _number.text,
  );

  Future<void> _pickCountry(String? current) async {
    final cubit = context.read<GpProCubit>();
    final code = await showCountryPicker(
      context,
      title: context.l10n.gpProCountryLabel,
      selectedCode: current,
      showFlag: false,
    );
    if (code != null) cubit.updateBusiness(country: code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.gpProFrequencyLabel,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        BlocBuilder<GpProCubit, GpProCubitState>(
          buildWhen: (p, c) => p.frequency != c.frequency,
          builder: (context, state) => GpProFrequencyChips(
            selected: state.frequency,
            onChanged: context.read<GpProCubit>().selectFrequency,
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyReplayMask(
          child: DonyTextField(
            controller: _name,
            label: l.gpProBusinessNameLabel,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(GpProForm.maxBusinessName),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        // Erreur dès que le champ est non vide et invalide (moins de 4
        // caractères, caractère interdit) : sans elle, « Envoyer ma demande »
        // restait grisé sans explication. L'aide neutre revient champ vide ou
        // valide.
        BlocBuilder<GpProCubit, GpProCubitState>(
          buildWhen: (p, c) =>
              p.isRegistrationNumberInvalid != c.isRegistrationNumberInvalid,
          builder: (context, state) {
            final invalid = state.isRegistrationNumberInvalid;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyReplayMask(
                  child: DonyTextField(
                    controller: _number,
                    label: l.gpProRegistrationLabel,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        kGpProRegistrationMaxLength,
                      ),
                    ],
                    errorText: invalid ? l.gpProRegistrationInvalid : null,
                  ),
                ),
                if (!invalid)
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.xs),
                    child: Text(
                      l.gpProRegistrationHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: DonySpacing.md),
        BlocBuilder<GpProCubit, GpProCubitState>(
          buildWhen: (p, c) => p.businessCountry != c.businessCountry,
          builder: (context, state) {
            final code = state.businessCountry;
            return DonyTextField.tappable(
              label: l.gpProCountryLabel,
              value: code == null ? null : countryName(l, code),
              trailing: DonyIcon('chevron-right', color: cs.onSurfaceVariant),
              onTap: () => _pickCountry(code),
            );
          },
        ),
        const SizedBox(height: DonySpacing.base),
        const GpProPiecesSection(),
      ],
    );
  }
}
