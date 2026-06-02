import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet pour créer ou modifier un article de la grille de prix.
///
/// Règle CLAUDE.md : le [DonyButton] est toujours dans [stickyBottom],
/// jamais dans le [child] scrollable.
abstract final class PriceGridItemFormSheet {
  static Future<void> show(
    BuildContext context, {
    PriceGridItemModel? item,
  }) {
    final bloc = context.read<PriceGridBloc>();
    final isValid = ValueNotifier<bool>(false);
    VoidCallback? submitFn;

    return DonyBottomSheet.show<void>(
      context,
      title: item == null ? 'Ajouter un article' : 'Modifier l\'article',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: isValid,
        builder: (context, valid, child) => DonyButton(
          label: item == null ? 'Ajouter' : 'Enregistrer',
          onPressed: valid ? () => submitFn?.call() : null,
        ),
      ),
      child: _PriceGridItemFormContent(
        item: item,
        onValidityChanged: (v) => isValid.value = v,
        onSubmitReady: (fn) => submitFn = fn,
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => isValid.dispose());
    });
  }
}

// ── Form content ─────────────────────────────────────────────────────────────

class _PriceGridItemFormContent extends StatefulWidget {
  const _PriceGridItemFormContent({
    required this.item,
    required this.onValidityChanged,
    required this.onSubmitReady,
  });

  final PriceGridItemModel? item;
  final ValueChanged<bool> onValidityChanged;
  final ValueChanged<VoidCallback> onSubmitReady;

  @override
  State<_PriceGridItemFormContent> createState() =>
      _PriceGridItemFormContentState();
}

class _PriceGridItemFormContentState
    extends State<_PriceGridItemFormContent> {
  late final TextEditingController _labelController;
  late final TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();

  // Cached parsed price for the hint preview
  double? _parsedPrice;

  @override
  void initState() {
    super.initState();
    _labelController =
        TextEditingController(text: widget.item?.label ?? '');
    _priceController = TextEditingController(
      text: widget.item != null
          ? widget.item!.unitPriceNet.toStringAsFixed(2)
          : '',
    );

    // Update parsed price on init if editing
    if (widget.item != null) {
      _parsedPrice = widget.item!.unitPriceNet;
    }

    // Register submit callback immediately so stickyBottom can call it
    widget.onSubmitReady(_handleSubmit);

    // Emit initial validity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateValidity();
    });

    _labelController.addListener(_updateValidity);
    // _updateParsedPrice calls _updateValidity internally — no separate listener needed
    _priceController.addListener(_updateParsedPrice);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _updateValidity() {
    final labelOk = _labelController.text.trim().isNotEmpty;
    final priceOk =
        _parsedPrice != null && _parsedPrice! > 0 && _parsedPrice! <= 500;
    widget.onValidityChanged(labelOk && priceOk);
  }

  void _updateParsedPrice() {
    final raw = _priceController.text.trim().replaceAll(',', '.');
    _parsedPrice = double.tryParse(raw);
    _updateValidity();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final label = _labelController.text.trim();
    final price = _parsedPrice;
    if (price == null) {
      return;
    }
    final bloc = context.read<PriceGridBloc>();

    if (widget.item == null) {
      bloc.add(PriceGridItemAddRequested(label: label, unitPriceNet: price));
    } else {
      bloc.add(PriceGridItemUpdateRequested(
        itemId: widget.item!.id,
        label: label,
        unitPriceNet: price,
      ));
    }

    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label field
          DonyTextField(
            controller: _labelController,
            label: 'Article',
            hint: 'Ex : Téléphone, Vêtements, Chaussures…',
            prefixIcon: Icons.label_outline_rounded,
            keyboardType: TextInputType.text,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Le nom est requis';
              }
              if (v.trim().length > 100) {
                return 'Maximum 100 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: DonySpacing.base),

          // Price field
          DonyTextField(
            controller: _priceController,
            label: 'Prix net (€)',
            hint: 'Ex : 10.00',
            prefixIcon: Icons.euro_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Le prix est requis';
              }
              final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
              if (parsed == null) {
                return 'Entrez un nombre valide';
              }
              if (parsed <= 0) {
                return 'Le prix doit être positif';
              }
              if (parsed > 500) {
                return 'Maximum 500 € par article';
              }
              return null;
            },
          ),
          const SizedBox(height: DonySpacing.sm),

          // Realtime hint: display price for sender
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _parsedPrice != null && _parsedPrice! > 0
                ? Container(
                    key: const ValueKey('hint-visible'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                      vertical: DonySpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Expanded(
                          child: Text(
                            'L\'expéditeur verra '
                            '${netToSenderPrice(_parsedPrice!).toStringAsFixed(2)} € '
                            '(+${(donyCommissionRate * 100).toStringAsFixed(0)} % Dony)',
                            style: tt.bodySmall?.copyWith(color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('hint-hidden')),
          ),
          const SizedBox(height: DonySpacing.base),
        ],
      ),
    );
  }
}
