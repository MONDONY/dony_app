import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TripTemplateEditScreen extends StatefulWidget {
  const TripTemplateEditScreen({super.key, this.template});

  final TripTemplate? template;

  @override
  State<TripTemplateEditScreen> createState() => _TripTemplateEditScreenState();
}

class _TripTemplateEditScreenState extends State<TripTemplateEditScreen> {
  static const _totalSteps = 3;
  static const _handoverChoices = <(int?, String)>[
    (null, 'Aucun'),
    (0, 'Le jour même'),
    (1, '1 jour avant'),
    (2, '2 jours avant'),
    (3, '3 jours avant'),
    (7, '7 jours avant'),
  ];

  late final TripFormFields _fields;
  final _labelCtrl = TextEditingController();
  final _step = ValueNotifier<int>(0);
  final _handoverLeadDays = ValueNotifier<int?>(null);
  final _canContinue = ValueNotifier<bool>(false);
  bool _submitted = false;

  bool get _isEditing => widget.template != null;

  @visibleForTesting
  int? get handoverLeadDaysForTest => _handoverLeadDays.value;
  @visibleForTesting
  TripFormFields get fieldsForTest => _fields;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _fields = TripFormFields(
      initialCurrency:
          SupportedCurrency.fromCode(t?.currency) ??
          ActiveCurrency.current ??
          SupportedCurrency.eur,
    );
    _fields.transportMode.value = TransportMode.plane;
    if (t != null) _prefill(t);
    _labelCtrl.addListener(_recomputeCanContinue);
    _fields.departureCity.addListener(_recomputeCanContinue);
    _fields.arrivalCity.addListener(_recomputeCanContinue);
    _fields.transportMode.addListener(_recomputeCanContinue);
    _step.addListener(_recomputeCanContinue);
    _recomputeCanContinue();
  }

  void _prefill(TripTemplate t) {
    _labelCtrl.text = t.label;
    _fields.departureCity.value = t.departureCity;
    _fields.arrivalCity.value = t.arrivalCity;
    _fields.departureCountryCode.value = t.departureCountryCode;
    _fields.arrivalCountryCode.value = t.arrivalCountryCode;
    _fields.transportMode.value =
        transportModeFromWire(t.transportMode) ?? TransportMode.plane;
    _fields.departureTime.value = _timeOfDay(t.departureTime);
    _fields.arrivalTime.value = _timeOfDay(t.arrivalTime);
    _handoverLeadDays.value = t.handoverLeadDays;
    // Étape 1 et 2 : Tâche 4 (_prefillConditions).
  }

  static TimeOfDay? _timeOfDay(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _wire(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Étape 0 : nom, villes et transport. Étapes 1 et 2 : voir Tâche 4.
  void _recomputeCanContinue() {
    final step0Ok =
        _labelCtrl.text.trim().isNotEmpty &&
        (_fields.departureCity.value?.trim().isNotEmpty ?? false) &&
        (_fields.arrivalCity.value?.trim().isNotEmpty ?? false) &&
        _fields.transportMode.value != null;
    _canContinue.value = switch (_step.value) {
      0 => step0Ok,
      // Étape 1 (Lieux & capacité) : formulaire pas encore branché
      // (Tâche 4), « Continuer » reste actif tant qu'il n'y a rien à
      // valider.
      1 => true,
      // Étape 2 (Prix & conditions) : « Enregistrer le modèle » reste
      // désactivé tant que la Tâche 4 n'a pas branché la validation du prix.
      _ => false,
    };
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _step.dispose();
    _handoverLeadDays.dispose();
    _canContinue.dispose();
    _fields.dispose();
    super.dispose();
  }

  /// Payload envoyé au bloc. Seuls les champs de l'étape 0 sont renseignés
  /// pour l'instant ; les étapes 1 et 2 (lieux/capacité, prix/conditions)
  /// sont complétées en Tâche 4.
  Map<String, dynamic> _buildPayload(BuildContext context) => {
    'label': _labelCtrl.text.trim(),
    'departureCity': _fields.departureCity.value?.trim(),
    'arrivalCity': _fields.arrivalCity.value?.trim(),
    'departureCountryCode': _fields.departureCountryCode.value,
    'arrivalCountryCode': _fields.arrivalCountryCode.value,
    'transportMode': transportModeToWire(
      _fields.transportMode.value ?? TransportMode.plane,
    ),
    'departureTime': _wire(_fields.departureTime.value),
    'arrivalTime': _wire(_fields.arrivalTime.value),
    'handoverLeadDays': _handoverLeadDays.value,
    'currency': _fields.currency.value.code,
  };

  void _submit(BuildContext context) {
    _submitted = true;
    final data = _buildPayload(context);
    final bloc = context.read<TripTemplateBloc>();
    if (_isEditing) {
      bloc.add(TripTemplateUpdated(widget.template!.id, data));
    } else {
      bloc.add(TripTemplateCreated(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripTemplateBloc, TripTemplateState>(
      listener: (context, state) {
        if (_submitted && state.status == TripTemplateStatus.success) {
          DonySnackbar.show(
            context,
            message: _isEditing ? 'Modèle mis à jour' : 'Modèle enregistré',
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == TripTemplateStatus.error && state.error != null) {
          _submitted = false;
          DonySnackbar.show(
            context,
            message: state.error!,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == TripTemplateStatus.loading;
        // Un seul ValueListenableBuilder sur `_step` pour tout l'écran :
        // PopScope.canPop doit se recalculer au changement d'étape, pas
        // seulement au changement d'état du bloc.
        return ValueListenableBuilder<int>(
          valueListenable: _step,
          builder: (context, step, _) {
            // Un seul handler de retour, partagé par la flèche visible de
            // l'AppBar (`onBack`) et par `PopScope` (geste système / swipe
            // iOS) : sans ça, `DonyAppBarBackButton` appelle `context.pop()`
            // directement sans consulter `canPop` et fait quitter l'écran au
            // lieu de reculer d'une étape (cf. `create_trip_screen.dart`,
            // même pattern avec `_handleExitRequest`).
            void handleBack() {
              if (step == 0) {
                context.pop();
              } else {
                _step.value = step - 1;
              }
            }

            return PopScope(
              canPop: step == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) {
                  handleBack();
                }
              },
              child: DonyPageScaffold(
                title: _isEditing ? 'Modifier le modèle' : 'Nouveau modèle',
                onBack: handleBack,
                stickyBottom: ValueListenableBuilder<bool>(
                  valueListenable: _canContinue,
                  builder: (context, canContinue, _) {
                    final enabled = canContinue && !isLoading;
                    return DonyButton(
                      label: step < 2 ? 'Continuer' : 'Enregistrer le modèle',
                      onPressed: enabled
                          ? (step < 2
                                ? () => _step.value = step + 1
                                : () => _submit(context))
                          : null,
                      isLoading: isLoading,
                    );
                  },
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CaStepperHeader(currentStep: step, totalSteps: _totalSteps),
                    const SizedBox(height: DonySpacing.xxl),
                    ...switch (step) {
                      0 => _buildStep0(context),
                      1 => _buildStep1(context),
                      _ => _buildStep2(context),
                    },
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildStep0(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return [
      // ── NOM DU MODÈLE ───────────────────────────────────────────
      const _SectionLabel(label: 'NOM DU MODÈLE', iconAsset: 'bookmark'),
      const SizedBox(height: DonySpacing.sm),
      DonyTextField(
        controller: _labelCtrl,
        label: 'Nom',
        hint: 'Ex : Mon Paris → Dakar',
        prefixWidget: DonyIcon('tag', size: 20, color: cs.onSurfaceVariant),
      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
      const SizedBox(height: DonySpacing.xxl),

      // ── TRAJET ──────────────────────────────────────────────────
      const _SectionLabel(label: 'TRAJET', iconAsset: 'plane-takeoff'),
      const SizedBox(height: DonySpacing.sm),
      ListenableBuilder(
        listenable: Listenable.merge([
          _fields.departureCity,
          _fields.arrivalCity,
        ]),
        builder: (context, _) => CityCorridorFields(
          departureValue: _fields.departureCity.value,
          arrivalValue: _fields.arrivalCity.value,
          departureFieldKey: const Key('trip-template-departure-city'),
          arrivalFieldKey: const Key('trip-template-arrival-city'),
          requiredLabels: true,
          onDepartureSelected: (city) {
            _fields.departureCity.value = city.name;
            _fields.departureCountryCode.value = city.countryCode;
          },
          onArrivalSelected: (city) {
            _fields.arrivalCity.value = city.name;
            _fields.arrivalCountryCode.value = city.countryCode;
          },
          onDepartureCleared: () {
            _fields.departureCity.value = null;
            _fields.departureCountryCode.value = null;
          },
          onArrivalCleared: () {
            _fields.arrivalCity.value = null;
            _fields.arrivalCountryCode.value = null;
          },
          onSwap: () {
            final city = _fields.departureCity.value;
            _fields.departureCity.value = _fields.arrivalCity.value;
            _fields.arrivalCity.value = city;
            final code = _fields.departureCountryCode.value;
            _fields.departureCountryCode.value =
                _fields.arrivalCountryCode.value;
            _fields.arrivalCountryCode.value = code;
          },
        ),
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODE DE TRANSPORT ───────────────────────────────────────
      const _SectionLabel(label: 'MODE DE TRANSPORT', iconAsset: 'route'),
      const SizedBox(height: DonySpacing.sm),
      ListenableBuilder(
        listenable: _fields.transportMode,
        builder: (context, _) => Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final mode in TransportMode.values)
              DonyChip(
                label: mode.label,
                icon: mode.icon,
                selected: _fields.transportMode.value == mode,
                onTap: () => _fields.transportMode.value = mode,
              ),
          ],
        ),
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── HORAIRES ─────────────────────────────────────────────────
      const _SectionLabel(label: 'HORAIRES', iconAsset: 'clock'),
      const SizedBox(height: DonySpacing.sm),
      _TimeRow(
        icon: 'plane-takeoff',
        label: 'Heure de départ',
        time: _fields.departureTime,
      ),
      const SizedBox(height: DonySpacing.sm),
      _TimeRow(
        icon: 'plane-landing',
        label: "Heure d'arrivée",
        time: _fields.arrivalTime,
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── DÉLAI DE REMISE ─────────────────────────────────────────
      const _SectionLabel(label: 'DÉLAI DE REMISE', iconAsset: 'timer'),
      const SizedBox(height: DonySpacing.sm),
      Text(
        'Au plus tard combien de jours avant le départ le colis doit être '
        'remis ?',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: DonySpacing.sm),
      ValueListenableBuilder<int?>(
        valueListenable: _handoverLeadDays,
        builder: (context, selected, _) => Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final choice in _handoverChoices)
              DonyChip(
                label: choice.$2,
                selected: _handoverLeadDays.value == choice.$1,
                onTap: () => _handoverLeadDays.value = choice.$1,
              ),
          ],
        ),
      ),
      const SizedBox(height: DonySpacing.md),
    ];
  }

  /// Lieux & capacité — branché en Tâche 4.
  List<Widget> _buildStep1(BuildContext context) => const [SizedBox.shrink()];

  /// Prix & conditions — branché en Tâche 4.
  List<Widget> _buildStep2(BuildContext context) => const [SizedBox.shrink()];
}

/// Rangée d'heure éditable (départ ou arrivée) — reprend le rendu de
/// l'ancienne section HEURE D'ARRIVÉE : un seul texte qui bascule entre le
/// placeholder et la valeur formatée, avec un bouton d'effacement quand une
/// heure est choisie.
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.icon, required this.label, required this.time});

  final String icon;
  final String label;
  final ValueNotifier<TimeOfDay?> time;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<TimeOfDay?>(
      valueListenable: time,
      builder: (context, value, _) {
        final wire = value == null
            ? null
            : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        return GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value ?? const TimeOfDay(hour: 12, minute: 0),
            );
            if (picked != null) time.value = picked;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              children: [
                DonyIcon(icon, color: cs.primary, size: 20),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    wire ?? '$label (optionnel)',
                    style: tt.bodyMedium?.copyWith(
                      color: wire == null ? cs.onSurfaceVariant : cs.onSurface,
                      fontWeight: wire == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (wire != null)
                  Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: 'Effacer $label',
                    child: GestureDetector(
                      onTap: () => time.value = null,
                      child: DonyIcon(
                        'x',
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
