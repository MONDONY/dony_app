import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/residence_address_cubit.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Étape « adresse de résidence » du parcours d'onboarding, entre la
/// sélection du pays (`/auth/country-selection`) et le code de parrainage
/// (`/auth/referral-code`).
///
/// [country] est le code pays ISO 3166-1 alpha-2 (ex. `FR`) choisi à l'étape
/// précédente (`CountryOnboardingCubit`) et exposé par `BusinessPrefsBloc`,
/// injecté par le routeur — jamais lu directement ici via ce Bloc pour que
/// cet écran reste testable sans provider ambiant.
class ResidenceAddressScreen extends StatefulWidget {
  const ResidenceAddressScreen({super.key, this.country});

  final String? country;

  @override
  State<ResidenceAddressScreen> createState() => _ResidenceAddressScreenState();
}

class _ResidenceAddressScreenState extends State<ResidenceAddressScreen> {
  // Le champ verrouillé affiche le nom lisible ('France'), jamais le code
  // ISO brut ('FR') que porte `widget.country`.
  String? get _countryName => CountryCatalog.byCode(widget.country)?.name;

  late final _countryCtrl = TextEditingController(
    text: _countryName ?? 'Non renseigné',
  );
  final _streetCtrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _isValid = ValueNotifier<bool>(false);

  void _revalidate() {
    _isValid.value =
        _streetCtrl.text.trim().isNotEmpty &&
        _postalCtrl.text.trim().isNotEmpty &&
        _cityCtrl.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _streetCtrl.addListener(_revalidate);
    _postalCtrl.addListener(_revalidate);
    _cityCtrl.addListener(_revalidate);
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _streetCtrl.dispose();
    _line2Ctrl.dispose();
    _postalCtrl.dispose();
    _cityCtrl.dispose();
    _isValid.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ResidenceAddressCubit>().submit(
      street: _streetCtrl.text.trim(),
      line2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
      postalCode: _postalCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<ResidenceAddressCubit, ResidenceAddressState>(
      listener: (context, state) {
        if (state is ResidenceAddressSuccess) {
          context.go('/auth/referral-code');
        } else if (state is ResidenceAddressError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is ResidenceAddressSaving;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AuthFlowBackground(),
              SafeArea(
                child: DonyLayout.constrained(
                  context,
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      h,
                      DonySpacing.base,
                      h,
                      DonySpacing.base + bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFlowHeader(
                          current: 3,
                          total: 4,
                          label: 'Adresse',
                          showBack: false,
                        ),
                        const SizedBox(height: DonySpacing.md),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AuthIntroCard(
                                      iconAsset: 'map-pin',
                                      title: 'Où résides-tu ?',
                                      body:
                                          'Cette adresse sert à préparer tes paiements Yadony. Elle n’est jamais partagée avec les autres membres.',
                                      footnote:
                                          'Utilisée uniquement pour ton compte de paiement, jamais affichée publiquement.',
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.04),
                                const SizedBox(height: DonySpacing.md),
                                _ResidenceFieldsPanel(
                                  country: _countryName,
                                  countryCtrl: _countryCtrl,
                                  streetCtrl: _streetCtrl,
                                  line2Ctrl: _line2Ctrl,
                                  postalCtrl: _postalCtrl,
                                  cityCtrl: _cityCtrl,
                                  isSaving: isSaving,
                                ).animate().fadeIn(
                                  delay: 120.ms,
                                  duration: 300.ms,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isValid,
                          builder: (context, hasAllFields, _) => DonyButton(
                            label: 'Continuer',
                            iconAsset: 'arrow-right',
                            isLoading: isSaving,
                            onPressed: hasAllFields && !isSaving
                                ? _submit
                                : null,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => context
                                    .read<ResidenceAddressCubit>()
                                    .skip(),
                          child: Text(
                            'Passer pour l\'instant',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Champs du formulaire ─────────────────────────────────────────────────────

class _ResidenceFieldsPanel extends StatelessWidget {
  const _ResidenceFieldsPanel({
    required this.country,
    required this.countryCtrl,
    required this.streetCtrl,
    required this.line2Ctrl,
    required this.postalCtrl,
    required this.cityCtrl,
    required this.isSaving,
  });

  final String? country;
  final TextEditingController countryCtrl;
  final TextEditingController streetCtrl;
  final TextEditingController line2Ctrl;
  final TextEditingController postalCtrl;
  final TextEditingController cityCtrl;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: isLight
            ? cs.surface.withValues(alpha: 0.94)
            : DonyColors.ink900.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(
          color: isLight
              ? cs.outline.withValues(alpha: 0.42)
              : DonyColors.neutral0.withValues(alpha: 0.18),
        ),
        boxShadow: DonyShadow.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AddressSectionLabel('Pays'),
          Semantics(
            container: true,
            label: country != null
                ? 'Pays de résidence : $country. Déterminé à l’inscription, non modifiable ici.'
                : 'Pays de résidence non renseigné. Déterminé à l’inscription, non modifiable ici.',
            child: DonyTextField(
              enabled: false,
              controller: countryCtrl,
              label: 'Pays',
              prefixWidget: DonyIcon('globe', size: 20, color: cs.primary),
            ),
          ),
          const SizedBox(height: DonySpacing.xl),
          const AddressSectionLabel('Adresse'),
          DonyTextField(
            key: const Key('residence-street'),
            textInputAction: TextInputAction.next,
            controller: streetCtrl,
            enabled: !isSaving,
            label: 'Rue et numéro',
            hint: '12 rue de la Paix',
            prefixWidget: DonyIcon('map-pin', size: 20, color: cs.primary),
          ),
          const SizedBox(height: DonySpacing.base),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DonyTextField(
                  key: const Key('residence-postal'),
                  textInputAction: TextInputAction.next,
                  controller: postalCtrl,
                  enabled: !isSaving,
                  label: 'Code postal',
                  hint: '75001',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                flex: 3,
                child: DonyTextField(
                  key: const Key('residence-city'),
                  textInputAction: TextInputAction.next,
                  controller: cityCtrl,
                  enabled: !isSaving,
                  label: 'Ville',
                  hint: 'Paris',
                  prefixWidget: DonyIcon(
                    'building-2',
                    size: 20,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          DonyTextField(
            key: const Key('residence-line2'),
            textInputAction: TextInputAction.done,
            controller: line2Ctrl,
            enabled: !isSaving,
            label: 'Étage / Appartement',
            hint: 'Optionnel (Ex : Bât. B, 3ème étage)',
            prefixWidget: DonyIcon('house', size: 20, color: cs.primary),
          ),
        ],
      ),
    );
  }
}
