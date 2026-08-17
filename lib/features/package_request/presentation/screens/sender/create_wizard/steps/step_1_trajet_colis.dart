import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Étape 1 / 3 — Trajet & colis (Proposal B — Sahel Warmth).
class Step1TrajetColis extends StatefulWidget {
  const Step1TrajetColis({super.key, this.canContinueNotifier, this.header});

  /// Piloté par l'étape, lu par le bouton « Continuer » de la coque.
  final ValueNotifier<bool>? canContinueNotifier;

  /// Contenu posé en tête de la zone défilante (bannière de devise). Porté par
  /// l'étape plutôt que par la coque : au-dessus du `SingleChildScrollView`, il
  /// restait figé et mangeait de la hauteur pendant toute la saisie.
  final Widget? header;

  @override
  State<Step1TrajetColis> createState() => Step1TrajetColisState();
}

class Step1TrajetColisState extends State<Step1TrajetColis> {
  final _formKey = GlobalKey<FormState>();
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _date;
  int _tolerance = 2;
  final TransportMode _transportMode = TransportMode.plane;

  /// Les messages rouges n'apparaissent qu'après une première interaction :
  /// un formulaire vierge ne doit pas accueillir l'utilisateur par des
  /// reproches sur des champs qu'il n'a pas encore eu l'occasion de remplir.
  bool _touched = false;

  String? get _departureError =>
      _departureCity == null ? 'Ville de départ obligatoire' : null;

  String? get _arrivalError {
    if (_arrivalCity == null) return "Ville d'arrivée obligatoire";
    if (_arrivalCity == _departureCity) {
      return 'Choisissez une ville différente du départ';
    }
    return null;
  }

  String? get _dateError => _date == null ? 'Date de départ obligatoire' : null;

  bool get _isComplete =>
      _departureError == null && _arrivalError == null && _dateError == null;

  /// Recalcule l'état du bouton et, si l'utilisateur a déjà agi, les messages.
  void _sync({bool markTouched = false}) {
    if (markTouched) _touched = true;
    widget.canContinueNotifier?.value = _isComplete;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (mode édition ou retour à l'étape) depuis l'état du bloc.
    final PackageRequestFormState s = context
        .read<PackageRequestFormBloc>()
        .state;
    _departureCity = s.departureCity;
    _arrivalCity = s.arrivalCity;
    _date = s.desiredDate;
    if (s.dateToleranceDays != null) _tolerance = s.dateToleranceDays!;
    // Après la frame : la coque possède le notifier et est en train de builder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.canContinueNotifier?.value = _isComplete;
    });
  }

  /// Saisie locale non encore remontée au bloc.
  ///
  /// L'étape ne pousse son contenu qu'à `submit()` : sans cet accesseur, le
  /// garde-fou de sortie du wizard serait aveugle à une étape 1 en cours de
  /// remplissage et laisserait perdre la saisie sans rien demander.
  bool get hasUnsubmittedInput {
    final s = context.read<PackageRequestFormBloc>().state;
    return _departureCity != s.departureCity ||
        _arrivalCity != s.arrivalCity ||
        _date != s.desiredDate ||
        _tolerance != (s.dateToleranceDays ?? 2);
  }

  /// Formule la tolérance en dates concrètes plutôt qu'en nombre de jours.
  String _toleranceHint() {
    if (_tolerance == 0) {
      return 'Seuls les voyageurs partant exactement ce jour-là pourront répondre.';
    }
    if (_date == null) {
      return '± $_tolerance jours autour de votre date. Plus de souplesse, '
          'plus de voyageurs.';
    }
    final f = DateFormat('d MMM', 'fr_FR');
    final from = f.format(_date!.subtract(Duration(days: _tolerance)));
    final to = f.format(_date!.add(Duration(days: _tolerance)));
    return 'Les voyageurs partant du $from au $to pourront répondre.';
  }

  void _setDeparture(String? city) {
    _departureCity = city;
    _sync(markTouched: true);
  }

  void _setArrival(String? city) {
    _arrivalCity = city;
    _sync(markTouched: true);
  }

  void _swapCities() {
    final departure = _departureCity;
    _departureCity = _arrivalCity;
    _arrivalCity = departure;
    _sync(markTouched: true);
  }

  void submit() {
    // Backstop : « Continuer » est déjà grisé tant que l'étape est incomplète.
    // On révèle quand même les messages, au cas où ce chemin redeviendrait
    // atteignable.
    if (!_formKey.currentState!.validate() || !_isComplete) {
      _sync(markTouched: true);
      return;
    }
    context.read<PackageRequestFormBloc>().add(
      FormStep1Submitted(
        departureCity: _departureCity!,
        arrivalCity: _arrivalCity!,
        desiredDate: _date!,
        dateToleranceDays: _tolerance,
        transportMode: _transportMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: DonySpacing.base),
            ],

            // ── Section label ──────────────────────────────────────────────
            Text(
              'TRAJET',
              style: tt.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              "D'où vers où ?",
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: DonySpacing.lg),

            // ── Corridor départ → arrivée ──────────────────────────────────
            // Carte « billet » partagée avec la recherche et « Publier un
            // trajet » : un seul rendu du corridor dans toute l'app.
            CityCorridorFields(
              departureValue: _departureCity,
              arrivalValue: _arrivalCity,
              departureFieldKey: const Key('step1-departure-city'),
              arrivalFieldKey: const Key('step1-arrival-city'),
              departureError: _touched ? _departureError : null,
              arrivalError: _touched ? _arrivalError : null,
              onSwap: _swapCities,
              onDepartureSelected: (city) => _setDeparture(city.name),
              onDepartureCleared: () => _setDeparture(null),
              onArrivalSelected: (city) => _setArrival(city.name),
              onArrivalCleared: () => _setArrival(null),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Date + Tolérance row ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Date'),
                      const SizedBox(height: DonySpacing.xs),
                      _DatePickerField(
                        date: _date,
                        onChanged: (d) {
                          _date = d;
                          _sync(markTouched: true);
                        },
                        errorText: _touched ? _dateError : null,
                      ),
                      // ── Feedback informatif « sera signalée urgente » ──
                      // Non-bloquant : n'affecte jamais la soumission.
                      if (_date != null && isUrgentDate(_date!))
                        Padding(
                          padding: const EdgeInsets.only(top: DonySpacing.xs),
                          child: Text(
                            '🔥 Date proche, cette demande sera signalée urgente',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Souplesse'),
                      const SizedBox(height: DonySpacing.xs),
                      _ToleranceField(
                        tolerance: _tolerance,
                        onChanged: (t) {
                          _tolerance = t;
                          _sync(markTouched: true);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // La tolérance est un réglage dont l'effet n'est pas devinable :
            // on dit ce qu'elle change pour l'utilisateur, pas ce qu'elle est.
            Padding(
              padding: const EdgeInsets.only(top: DonySpacing.xs),
              child: Text(
                _toleranceHint(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Mode de transport — Avion verrouillé ───────────────────────
            const _LockedAirplaneBlock(),
          ],
        ),
      ),
    );
  }
}

// ─── Locked Airplane Block ────────────────────────────────────────────────────

class _LockedAirplaneBlock extends StatelessWidget {
  const _LockedAirplaneBlock();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          DonyIcon('plane', size: 22, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avion',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'seul mode disponible',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          DonyIcon('lock', size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.date,
    required this.onChanged,
    this.errorText,
  });
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dateText = date == null
        ? 'Date'
        : DateFormat('d MMM. y', 'fr_FR').format(date!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.md + 2,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: errorText != null ? cs.error : cs.outline,
              ),
            ),
            child: Row(
              children: [
                const Text('📆', style: TextStyle(fontSize: 14)),
                const SizedBox(width: DonySpacing.xs),
                Flexible(
                  child: Text(
                    dateText,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      color: date == null ? cs.onSurfaceVariant : cs.onSurface,
                      fontWeight: date == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DonyFieldError(message: errorText, textKey: const Key('date-error')),
      ],
    );
  }
}

class _ToleranceField extends StatelessWidget {
  const _ToleranceField({required this.tolerance, required this.onChanged});
  final int tolerance;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.outline),
        ),
        child: Text(
          '± $tolerance j',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in [0, 1, 2, 3, 5, 7])
                ListTile(
                  title: Text(
                    t == 0 ? 'Date exacte' : '± $t ${t > 1 ? "jours" : "jour"}',
                  ),
                  trailing: t == tolerance
                      ? DonyIcon(
                          'check',
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    onChanged(t);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bouton sélectionnable pill — emoji/icône + label.
/// Sélectionné : bg terracotta + texte blanc. Repos : blanc + bord neutral.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base - 2,
          vertical: DonySpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(color: selected ? cs.primary : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 14))
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            const SizedBox(width: DonySpacing.xs + 2),
            Text(
              label,
              style: tt.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
