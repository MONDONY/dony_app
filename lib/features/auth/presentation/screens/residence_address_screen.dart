import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/address/address_section_label.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/residence_address_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Étape « Vos informations » du parcours d'onboarding, entre la sélection du
/// pays (`/auth/country-selection`) et le code de parrainage
/// (`/auth/referral-code`).
///
/// Collecte l'identité déclarée (prénom, nom, date de naissance) **et**
/// l'adresse de résidence : ce sont exactement les champs que Stripe Connect
/// redemanderait plus tard. Les recueillir ici, dans le parcours yadony,
/// évite de les ressaisir dans le formulaire Stripe. Le téléphone n'y figure
/// pas — Stripe le redemande de toute façon pour sa propre authentification.
///
/// [country] est le code pays ISO 3166-1 alpha-2 (ex. `FR`) choisi à l'étape
/// précédente (`CountryOnboardingCubit`) et exposé par `BusinessPrefsBloc`,
/// injecté par le routeur — jamais lu directement ici via ce Bloc pour que
/// cet écran reste testable sans provider ambiant. [progress] suit la même
/// règle : lu par `readOnboardingProgress` dans le routeur, jamais ici.
class ResidenceAddressScreen extends StatefulWidget {
  const ResidenceAddressScreen({
    super.key,
    this.country,
    this.user,
    required this.addressService,
    required this.progress,
  });

  final String? country;

  /// Profil connu à l'ouverture, pour préremplir ce qui l'est déjà (retour
  /// sur l'étape depuis la bannière du profil, second passage). `null` quand
  /// le profil n'est pas encore chargé — les champs restent vides.
  final UserModel? user;

  /// Injecté par le routeur, jamais lu par `getIt` ici : cet écran doit
  /// rester montable en test sans conteneur d'injection, au même titre qu'il
  /// l'est sans provider ambiant.
  final AddressAutocompleteService addressService;

  final OnboardingProgress progress;

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
  late final _firstNameCtrl = TextEditingController(
    text: widget.user?.firstName ?? '',
  );
  late final _lastNameCtrl = TextEditingController(
    text: widget.user?.lastName ?? '',
  );
  final _streetCtrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  late final _cityCtrl = TextEditingController(text: widget.user?.city ?? '');
  final _isValid = ValueNotifier<bool>(false);

  /// Date de naissance choisie. Portée par un [ValueNotifier] plutôt que par
  /// `setState` : cet écran n'a aucun état local à reconstruire en dehors du
  /// libellé du champ et de la validité du bouton.
  late final _birthDate = ValueNotifier<DateTime?>(widget.user?.birthDate);

  void _revalidate() {
    _isValid.value =
        _firstNameCtrl.text.trim().isNotEmpty &&
        _lastNameCtrl.text.trim().isNotEmpty &&
        _birthDate.value != null &&
        _streetCtrl.text.trim().isNotEmpty &&
        _postalCtrl.text.trim().isNotEmpty &&
        _cityCtrl.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      _firstNameCtrl,
      _lastNameCtrl,
      _streetCtrl,
      _postalCtrl,
      _cityCtrl,
    ]) {
      ctrl.addListener(_revalidate);
    }
    _birthDate.addListener(_revalidate);
    _revalidate();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _streetCtrl.dispose();
    _line2Ctrl.dispose();
    _postalCtrl.dispose();
    _cityCtrl.dispose();
    _birthDate.dispose();
    _isValid.dispose();
    super.dispose();
  }

  /// Une suggestion Google résolue remplit le code postal et la ville : c'est
  /// tout l'intérêt de l'autocomplétion, ne pas faire retaper ce que l'adresse
  /// contient déjà. Le texte libre reste possible (quartiers mal couverts).
  void _onAddressResolved(AddressData address) {
    if (address.postalCode != null && address.postalCode!.isNotEmpty) {
      _postalCtrl.text = address.postalCode!;
    }
    if (address.city != null && address.city!.isNotEmpty) {
      _cityCtrl.text = address.city!;
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate.value ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      // Stripe Connect exige 18 ans révolus pour un compte de paiement :
      // proposer plus jeune ne mènerait qu'à un refus chez eux.
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Votre date de naissance',
    );
    if (picked != null) _birthDate.value = picked;
  }

  String? _trimmedOrNull(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  void _submit() {
    context.read<ResidenceAddressCubit>().submit(
      street: _streetCtrl.text.trim(),
      line2: _trimmedOrNull(_line2Ctrl),
      postalCode: _postalCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      firstName: _trimmedOrNull(_firstNameCtrl),
      lastName: _trimmedOrNull(_lastNameCtrl),
      birthDate: _birthDate.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<ResidenceAddressCubit, ResidenceAddressState>(
      listener: (context, state) {
        if (state is ResidenceAddressSuccess) {
          // `submit()` vient d'écrire `users.residence_street` ; `skip()`
          // pose `onboarding_seen_at` (les deux mènent ici). Sans ce refresh,
          // le `UserModel` en cache reste périmé et l'étape « adresse »
          // regresserait sur `/auth/referral-code`, faute de source fraîche
          // (`nextStep`, correction 1 de la revue finale).
          context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          // Repli immédiat pour l'étape « pays » : ce refresh est un GET
          // asynchrone non attendu (ne jamais bloquer cette navigation
          // dessus), et `/auth/referral-code` peut se construire avant qu'il
          // ne revienne. `widget.country` — déjà connu de cet écran — comble
          // ce trou exactement comme `country_selection_screen.dart` le fait
          // pour celui-ci (voir `router.dart`, route
          // `/auth/referral-code`).
          context.go('/auth/referral-code', extra: widget.country);
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
                                          'Elles préparent vos paiements Yadony et vous évitent de tout ressaisir chez Stripe.',
                                      footnote:
                                          'Jamais partagées avec les autres membres, jamais affichées publiquement.',
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.04),
                                const SizedBox(height: DonySpacing.md),
                                _ResidenceFieldsPanel(
                                  country: _countryName,
                                  countryCtrl: _countryCtrl,
                                  firstNameCtrl: _firstNameCtrl,
                                  lastNameCtrl: _lastNameCtrl,
                                  birthDate: _birthDate,
                                  onPickBirthDate: _pickBirthDate,
                                  streetCtrl: _streetCtrl,
                                  line2Ctrl: _line2Ctrl,
                                  postalCtrl: _postalCtrl,
                                  cityCtrl: _cityCtrl,
                                  addressService: widget.addressService,
                                  onAddressResolved: _onAddressResolved,
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
                              context.read<ResidenceAddressCubit>().skip(),
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
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.birthDate,
    required this.onPickBirthDate,
    required this.streetCtrl,
    required this.line2Ctrl,
    required this.postalCtrl,
    required this.cityCtrl,
    required this.addressService,
    required this.onAddressResolved,
    required this.isSaving,
  });

  final String? country;
  final TextEditingController countryCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final ValueNotifier<DateTime?> birthDate;
  final VoidCallback onPickBirthDate;
  final TextEditingController streetCtrl;
  final TextEditingController line2Ctrl;
  final TextEditingController postalCtrl;
  final TextEditingController cityCtrl;
  final AddressAutocompleteService addressService;
  final ValueChanged<AddressData> onAddressResolved;
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
                  textInputAction: TextInputAction.next,
                  controller: lastNameCtrl,
                  enabled: !isSaving,
                  label: 'Nom',
                  hint: 'Diallo',
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          ValueListenableBuilder<DateTime?>(
            valueListenable: birthDate,
            builder: (context, value, _) => _BirthDateField(
              value: value,
              enabled: !isSaving,
              onTap: onPickBirthDate,
            ),
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
          const SizedBox(height: DonySpacing.xl),
          const AddressSectionLabel('Adresse'),
          // Même autocomplétion Google que les adresses de retrait et de
          // livraison (proxy backend `/addresses/autocomplete`, une session
          // Google facturée par saisie complète). Choisir une suggestion
          // remplit code postal et ville ; le texte libre reste accepté pour
          // les quartiers que Google couvre mal.
          AddressSuggestField(
            key: const Key('residence-street'),
            controller: streetCtrl,
            service: addressService,
            label: 'Rue et numéro',
            hint: '12 rue de la Paix',
            prefixIconAsset: 'map-pin',
            prefixIconColor: cs.primary,
            onResolved: onAddressResolved,
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

/// Champ de date de naissance : un [DonyTextField] désactivé qui ouvre le
/// sélecteur au tap.
///
/// Un `TextField` en lecture seule plutôt qu'un contrôle sur mesure, pour que
/// le champ soit visuellement identique à ses voisins (même hauteur, même
/// bordure, même libellé flottant) — un composant qui détonne au milieu d'un
/// formulaire se lit comme un bug.
class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = value == null
        ? ''
        // 'fr' et non 'fr_FR' : c'est la locale que `main.dart` initialise
        // (`initializeDateFormatting('fr')`), et celle qu'emploient les autres
        // écrans de l'app.
        : DateFormat('d MMMM yyyy', 'fr').format(value!);

    return Semantics(
      button: true,
      label: value == null
          ? 'Date de naissance, non renseignée. Appuyez pour choisir.'
          : 'Date de naissance : $label. Appuyez pour modifier.',
      child: GestureDetector(
        key: const Key('identity-birth-date'),
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        // `IgnorePointer` et non `AbsorbPointer` : le second est lui-même une
        // cible de hit test et avalait le tap sans le transmettre au
        // `GestureDetector` parent — le sélecteur ne s'ouvrait jamais. Ignorer
        // le sous-arbre laisse le parent opaque le recevoir.
        child: IgnorePointer(
          child: DonyTextField(
            controller: TextEditingController(text: label),
            enabled: false,
            label: 'Date de naissance',
            hint: 'Choisir une date',
            prefixWidget: DonyIcon(
              'calendar',
              size: 20,
              color: enabled ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
