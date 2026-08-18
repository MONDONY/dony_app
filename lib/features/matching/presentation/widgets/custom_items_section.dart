import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter/material.dart';

/// Article hors grille en cours de saisie.
///
/// L'expéditeur le décrit ET le chiffre lui-même : c'est ce que le voyageur
/// n'a jamais tarifé, donc la raison d'être de la négociation. Le montant est
/// un prix total pour une unité, la quantité le multiplie.
class BidCustomItemDraft {
  BidCustomItemDraft({
    required this.label,
    required this.quantity,
    required this.amountEur,
  });

  final String label;
  final int quantity;
  final double amountEur;

  double get totalEur => amountEur * quantity;

  Map<String, dynamic> toJson() => {
    'label': label,
    'quantity': quantity,
    'amountEur': amountEur,
  };
}

/// Somme des articles hors grille, quantités comprises.
double customItemsTotalEur(List<BidCustomItemDraft> items) =>
    items.fold<double>(0, (sum, item) => sum + item.totalEur);

/// Section « Articles hors grille » du formulaire de proposition.
///
/// Vit dans son propre fichier : `create_bid_bottom_sheet.dart` dépasse déjà
/// les 2 200 lignes. Le [notifier] appartient à l'écran parent, qui le crée et
/// le dispose, comme les autres notifiers du formulaire.
class CustomItemsSection extends StatelessWidget {
  const CustomItemsSection({
    super.key,
    required this.notifier,
    required this.currencyCode,
  });

  final ValueNotifier<List<BidCustomItemDraft>> notifier;

  /// Devise du trajet négocié, figée à sa publication. Les montants saisis ici
  /// s'ajoutent au prix du voyageur : les afficher en euro sur un trajet en
  /// franc CFA annoncerait un prix que personne ne paiera.
  final String currencyCode;

  void _add(BidCustomItemDraft draft) {
    notifier.value = [...notifier.value, draft];
  }

  void _removeAt(int index) {
    final next = [...notifier.value]..removeAt(index);
    notifier.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ValueListenableBuilder<List<BidCustomItemDraft>>(
      valueListenable: notifier,
      builder: (context, items, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles hors grille',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Ajoutez ce que le voyageur n\'a pas tarifé, et proposez votre prix pour chaque article.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.md),
            if (items.isEmpty)
              Container(
                key: const Key('custom-items-empty'),
                width: double.infinity,
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  'Aucun article pour le moment.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              ...List.generate(
                items.length,
                (i) => _CustomItemRow(
                  key: Key('custom-item-row-$i'),
                  index: i,
                  item: items[i],
                  currencyCode: currencyCode,
                  onRemove: () => _removeAt(i),
                ),
              ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total des articles hors grille',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    formatPriceIn(customItemsTotalEur(items), currencyCode),
                    key: const Key('custom-items-total'),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('custom-item-add'),
              label: 'Ajouter un article',
              variant: DonyButtonVariant.secondary,
              icon: Icons.add_rounded,
              onPressed: () => _showAddSheet(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final draft = await CustomItemFormSheet.show(
      context,
      currencyCode: currencyCode,
    );
    if (draft != null) _add(draft);
  }
}

class _CustomItemRow extends StatelessWidget {
  const _CustomItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.currencyCode,
    required this.onRemove,
  });

  final int index;
  final BidCustomItemDraft item;
  final String currencyCode;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: DonySpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.sm,
        DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  '${item.quantity} × ${formatPriceIn(item.amountEur, currencyCode)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            formatPriceIn(item.totalEur, currencyCode),
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            key: Key('custom-item-remove-$index'),
            onPressed: onRemove,
            tooltip: 'Retirer cet article',
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulaire d'ajout d'un article hors grille.
///
/// Le `DonyButton` de validation vit dans `stickyBottom`, jamais dans le
/// `child` scrollable. Les `TextEditingController` appartiennent au contenu
/// et non à `show()` : les champs sont encore reconstruits pendant l'animation
/// de fermeture, un dispose en `whenComplete` les leur retirerait trop tôt.
/// Seul le `ValueNotifier` du bouton, jamais réabonné, se dispose là.
abstract final class CustomItemFormSheet {
  static Future<BidCustomItemDraft?> show(
    BuildContext context, {
    required String currencyCode,
  }) {
    final submitNotifier = ValueNotifier<VoidCallback?>(null);

    return DonyBottomSheet.show<BidCustomItemDraft>(
      context,
      title: 'Ajouter un article',
      subtitle:
          'Décrivez l\'article et indiquez le prix que vous proposez pour son transport.',
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submitNotifier,
        builder: (_, submit, _) => DonyButton(
          key: const Key('custom-item-submit'),
          label: 'Ajouter',
          onPressed: submit,
        ),
      ),
      child: _CustomItemForm(
        currencyCode: currencyCode,
        onSubmitReady: (fn) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => submitNotifier.value = fn,
        ),
      ),
    ).whenComplete(submitNotifier.dispose);
  }
}

class _CustomItemForm extends StatefulWidget {
  const _CustomItemForm({
    required this.currencyCode,
    required this.onSubmitReady,
  });

  final String currencyCode;
  final void Function(VoidCallback?) onSubmitReady;

  @override
  State<_CustomItemForm> createState() => _CustomItemFormState();
}

class _CustomItemFormState extends State<_CustomItemForm> {
  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl.addListener(_validate);
    _amountCtrl.addListener(_validate);
    _quantityCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  /// Un article n'est ajoutable qu'avec un libellé ET un montant : sans prix,
  /// le voyageur n'aurait rien à accepter ou refuser.
  BidCustomItemDraft? _read() {
    final label = _labelCtrl.text.trim();
    final amount = parsePriceInput(_amountCtrl.text);
    final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    if (label.isEmpty || amount == null || quantity < 1) return null;
    return BidCustomItemDraft(
      label: label,
      quantity: quantity,
      amountEur: amount,
    );
  }

  void _validate() {
    final isValid = _read() != null;
    if (isValid == _valid) return;
    _valid = isValid;
    widget.onSubmitReady(isValid ? _submit : null);
  }

  void _submit() {
    final draft = _read();
    if (draft == null) return;
    Navigator.of(context, rootNavigator: true).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('custom-item-label'),
          controller: _labelCtrl,
          label: 'Article',
          hint: 'Sac de riz, boubou, médicaments',
          requiredLabel: true,
        ),
        const SizedBox(height: DonySpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DonyTextField(
                key: const Key('custom-item-quantity'),
                controller: _quantityCtrl,
                label: 'Quantité',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: DonyTextField(
                key: const Key('custom-item-amount'),
                controller: _amountCtrl,
                label:
                    'Prix (${SupportedCurrency.symbolOf(widget.currencyCode)})',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                requiredLabel: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
