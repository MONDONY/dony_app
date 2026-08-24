import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/personal_info_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Étape « Vos informations » du parcours d'onboarding, entre la sélection du
/// pays (`/auth/country-selection`) et le code de parrainage
/// (`/auth/referral-code`).
///
/// Ne collecte que le nom légal. Date de naissance et adresse de résidence
/// appartiennent au formulaire Stripe Connect, qui les redemande et les
/// revalide de toute façon : les recueillir ici doublait la saisie et
/// exposait à des écarts de format que Stripe finissait par refuser. Le
/// téléphone n'y figure pas non plus — c'est le canal d'authentification
/// propre à Stripe.
///
/// [country] est le code pays ISO 3166-1 alpha-2 (ex. `FR`) choisi à l'étape
/// précédente (`CountryOnboardingCubit`) et exposé par `BusinessPrefsBloc`,
/// injecté par le routeur — jamais lu directement ici via ce Bloc pour que
/// cet écran reste testable sans provider ambiant. [progress] suit la même
/// règle : lu par `readOnboardingProgress` dans le routeur, jamais ici.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({
    super.key,
    this.country,
    this.user,
    required this.progress,
  });

  final String? country;

  /// Profil connu à l'ouverture, pour préremplir ce qui l'est déjà (retour
  /// sur l'étape depuis la bannière du profil, second passage). `null` quand
  /// le profil n'est pas encore chargé — les champs restent vides.
  final UserModel? user;

  final OnboardingProgress progress;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  // Le champ verrouillé affiche le nom lisible ('France'), jamais le code
  // ISO brut ('FR') que porte `widget.country`.
  String? get _countryName => CountryCatalog.byCode(widget.country)?.name;

  late final _countryCtrl = TextEditingController(
    text: _countryName ?? 'Non renseigné',
  );
  late final _firstNameCtrl = TextEditingController(
    text: widget.user?.firstName ?? '',
  );
  late final _lastNameCtrl = TextEditingController(
    text: widget.user?.lastName ?? '',
  );
  final _isValid = ValueNotifier<bool>(false);

  void _revalidate() {
    _isValid.value =
        _firstNameCtrl.text.trim().isNotEmpty &&
        _lastNameCtrl.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_revalidate);
    _lastNameCtrl.addListener(_revalidate);
    _revalidate();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _isValid.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<PersonalInfoCubit>().submit(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<PersonalInfoCubit, PersonalInfoState>(
      listener: (context, state) {
        if (state is PersonalInfoSuccess) {
          // `submit()` vient d'écrire le nom ; `skip()` n'écrit rien (les deux
          // mènent ici). Sans ce refresh, le `UserModel` en cache reste périmé
          // et l'étape « informations » regresserait sur
          // `/auth/referral-code`, faute de source fraîche (`nextStep`,
          // correction 1 de la revue finale).
          context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          // Repli immédiat pour l'étape « pays » : ce refresh est un GET
          // asynchrone non attendu (ne jamais bloquer cette navigation
          // dessus), et `/auth/referral-code` peut se construire avant qu'il
          // ne revienne. `widget.country` — déjà connu de cet écran — comble
          // ce trou exactement comme `country_selection_screen.dart` le fait
          // pour celui-ci (voir `router.dart`, route
          // `/auth/referral-code`).
          context.go('/auth/referral-code', extra: widget.country);
        } else if (state is PersonalInfoError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is PersonalInfoSaving;

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
                        AuthFlowHeader.gauge(
                          segments: widget.progress.segments,
                          label: 'Informations',
                        ),
                        const SizedBox(height: DonySpacing.md),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AuthIntroCard.compact(
                                      iconAsset: 'user',
                                      title: 'Vos informations',
                                      body:
                                          'Votre nom légal, tel qu’il figure sur votre pièce d’identité. Le reste vous sera demandé une seule fois, par Stripe.',
                                      footnote:
                                          'Jamais partagées avec les autres membres, jamais affichées publiquement.',
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.04),
                                const SizedBox(height: DonySpacing.md),
                                _IdentityFieldsPanel(
                                  country: _countryName,
                                  countryCtrl: _countryCtrl,
                                  firstNameCtrl: _firstNameCtrl,
                                  lastNameCtrl: _lastNameCtrl,
                                  isSaving: isSaving,
                                ).animate().fadeIn(
                                  delay: 120.ms,
                                  duration: 300.ms,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AuthFlowActions(
                          primary: ValueListenableBuilder<bool>(
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
                          skipEnabled: !isSaving,
                          onSkip: () =>
                              context.read<PersonalInfoCubit>().skip(),
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

class _IdentityFieldsPanel extends StatelessWidget {
  const _IdentityFieldsPanel({
    required this.country,
    required this.countryCtrl,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.isSaving,
  });

  final String? country;
  final TextEditingController countryCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
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
          const AddressSectionLabel('Identité'),
          Row(
            children: [
              Expanded(
                child: DonyTextField(
                  key: const Key('identity-first-name'),
                  textInputAction: TextInputAction.next,
                  controller: firstNameCtrl,
                  enabled: !isSaving,
                  label: 'Prénom',
                  hint: 'Awa',
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyTextField(
                  key: const Key('identity-last-name'),
                  textInputAction: TextInputAction.done,
                  controller: lastNameCtrl,
                  enabled: !isSaving,
                  label: 'Nom',
                  hint: 'Diallo',
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xl),
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
        ],
      ),
    );
  }
}
