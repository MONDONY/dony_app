abstract class PriceGridEvent {
  const PriceGridEvent();
}

class LoadPriceGrid extends PriceGridEvent {
  const LoadPriceGrid();
}

class AddPriceGridItem extends PriceGridEvent {
  final String label;
  final double unitPriceNet;
  const AddPriceGridItem({required this.label, required this.unitPriceNet});
}

class UpdatePriceGridItem extends PriceGridEvent {
  final String itemId;
  final String label;
  final double unitPriceNet;
  const UpdatePriceGridItem({
    required this.itemId,
    required this.label,
    required this.unitPriceNet,
  });
}

class DeletePriceGridItem extends PriceGridEvent {
  final String itemId;
  const DeletePriceGridItem(this.itemId);
}

class ReorderPriceGridItems extends PriceGridEvent {
  final List<String> orderedIds;
  const ReorderPriceGridItems(this.orderedIds);
}
