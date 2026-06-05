import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet « Ouvrir les kg restants » : depuis un trajet dédié dont la
/// négociation est payée ([AnnouncementModel.canOpenSurplus]), le voyageur
/// déclare une capacité supplémentaire (kg) et un prix/kg libre, puis publie
/// cette capacité au public.
///
/// Le `DonyButton` « Publier » vit dans `stickyBottom` (règle absolue), gardé
/// par un `ValueNotifier<bool>` de validité (kg ≥ 1 ET prix > 0) et enveloppé
/// dans un `BlocBuilder` pour l'état de chargement.
abstract final class OpenSurplusBottomSheet {
  /// Ouvre la feuille. Retourne `true` si le surplus a été ouvert avec succès
  /// (le détail parent peut alors être rechargé), `null`/`false` sinon.
  static Future<bool?> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    // Validité du formulaire — pilote l'activation du bouton sticky.
    final canSubmit = ValueNotifier<bool>(false);
    VoidCallback? submitFn;

    return DonyBottomSheet.show<bool>(
      context,
      title: 'Ouvrir les kg restants',
      subtitle: 'Mettez votre capacité libre à disposition du public',
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<AnnouncementBloc>(),
        child: child,
      ),
      stickyBottom: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          final loading = state is AnnouncementLoading;
          return ValueListenableBuilder<bool>(
            valueListenable: canSubmit,
            builder: (context, valid, _) => DonyButton(
              label: loading ? 'Publication…' : 'Publier',
              icon: loading ? null : Icons.public_rounded,
              isLoading: loading,
              onPressed: (valid && !loading) ? () => submitFn?.call() : null,
            ),
          );
        },
      ),
      child: _OpenSurplusContent(
        announcement: announcement,
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submitFn = fn,
      ),
    ).whenComplete(canSubmit.dispose);
  }
}

class _OpenSurplusContent extends StatefulWidget {
  const _OpenSurplusContent({
    required this.announcement,
    required this.canSubmit,
    required this.onSubmitReady,
  });

  final AnnouncementModel announcement;
  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_OpenSurplusContent> createState() => _OpenSurplusContentState();
}

class _OpenSurplusContentState extends State<_OpenSurplusContent> {
  final _formKey = GlobalKey<FormState>();
  final _kgCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();

  /// Index du chip prix sélectionné. `kPriceOptions.length` = « Autre ».
  final _priceOptionNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
    _kgCtrl.addListener(_recomputeValidity);
    _customPriceCtrl.addListener(_recomputeValidity);
    _priceOptionNotifier.addListener(_recomputeValidity);
  }

  @override
  void dispose() {
    _kgCtrl.dispose();
    _customPriceCtrl.dispose();
    _priceOptionNotifier.dispose();
    super.dispose();
  }

  bool get _isCustomPrice =>
      _priceOptionNotifier.value == kPriceOptions.length;

  double get _pricePerKg => _isCustomPrice
      ? (double.tryParse(_customPriceCtrl.text.replaceAll(',', '.')) ?? 0)
      : kPriceOptions[
          _priceOptionNotifier.value.clamp(0, kPriceOptions.length - 1)];

  double get _surplusKg =>
      double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0;

  void _recomputeValidity() {
    final valid = _surplusKg >= 1 && _pricePerKg > 0;
    if (widget.canSubmit.value != valid) {
      widget.canSubmit.value = valid;
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!widget.canSubmit.value) {
      return;
    }
    context.read<AnnouncementBloc>().add(AnnouncementSurplusOpenRequested(
          announcementId: widget.announcement.id,
          surplusKg: _surplusKg,
          pricePerKg: _pricePerKg,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final a = widget.announcement;

    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementSurplusOpened) {
          DonySnackbar.show(
            context,
            message: 'Capacité ouverte au public',
            type: DonySnackbarType.success,
          );
          Navigator.of(context, rootNavigator: true).pop(true);
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Contexte : capacité réservée + caractère public ────────────
            _ReservedBanner(reservedKg: a.reservedKg)
                .animate()
                .fadeIn(duration: 250.ms),
            const SizedBox(height: DonySpacing.lg),

            // ── Capacité supplémentaire ────────────────────────────────────
            const _SectionLabel(label: 'KG À OUVRIR', icon: Icons.add_box_outlined),
            const SizedBox(height: DonySpacing.sm),
            _KgField(
              controller: _kgCtrl,
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (d == null) {
                  return 'Entrez un nombre de kg';
                }
                if (d < 1) {
                  return 'Minimum 1 kg';
                }
                return null;
              },
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.lg),

            // ── Prix par kg (chips preset + autre) ─────────────────────────
            const _SectionLabel(label: 'PRIX PAR KG', icon: Icons.sell_rounded),
            const SizedBox(height: DonySpacing.sm),
            ValueListenableBuilder<int>(
              valueListenable: _priceOptionNotifier,
              builder: (context, selectedIdx, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ...List.generate(kPriceOptions.length, (i) {
                          final selected = selectedIdx == i;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i < kPriceOptions.length
                                    ? DonySpacing.xs
                                    : 0,
                              ),
                              child: _PriceChip(
                                key: Key('surplus-price-chip-$i'),
                                label:
                                    '${kPriceOptions[i].toStringAsFixed(0)}€',
                                selected: selected,
                                onTap: () => _priceOptionNotifier.value = i,
                              ),
                            ),
                          );
                        }),
                        Expanded(
                          child: _PriceChip(
                            key: const Key('surplus-price-chip-custom'),
                            label: 'Autre',
                            selected: _isCustomPrice,
                            onTap: () => _priceOptionNotifier.value =
                                kPriceOptions.length,
                          ),
                        ),
                      ],
                    ),
                    if (_isCustomPrice) ...[
                      const SizedBox(height: DonySpacing.sm),
                      _CustomPriceField(controller: _customPriceCtrl),
                    ],
                  ],
                );
              },
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.lg),

            // ── Aperçu prix public (net → expéditeur) ──────────────────────
            // Recalcul sans setState : on écoute prix preset/custom via le
            // notifier d'option + le contrôleur de prix libre.
            ListenableBuilder(
              listenable: Listenable.merge([
                _priceOptionNotifier,
                _customPriceCtrl,
              ]),
              builder: (context, _) => _PublicPricePreview(
                netPricePerKg: _pricePerKg,
                senderPricePerKg: netToSenderPrice(_pricePerKg),
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Action définitive : une fois publiée, votre capacité libre '
              'devient visible dans la recherche et ne peut plus être refermée.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sous-widgets ──────────────────────────────────────────────────────────────

class _ReservedBanner extends StatelessWidget {
  const _ReservedBanner({required this.reservedKg});
  final double reservedKg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
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
            child: Icon(Icons.lock_outline_rounded, color: cs.primary, size: 18),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réservé à votre expéditeur',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reservedKg.toStringAsFixed(reservedKg % 1 == 0 ? 0 : 1)} kg verrouillés',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _KgField extends StatelessWidget {
  const _KgField({required this.controller, required this.validator});
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: TextFormField(
        key: const Key('surplus-kg-field'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
        ],
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: tt.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: 'Ex. 8',
          suffixText: 'kg',
          suffixStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

class _CustomPriceField extends StatelessWidget {
  const _CustomPriceField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: TextFormField(
        key: const Key('surplus-custom-price-field'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
        ],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) {
          final d = double.tryParse((v ?? '').replaceAll(',', '.'));
          if (d == null || d <= 0) {
            return 'Prix invalide';
          }
          return null;
        },
        style: tt.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: 'Votre prix',
          suffixText: '€/kg',
          suffixStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = selected ? cs.primaryContainer : cs.surface;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    final border = selected ? cs.primary : cs.outline;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DonyDuration.micro,
        curve: DonyCurve.easeOut,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DonyRadius.xl),
          border: Border.all(color: border, width: selected ? 1.5 : 1.0),
        ),
        child: Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PublicPricePreview extends StatelessWidget {
  const _PublicPricePreview({
    required this.netPricePerKg,
    required this.senderPricePerKg,
  });

  final double netPricePerKg;
  final double senderPricePerKg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasPrice = netPricePerKg > 0;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Prix affiché aux expéditeurs',
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
          Text(
            hasPrice
                ? '${senderPricePerKg.toStringAsFixed(senderPricePerKg % 1 == 0 ? 0 : 1)} €/kg'
                : '—',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.success,
            ),
          ),
        ],
      ),
    );
  }
}
