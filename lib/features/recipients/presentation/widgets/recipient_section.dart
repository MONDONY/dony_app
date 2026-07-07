import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Déduit le pays destination du préfixe E.164.
String countryFromPhone(String phoneE164) {
  if (phoneE164.startsWith('+221')) {
    return 'SN';
  }
  if (phoneE164.startsWith('+225')) {
    return 'CI';
  }
  if (phoneE164.startsWith('+223')) {
    return 'ML';
  }
  if (phoneE164.startsWith('+237')) {
    return 'CM';
  }
  return 'SN';
}

/// Poignée donnée au formulaire hôte pour déclencher la sauvegarde
/// du destinataire saisi manuellement après une soumission réussie.
class RecipientSectionController {
  VoidCallback? _saveHook;
  void maybeSaveManualEntry() => _saveHook?.call();
}

/// Bloc « Destinataire » partagé par les formulaires d'envoi :
/// bouton « Choisir un destinataire » (état initial) → carte sélectionnée
/// (état 2) → saisie manuelle avec toggle « Enregistrer » (état 3).
class RecipientSection extends StatefulWidget {
  const RecipientSection({
    super.key,
    required this.controller,
    required this.nameCtrl,
    required this.phoneCtrl,
    this.cityCtrl,
    this.fallbackCity,
    this.fallbackCountry,
    required this.children,
    @visibleForTesting this.createBloc,
  });

  final RecipientSectionController controller;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController? cityCtrl;
  final String? fallbackCity;
  final String? fallbackCountry;
  final List<Widget> children;

  /// Override de test pour l'instanciation du bloc — par défaut `getIt`.
  @visibleForTesting
  final RecipientBloc Function()? createBloc;

  @override
  State<RecipientSection> createState() => _RecipientSectionState();
}

class _RecipientSectionState extends State<RecipientSection> {
  late final RecipientBloc _bloc;
  Recipient? _selected;
  bool _save = true;
  bool _suppressListener = false;

  static final _e164 = kRecipientPhoneE164;

  @override
  void initState() {
    super.initState();
    _bloc = (widget.createBloc ?? () => getIt<RecipientBloc>())()
      ..add(const RecipientLoaded());
    widget.controller._saveHook = _maybeSave;
    widget.nameCtrl.addListener(_onFieldChanged);
    widget.phoneCtrl.addListener(_onFieldChanged);
    widget.cityCtrl?.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.controller._saveHook = null;
    widget.nameCtrl.removeListener(_onFieldChanged);
    widget.phoneCtrl.removeListener(_onFieldChanged);
    widget.cityCtrl?.removeListener(_onFieldChanged);
    _bloc.close();
    super.dispose();
  }

  /// Toute modification manuelle d'un champ nom/téléphone invalide la
  /// sélection (retour à l'état 3). Éditer la ville seule n'invalide pas.
  void _onFieldChanged() {
    if (_suppressListener) {
      return;
    }
    if (_selected != null &&
        (widget.nameCtrl.text.trim() != _selected!.fullName ||
            widget.phoneCtrl.text.trim() != _selected!.phoneE164)) {
      setState(() => _selected = null);
    } else {
      setState(() {}); // met à jour la visibilité du toggle
    }
  }

  Future<void> _openPicker() async {
    final recipient = await RecipientPickerSheet.show(
      context,
      currentPhone: widget.phoneCtrl.text.trim(),
    );
    if (!mounted) {
      return;
    }
    // Toujours recharger, même si la sheet a été fermée sans confirmer :
    // l'utilisateur a pu y créer un destinataire puis l'avoir refermée sans
    // le sélectionner — la liste locale doit refléter ce nouvel enregistrement
    // (sinon le toggle « Enregistrer » resterait visible pour un numéro déjà
    // dans le carnet → doublon à la soumission).
    _bloc.add(const RecipientLoaded());
    if (recipient == null) {
      return;
    }
    _suppressListener = true;
    widget.nameCtrl.text = recipient.fullName;
    widget.phoneCtrl.text = recipient.phoneE164;
    widget.cityCtrl?.text = recipient.city ?? '';
    _suppressListener = false;
    setState(() => _selected = recipient);
  }

  bool get _phoneIsKnown => _bloc.state.recipients.any(
    (r) => r.phoneE164 == widget.phoneCtrl.text.trim(),
  );

  bool get _toggleVisible =>
      _selected == null &&
      _e164.hasMatch(widget.phoneCtrl.text.trim()) &&
      !_phoneIsKnown;

  void _maybeSave() {
    if (!_toggleVisible || !_save) {
      return;
    }
    final phone = widget.phoneCtrl.text.trim();
    final city = widget.cityCtrl?.text.trim();
    _bloc.add(
      RecipientCreated(
        fullName: widget.nameCtrl.text.trim(),
        phoneE164: phone,
        city: (city != null && city.isNotEmpty)
            ? city
            : (widget.fallbackCity ?? ''),
        country: widget.fallbackCountry ?? countryFromPhone(phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<RecipientBloc, RecipientState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selected != null)
                _SelectedCard(recipient: _selected!, onChange: _openPicker)
              else
                _PickerButton(onTap: _openPicker),
              const SizedBox(height: DonySpacing.md),
              ...widget.children,
              if (_toggleVisible) ...[
                const SizedBox(height: DonySpacing.sm),
                SwitchListTile.adaptive(
                  value: _save,
                  onChanged: (v) => setState(() => _save = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enregistrer ce destinataire'),
                  subtitle: const Text(
                    'Sera ajouté à « Mes destinataires » pour tes prochains envois',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              DonyIcon('contact', size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Choisir un destinataire',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              DonyIcon('chevron-right', size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.recipient, required this.onChange});
  final Recipient recipient;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = recipient.relationship?.isNotEmpty == true
        ? recipient.relationship!
        : recipient.fullName;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Row(
        children: [
          DonyAvatar(name: recipient.fullName, size: DonyAvatarSize.sm),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    recipient.fullName,
                    recipient.phoneE164,
                    if (recipient.city != null) recipient.city!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}
