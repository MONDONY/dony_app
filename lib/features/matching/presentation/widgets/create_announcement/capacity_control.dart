import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/matching/presentation/widgets/item_size_selector.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Contrôle de capacité : chips single-select (DonyChip) + corps adapté par mode.
///
/// - Presets valise (23/32 kg) : compteur ±, plafonné à la capacité du mode.
///   Absents en route (C27) : la route n'a que « Kg libre » et « Personnalisé ».
/// - Kg libre : carte info statique (inchangé).
/// - Personnalisé : kilos entiers, de 1 à `TripCapacityLimits.maxKgFor(mode)`
///   (999 en avion, 999 999 en route) ; au-delà, erreur sous le champ.
/// - Route : sous la capacité, la taille max d'un colis (facultative, C24) et
///   le poids max par colis (facultatif, de 0,5 kg à la capacité, D19).
///
/// `StatefulWidget` requis pour :
///   - les `TextEditingController` des kilos et du poids max par colis (créés
///     en initState, disposés en dispose, jamais dans un `whenComplete`) ;
///   - la synchronisation contrôleurs ↔ état BLoC lors d'un changement venu
///     d'ailleurs (unité, changement de mode, brouillon).
class CapacityControl extends StatefulWidget {
  const CapacityControl({super.key});

  @override
  State<CapacityControl> createState() => _CapacityControlState();
}

class _CapacityControlState extends State<CapacityControl> {
  late final TextEditingController _customKgController;
  late final TextEditingController _maxWeightController;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AnnouncementFormBloc>();
    final initialKg = bloc.state.availableKg;
    _customKgController = TextEditingController(
      text: initialKg != null && initialKg >= 1
          ? initialKg.toInt().toString()
          : '',
    );
    _maxWeightController = TextEditingController(
      text: _weightText(bloc.state.maxParcelWeightKg),
    );
  }

  @override
  void dispose() {
    _customKgController.dispose();
    _maxWeightController.dispose();
    super.dispose();
  }

  /// Texte du champ de poids max, sans séparateur de milliers (saisie).
  static String _weightText(double? kg) =>
      kg == null ? '' : formatWeightValue('en', kg);

  /// Poids saisi (virgule ou point), `null` si vide ou illisible.
  static double? parseMaxParcelWeight(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
          listenWhen: (prev, curr) => prev.capacityUnit != curr.capacityUnit,
          listener: (context, state) {
            // Mode Personnalisé uniquement : pré-remplir le champ avec la
            // valeur courante du bloc (ou vider si null/invalide).
            // kgFree n'a plus de champ de saisie — pas de sync nécessaire.
            if (state.capacityUnit == CapacityUnit.custom) {
              final kg = state.availableKg;
              final text = kg != null && kg >= 1 ? kg.toInt().toString() : '';
              if (_customKgController.text != text) {
                _customKgController.text = text;
              }
            }
          },
        ),
        // Poids max effacé ou posé d'ailleurs (passage en avion, brouillon) :
        // le champ suit, sans réécrire une saisie en cours équivalente.
        BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
          listenWhen: (prev, curr) =>
              prev.maxParcelWeightKg != curr.maxParcelWeightKg,
          listener: (context, state) {
            final typed = parseMaxParcelWeight(_maxWeightController.text);
            if (typed == state.maxParcelWeightKg) return;
            _maxWeightController.text = _weightText(state.maxParcelWeightKg);
          },
        ),
      ],
      child: BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
        buildWhen: (prev, curr) =>
            prev.capacityUnit != curr.capacityUnit ||
            prev.availableKg != curr.availableKg ||
            prev.transportMode != curr.transportMode ||
            prev.maxItemSize != curr.maxItemSize ||
            prev.maxParcelWeightKg != curr.maxParcelWeightKg,
        builder: (context, state) {
          final tt = Theme.of(context).textTheme;
          final l = context.l10n;
          final mode = transportModeOrPlane(state.transportMode);
          final units = CapacityUnit.values
              .where((u) => mode.allowsSuitcases || u.maxKg == null)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.tripPublishCapacityAvailableLabel, style: tt.titleMedium),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: units.map((unit) {
                  return DonyChip(
                    label: unit.label(l),
                    selected: state.capacityUnit == unit,
                    onTap: () => context.read<AnnouncementFormBloc>().add(
                      CapacityUnitChanged(unit),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: DonySpacing.md),
              _buildBody(context, state, mode),
              if (mode.hasItemSize) ...[
                const SizedBox(height: DonySpacing.lg),
                _RoadParcelLimits(
                  state: state,
                  weightController: _maxWeightController,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AnnouncementFormState state,
    TransportMode mode,
  ) {
    switch (state.capacityUnit) {
      case CapacityUnit.suitcase23kg:
      case CapacityUnit.suitcase32kg:
        return _SuitcaseStepperCard(state: state);
      case CapacityUnit.kgFree:
        // Capacité illimitée — pas de saisie de poids. La valeur sentinelle
        // (1.0) est fixée automatiquement par le BLoC.
        return const _KgFreeInfoCard();
      case CapacityUnit.custom:
        return _CustomKgCard(
          controller: _customKgController,
          isRoad: mode.isRoad,
          error: state.capacityTooHigh
              ? context.l10n.tripPublishCapacityTooHigh(
                  formatWeightKg(context.l10n, state.capacityMaxKg.toDouble()),
                )
              : null,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route : taille max d'un colis et poids max par colis, facultatifs
// ─────────────────────────────────────────────────────────────────────────────

class _RoadParcelLimits extends StatelessWidget {
  const _RoadParcelLimits({
    required this.state,
    required this.weightController,
  });

  final AnnouncementFormState state;
  final TextEditingController weightController;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final bloc = context.read<AnnouncementFormBloc>();
    return Column(
      key: const Key('capacity-road-limits'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.tripPublishMaxItemSizeLabel, style: tt.titleSmall),
        const SizedBox(height: DonySpacing.sm),
        ItemSizeSelector(
          sizes: ItemSize.values,
          selected: state.maxItemSize,
          onChanged: (size) => bloc.add(MaxItemSizeChanged(size)),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyTextField(
          key: const Key('max-parcel-weight-field'),
          controller: weightController,
          label: l.tripPublishMaxParcelWeightLabel,
          prefixIcon: Icons.inventory_2_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]\d{0,2})?')),
          ],
          onChanged: (value) => bloc.add(
            MaxParcelWeightChanged(
              _CapacityControlState.parseMaxParcelWeight(value),
            ),
          ),
        ),
        DonyFieldError(
          message: state.isMaxParcelWeightValid
              ? null
              : l.tripPublishMaxParcelWeightInvalid,
          textKey: const Key('max-parcel-weight-error'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte valise avec compteur ±
// ─────────────────────────────────────────────────────────────────────────────

class _SuitcaseStepperCard extends StatelessWidget {
  const _SuitcaseStepperCard({required this.state});

  final AnnouncementFormState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final unitKg = state.capacityUnit.maxKg!;
    final totalKg = state.availableKg ?? unitKg;
    final quantite = ((totalKg / unitKg).round()).clamp(1, 999999);
    final totalDisplay = (quantite * unitKg).toInt();
    final canAdd = (quantite + 1) * unitKg <= state.capacityMaxKg;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne icône + titre total
          Row(
            children: [
              Icon(DonyIcons.suitcase, color: cs.primary, size: 24),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tripPublishYouOfferKg(totalDisplay),
                      style: tt.titleMedium,
                    ),
                    Text(
                      l.tripPublishSuitcaseCount(quantite, unitKg.toInt()),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          // Compteur ±
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton −
              _StepperButton(
                icon: DonyIcons.minus,
                enabled: quantite > 1,
                semanticLabel: l.tripPublishDecreaseQuantityTooltip,
                onPressed: quantite > 1
                    ? () => context.read<AnnouncementFormBloc>().add(
                        AvailableKgChanged((quantite - 1) * unitKg),
                      )
                    : null,
              ),
              // Affichage quantité
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                child: Text(
                  '$quantite',
                  style: tt.headlineMedium?.copyWith(color: cs.primary),
                ),
              ),
              // Bouton +
              // Plafond du mode : 43 valises de 23 kg, pas 44 (999 kg).
              _StepperButton(
                icon: DonyIcons.add,
                enabled: canAdd,
                semanticLabel: l.tripPublishIncreaseQuantityTooltip,
                onPressed: canAdd
                    ? () => context.read<AnnouncementFormBloc>().add(
                        AvailableKgChanged((quantite + 1) * unitKg),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: IconButton.styleFrom(
          backgroundColor: enabled
              ? cs.primary.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte Kg libre — info statique, pas de saisie
// ─────────────────────────────────────────────────────────────────────────────

class _KgFreeInfoCard extends StatelessWidget {
  const _KgFreeInfoCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('infinity', color: cs.primary),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.tripPublishUnlimitedCapacityTitle,
                  style: tt.titleMedium?.copyWith(color: cs.primary),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.tripPublishUnlimitedCapacitySubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte personnalisé — saisie libre
// ─────────────────────────────────────────────────────────────────────────────

class _CustomKgCard extends StatelessWidget {
  const _CustomKgCard({
    required this.controller,
    required this.isRoad,
    required this.error,
  });

  final TextEditingController controller;

  /// Route : pas d'icône de valise.
  final bool isRoad;

  /// Capacité au-delà du plafond du mode, `null` sinon.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyTextField(
            key: const Key('capacity-kg-field'),
            controller: controller,
            label: l.tripPublishCapacityKgFieldLabel,
            prefixIcon: isRoad ? Icons.inventory_2_rounded : DonyIcons.suitcase,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              // Au-delà du plafond, la valeur part quand même : l'étape
              // l'affiche en erreur et grise « Continuer », plutôt que de
              // publier en silence l'ancienne capacité.
              if (parsed != null && parsed >= 1) {
                context.read<AnnouncementFormBloc>().add(
                  AvailableKgChanged(parsed.toDouble()),
                );
              }
            },
          ),
          DonyFieldError(
            message: error,
            textKey: const Key('capacity-kg-error'),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripPublishCapacityKgFieldHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
