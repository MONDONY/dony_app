import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Comment voyagez-vous ? » : le voyageur déclare s'il voyage comme
/// particulier ou comme professionnel.
///
/// Deux étapes. 1 : le choix, sans présélection, « Continuer » grisé tant que
/// rien n'est choisi. 2 : la case de confirmation d'un particulier, ou la
/// raison sociale, le numéro d'entreprise et le pays d'un professionnel.
///
/// Les boutons vivent dans le `stickyBottom` ([_TravelerStatusActions]) et
/// lisent le même cubit que le contenu (le `wrapper` les enveloppe ensemble).
/// Les contrôleurs de texte appartiennent au `State` du contenu : jamais
/// disposés dans un `whenComplete`, la feuille reste affichée pendant son
/// animation de sortie.
class TravelerStatusSheet extends StatefulWidget {
  const TravelerStatusSheet({super.key, this.required = false});

  /// Déclaration exigée par Yadony pour publier : pas de « Plus tard ».
  final bool required;

  /// Ouvre la feuille. Rend `true` si le statut vient d'être déclaré, `false`
  /// si le voyageur a choisi « Plus tard », `null` si la feuille est fermée
  /// d'un geste. Après une déclaration, le profil du compte est rechargé pour
  /// que la pastille et la ligne du profil suivent.
  static Future<bool?> show(
    BuildContext context, {
    bool required = false,
  }) async {
    final auth = maybeRead<AuthBloc>(context);
    final declared = await DonyBottomSheet.show<bool>(
      context,
      analyticsName: 'traveler-status',
      wrapper: (child) => BlocProvider<TravelerStatusCubit>(
        create: (_) => getIt<TravelerStatusCubit>(),
        child: child,
      ),
      stickyBottom: _TravelerStatusActions(required: required),
      child: TravelerStatusSheet(required: required),
    );
    if (declared == true) auth?.add(const AuthProfileRefreshRequested());
    return declared;
  }

  @override
  State<TravelerStatusSheet> createState() => _TravelerStatusSheetState();
}

class _TravelerStatusSheetState extends State<TravelerStatusSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _numberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _numberCtrl.addListener(_onNumberChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _numberCtrl.removeListener(_onNumberChanged);
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() =>
      context.read<TravelerStatusCubit>().updateBusiness(name: _nameCtrl.text);

  void _onNumberChanged() => context.read<TravelerStatusCubit>().updateBusiness(
    registrationNumber: _numberCtrl.text,
  );

  Future<void> _pickCountry(String? current) async {
    final cubit = context.read<TravelerStatusCubit>();
    final code = await showCountryPicker(
      context,
      title: context.l10n.travelerStatusCountryLabel,
      selectedCode: current,
      showFlag: false,
    );
    if (code != null) cubit.updateBusiness(country: code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TravelerStatusCubit, TravelerStatusState>(
      listenWhen: (prev, curr) =>
          curr is TravelerStatusSuccess ||
          curr is TravelerStatusFailure ||
          prev.form.choice != curr.form.choice,
      listener: (context, state) {
        switch (state) {
          case TravelerStatusSuccess():
            Navigator.of(context).pop(true);
          case TravelerStatusFailure(:final error):
            ErrorPresenter.show(context, error);
          case TravelerStatusEditing() || TravelerStatusInitial():
            // Autre statut choisi : la saisie de l'ancien ne vaut plus rien.
            if (state.form.businessName.isEmpty) _nameCtrl.clear();
            if (state.form.registrationNumber.isEmpty) _numberCtrl.clear();
          case TravelerStatusSubmitting():
            break;
        }
      },
      buildWhen: (prev, curr) =>
          prev.form.choice != curr.form.choice ||
          prev.form.detailsStep != curr.form.detailsStep ||
          prev.form.confirmed != curr.form.confirmed ||
          prev.form.country != curr.form.country,
      builder: (context, state) {
        final form = state.form;
        final l = context.l10n;
        if (!form.detailsStep) {
          return _ChoiceStep(
            required: widget.required,
            choice: form.choice,
            onChoose: context.read<TravelerStatusCubit>().choose,
          );
        }
        return switch (form.choice) {
          TravelerStatus.individual => _IndividualStep(
            confirmed: form.confirmed,
            onConfirmed: context.read<TravelerStatusCubit>().setConfirmed,
          ),
          TravelerStatus.professional => _ProfessionalStep(
            nameCtrl: _nameCtrl,
            numberCtrl: _numberCtrl,
            countryLabel: form.country == null
                ? null
                : countryName(l, form.country!),
            onPickCountry: () => _pickCountry(form.country),
          ),
          null => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.headlineSmall),
        const SizedBox(height: DonySpacing.xs),
        Text(
          subtitle,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.required,
    required this.choice,
    required this.onChoose,
  });

  final bool required;
  final TravelerStatus? choice;
  final ValueChanged<TravelerStatus> onChoose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          title: l.travelerStatusSheetTitle,
          subtitle: required
              ? l.travelerStatusSheetSubtitleRequired
              : l.travelerStatusSheetSubtitle,
        ),
        DonyRadioGroup<TravelerStatus>(
          value: choice,
          onChanged: (value) {
            if (value != null) onChoose(value);
          },
          options: [
            DonyRadioOption(
              value: TravelerStatus.individual,
              label: l.travelerStatusOptionIndividual,
              subtitle: l.travelerStatusOptionIndividualBody,
            ),
            DonyRadioOption(
              value: TravelerStatus.professional,
              label: l.travelerStatusOptionProfessional,
              subtitle: l.travelerStatusOptionProfessionalBody,
            ),
          ],
        ),
      ],
    );
  }
}

class _IndividualStep extends StatelessWidget {
  const _IndividualStep({required this.confirmed, required this.onConfirmed});

  final bool confirmed;
  final ValueChanged<bool> onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          title: l.travelerStatusIndividualTitle,
          subtitle: l.travelerStatusIndividualSubtitle,
        ),
        DonyCheckbox(
          label: l.travelerStatusIndividualConfirm,
          value: confirmed,
          onChanged: (v) => onConfirmed(v ?? false),
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          l.travelerStatusIndividualHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Numéro saisi mais refusé : non vide et invalide.
bool _numberInvalid(TravelerStatusEditing form) =>
    form.registrationNumber.trim().isNotEmpty &&
    !form.isRegistrationNumberValid;

class _ProfessionalStep extends StatelessWidget {
  const _ProfessionalStep({
    required this.nameCtrl,
    required this.numberCtrl,
    required this.countryLabel,
    required this.onPickCountry,
  });

  final TextEditingController nameCtrl;
  final TextEditingController numberCtrl;
  final String? countryLabel;
  final VoidCallback onPickCountry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          title: l.travelerStatusProfessionalTitle,
          subtitle: l.travelerStatusProfessionalSubtitle,
        ),
        DonyTextField(
          controller: nameCtrl,
          label: l.travelerStatusBusinessNameLabel,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
        ),
        const SizedBox(height: DonySpacing.md),
        // Erreur dès que le champ est non vide et invalide (moins de 4
        // caractères, caractère interdit) : sans elle, « Enregistrer » restait
        // grisé sans explication. L'aide neutre revient champ vide ou valide.
        BlocBuilder<TravelerStatusCubit, TravelerStatusState>(
          buildWhen: (prev, curr) =>
              _numberInvalid(prev.form) != _numberInvalid(curr.form),
          builder: (context, state) {
            final invalid = _numberInvalid(state.form);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyTextField(
                  controller: numberCtrl,
                  label: l.travelerStatusRegistrationLabel,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  errorText: invalid
                      ? l.travelerStatusRegistrationInvalid
                      : null,
                ),
                if (!invalid)
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.xs),
                    child: Text(
                      l.travelerStatusRegistrationHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: DonySpacing.md),
        DonyTextField.tappable(
          label: l.travelerStatusCountryLabel,
          value: countryLabel,
          trailing: DonyIcon('chevron-right', color: cs.onSurfaceVariant),
          onTap: onPickCountry,
        ),
      ],
    );
  }
}

/// Pied collant : le bouton principal, puis « Plus tard » (étape 1, si la
/// déclaration est facultative) ou « Retour » (étape 2).
class _TravelerStatusActions extends StatelessWidget {
  const _TravelerStatusActions({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<TravelerStatusCubit, TravelerStatusState>(
      builder: (context, state) {
        final cubit = context.read<TravelerStatusCubit>();
        final form = state.form;
        final submitting = state is TravelerStatusSubmitting;
        if (!form.detailsStep) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyButton(
                label: l.commonContinue,
                onPressed: form.canContinue ? cubit.continueToDetails : null,
              ),
              if (!required) ...[
                const SizedBox(height: DonySpacing.xs),
                DonyButton(
                  label: l.commonLater,
                  variant: DonyButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: l.commonSave,
              isLoading: submitting,
              onPressed: form.canSubmit && !submitting ? cubit.submit : null,
            ),
            const SizedBox(height: DonySpacing.xs),
            DonyButton(
              label: l.commonBack,
              variant: DonyButtonVariant.ghost,
              onPressed: submitting ? null : cubit.back,
            ),
          ],
        );
      },
    );
  }
}
