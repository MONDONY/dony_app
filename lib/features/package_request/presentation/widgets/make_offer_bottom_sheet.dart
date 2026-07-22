import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MakeOfferBottomSheet {
  const MakeOfferBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String packageRequestId,
    double? targetPriceEur,
    required double weightKg,
    required String departureCity,
    required String arrivalCity,
    DateTime? initialDate,
    bool isFirmPrice = false,
  }) async {
    PriceEstimate? estimate;
    try {
      estimate = await getIt<PriceEstimationRepository>().estimate(
        from: departureCity,
        to: arrivalCity,
        weight: weightKg,
      );
    } catch (_) {
      // estimate optional
    }

    if (!context.mounted) return;

    // Capture root references BEFORE the sheet opens — using `ctx` from
    // inside the listener after pop() would touch a disposed subtree.
    final rootRouter = GoRouter.of(context);

    VoidCallback? submitFn;
    // Sortie protégée : la croix de la feuille et, faute de mieux, le
    // glissement, doivent repasser par la confirmation d'abandon.
    Future<void> Function()? exitFn;

    await DonyBottomSheet.show<void>(
      context,
      title: isFirmPrice ? 'Prendre ce colis' : 'Faire une offre',
      // Le glissement vers le bas et le tap sur le fond appellent
      // `Navigator.pop()` sans consulter `PopScope` (vérifié sur Flutter
      // 3.44) : ils contourneraient la confirmation. On les désactive et on
      // laisse la croix, qui elle passe par `onCloseRequested`.
      enableDrag: false,
      isDismissible: false,
      onCloseRequested: () => exitFn?.call(),
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<NegotiationBloc>(),
        child: child,
      ),
      child: _MakeOfferContent(
        packageRequestId: packageRequestId,
        targetPriceEur: targetPriceEur,
        weightKg: weightKg,
        estimate: estimate,
        rootRouter: rootRouter,
        onSubmitReady: (fn) => submitFn = fn,
        onExitReady: (fn) => exitFn = fn,
        initialDate: initialDate,
        isFirmPrice: isFirmPrice,
      ),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        builder: (ctx, state) {
          final loading = state is NegotiationLoading;
          final String label;
          if (loading) {
            label = 'Envoi…';
          } else if (isFirmPrice) {
            label = targetPriceEur != null
                ? 'Prendre à ${PriceDisplay.eur(targetPriceEur)}'
                : 'Prendre ce colis';
          } else {
            label = 'Envoyer l\'offre';
          }
          return DonyButton(
            label: label,
            isLoading: loading,
            onPressed: loading ? null : () => submitFn?.call(),
          );
        },
      ),
    );
  }
}

class _MakeOfferContent extends StatefulWidget {
  const _MakeOfferContent({
    required this.packageRequestId,
    required this.targetPriceEur,
    required this.weightKg,
    required this.estimate,
    required this.rootRouter,
    required this.onSubmitReady,
    required this.onExitReady,
    this.initialDate,
    this.isFirmPrice = false,
  });

  final String packageRequestId;
  final double? targetPriceEur;
  final double weightKg;
  final PriceEstimate? estimate;
  final GoRouter rootRouter;
  final void Function(VoidCallback) onSubmitReady;

  /// Remonte au parent la routine de sortie protégée, pour que la croix de la
  /// feuille l'emprunte au lieu de popper directement.
  final void Function(Future<void> Function()) onExitReady;
  final DateTime? initialDate;
  final bool isFirmPrice;

  @override
  State<_MakeOfferContent> createState() => _MakeOfferContentState();
}

class _MakeOfferContentState extends State<_MakeOfferContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _kgCtrl;
  late final TextEditingController _bodyCtrl;
  final _dateNotifier = ValueNotifier<DateTime?>(null);

  /// Signature de la saisie à l'ouverture, pour ne demander confirmation de
  /// sortie que si l'utilisateur a modifié quelque chose. Les champs sont
  /// pré-remplis (prix cible, poids), d'où la comparaison plutôt qu'un simple
  /// test de non-vacuité.
  String? _initialSignature;

  /// Évite d'empiler deux dialogues sur retours système répétés.
  bool _confirmingExit = false;

  String get _formSignature => [
        _priceCtrl.text,
        _kgCtrl.text,
        _bodyCtrl.text,
        _dateNotifier.value,
      ].join('|');

  /// Saleté observable : `PopScope.canPop` est lu au build, or taper dans un
  /// `TextFormField` ne provoque aucun rebuild. Sans ce notifier, le garde-fou
  /// resterait figé sur sa valeur d'ouverture et se contournerait tout seul.
  final _isDirtyNotifier = ValueNotifier<bool>(false);

  bool get _isDirty => _isDirtyNotifier.value;

  void _recomputeDirty() {
    _isDirtyNotifier.value =
        _initialSignature != null && _formSignature != _initialSignature;
  }

  Future<void> _handleExitRequest() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed = await DonyDialog.confirmDiscard(context);
    _confirmingExit = false;
    if (!mounted || confirmed != true) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
    widget.onExitReady(_handleExitRequest);
    _priceCtrl = TextEditingController(
      text: widget.targetPriceEur != null
          // Prix ferme : valeur EXACTE (pas d'arrondi) — sinon le backend
          // rejette avec negotiation/firm-price-must-match.
          ? widget.targetPriceEur!.toStringAsFixed(widget.isFirmPrice ? 2 : 0)
          : '',
    );
    _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(1));
    _bodyCtrl = TextEditingController();
    if (widget.initialDate != null) _dateNotifier.value = widget.initialDate;

    _priceCtrl.addListener(_recomputeDirty);
    _kgCtrl.addListener(_recomputeDirty);
    _bodyCtrl.addListener(_recomputeDirty);
    _dateNotifier.addListener(_recomputeDirty);

    // Après le premier build : les champs pré-remplis font partie de la
    // référence, pas d'une saisie utilisateur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initialSignature = _formSignature;
        _recomputeDirty();
      });
    });
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_recomputeDirty);
    _kgCtrl.removeListener(_recomputeDirty);
    _bodyCtrl.removeListener(_recomputeDirty);
    _dateNotifier.removeListener(_recomputeDirty);
    _priceCtrl.dispose();
    _kgCtrl.dispose();
    _bodyCtrl.dispose();
    _dateNotifier.dispose();
    _isDirtyNotifier.dispose();
    super.dispose();
  }

  DateTime _clampDate(DateTime d) {
    final now = DateTime.now();
    final last = now.add(const Duration(days: 90));
    if (d.isBefore(now)) return now;
    if (d.isAfter(last)) return last;
    return d;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateNotifier.value == null) {
      DonySnackbar.show(
        context,
        message: 'Sélectionnez votre date de voyage',
        type: DonySnackbarType.warning,
      );
      return;
    }
    context.read<NegotiationBloc>().add(NegotiationStartRequested(
          packageRequestId: widget.packageRequestId,
          // Prix ferme : on envoie la valeur exacte (le champ est verrouillé),
          // jamais le texte arrondi → match garanti côté backend.
          proposedPriceEur: widget.isFirmPrice && widget.targetPriceEur != null
              ? widget.targetPriceEur!
              : double.parse(_priceCtrl.text.replaceAll(',', '.')),
          travelerTravelDate: _dateNotifier.value!,
          travelerAvailableKg:
              double.parse(_kgCtrl.text.replaceAll(',', '.')),
          body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          isFirmPrice: widget.isFirmPrice,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final estimate = widget.estimate;
    return ValueListenableBuilder<bool>(
      valueListenable: _isDirtyNotifier,
      builder: (context, isDirty, child) => PopScope(
        // Feuille modale : bloque le retour système et le glissement vers le
        // bas tant qu'il y a de la saisie, pour repasser par la confirmation.
        canPop: !isDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_handleExitRequest());
        },
        child: child!,
      ),
      child: BlocListener<NegotiationBloc, NegotiationState>(
      listener: (ctx, state) {
        if (state is NegotiationLoaded) {
          DonySnackbar.show(
            ctx,
            message: 'Offre envoyée',
            type: DonySnackbarType.success,
          );
          Navigator.of(ctx, rootNavigator: true).pop();
          widget.rootRouter.push('/negotiations/${state.thread.id}');
        } else if (state is NegotiationError) {
          ErrorPresenter.show(ctx, state.error);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner estimation ─────────────────────────────────────────
            if (estimate != null && estimate.lowEur != null) ...[
              _EstimationBanner(estimate: estimate),
              const SizedBox(height: DonySpacing.base),
            ],

            // ── Prix + Capacité (2 colonnes) ──────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldTile(
                      label: widget.isFirmPrice ? 'PRIX FERME' : 'VOTRE PRIX',
                      iconAsset: widget.isFirmPrice ? 'lock' : 'banknote',
                      iconBgKey: _TileColor.blue,
                      suffix: '€',
                      child: TextFormField(
                        controller: _priceCtrl,
                        // Prix ferme : non négociable → champ verrouillé.
                        readOnly: widget.isFirmPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]')),
                        ],
                        style: _fieldTextStyle(context),
                        decoration: _fieldDecoration(context),
                        validator: (v) {
                          final d = double.tryParse(
                              (v ?? '').replaceAll(',', '.'));
                          if (d == null) return 'Invalide';
                          if (d <= 0 || d > 500) return '0–500 €';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: _FieldTile(
                      label: 'CAPACITÉ',
                      iconAsset: 'scale',
                      iconBgKey: _TileColor.green,
                      suffix: 'kg',
                      child: TextFormField(
                        controller: _kgCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]')),
                        ],
                        style: _fieldTextStyle(context),
                        decoration: _fieldDecoration(context),
                        validator: (v) {
                          final d = double.tryParse(
                              (v ?? '').replaceAll(',', '.'));
                          if (d == null || d <= 0) return '> 0 kg';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.md),

            // ── Date ──────────────────────────────────────────────────────
            ValueListenableBuilder<DateTime?>(
              valueListenable: _dateNotifier,
              builder: (ctx, date, _) => _FieldTile(
                label: 'DATE DE VOYAGE',
                iconAsset: 'calendar',
                iconBgKey: _TileColor.amber,
                suffix: null,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: _clampDate(
                          date ?? DateTime.now().add(const Duration(days: 7))),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 90)),
                    );
                    if (picked != null) _dateNotifier.value = picked;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            date == null
                                ? 'Sélectionner…'
                                : DateFormat('EEE d MMM yyyy', 'fr')
                                    .format(date),
                            style: _fieldTextStyle(context).copyWith(
                              color: date == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        DonyIcon(
                          'chevron-right',
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.md),

            // ── Message ───────────────────────────────────────────────────
            _FieldTile(
              label: 'MESSAGE',
              iconAsset: 'message-circle',
              iconBgKey: _TileColor.violet,
              suffix: null,
              sublabel: 'optionnel',
              alignIconTop: true,
              child: TextFormField(
                controller: _bodyCtrl,
                maxLines: 3,
                maxLength: 280,
                style: _fieldTextStyle(context),
                decoration: _fieldDecoration(context).copyWith(
                  hintText: 'Je voyage exactement ce jour-là…',
                  counterStyle: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  static TextStyle _fieldTextStyle(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return tt.bodyLarge!.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static InputDecoration _fieldDecoration(BuildContext context) {
    return const InputDecoration(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 2),
      errorStyle: TextStyle(fontSize: 11),
    );
  }
}

// ─── Estimation banner ────────────────────────────────────────────────────────

class _EstimationBanner extends StatelessWidget {
  const _EstimationBanner({required this.estimate});
  final PriceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final confidenceColor = switch (estimate.confidence.wireName.toLowerCase()) {
      'high' => cs.success,
      'medium' => cs.warning,
      _ => cs.primary,
    };
    final confidenceBg = switch (estimate.confidence.wireName.toLowerCase()) {
      'high' => cs.successLight,
      'medium' => cs.warningLight,
      _ => cs.primaryContainer,
    };

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
            color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: DonyIcon('trending-up',
                color: cs.primary, size: 18),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prix du marché',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${estimate.lowEur!.toStringAsFixed(0)} – ${estimate.highEur!.toStringAsFixed(0)} €',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
            decoration: BoxDecoration(
              color: confidenceBg,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              estimate.confidence.wireName.toLowerCase(),
              style: tt.labelSmall?.copyWith(
                color: confidenceColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field tile ──────────────────────────────────────────────────────────────

enum _TileColor { blue, green, amber, violet }

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.iconAsset,
    required this.iconBgKey,
    required this.child,
    this.suffix,
    this.sublabel,
    this.alignIconTop = false,
  });

  final String label;
  final String iconAsset;
  final _TileColor iconBgKey;
  final Widget child;
  final String? suffix;
  final String? sublabel;
  final bool alignIconTop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (iconBg, iconColor) = switch (iconBgKey) {
      _TileColor.blue => (cs.primaryContainer, cs.primary),
      _TileColor.green => (cs.successLight, cs.success),
      _TileColor.amber => (DonyColors.amberLight, DonyColors.amberDark),
      _TileColor.violet => (DonyColors.violetLight, DonyColors.violet),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(width: DonySpacing.xs),
              Text(
                '· $sublabel',
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // ── Tile ──────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: Row(
            crossAxisAlignment: alignIconTop
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              // Icon square
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.sm,
                  alignIconTop ? DonySpacing.sm + 2 : DonySpacing.sm,
                  0,
                  DonySpacing.sm,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: DonyIcon(iconAsset, size: 18, color: iconColor),
                ),
              ),
              // Input
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm),
                  child: child,
                ),
              ),
              // Suffix
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: DonySpacing.base),
                  child: Text(
                    suffix!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
