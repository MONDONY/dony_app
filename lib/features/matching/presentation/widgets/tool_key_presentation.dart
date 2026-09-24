import 'package:dony/features/matching/data/models/tools_completion_model.dart';

/// Seule déclaration des routes par outil (spec § 4.5). Les libellés, CTA et
/// badges vivent désormais dans `activity_labels.dart` (traduits).
extension ToolKeyPresentation on ToolKey {
  String get route => switch (this) {
    ToolKey.addresses => '/profile/addresses',
    ToolKey.recipients => '/profile/recipients',
    ToolKey.alerts => '/corridor-alerts',
    ToolKey.tripTemplates => '/trip-templates',
    ToolKey.priceGrid => '/profile/price-grid',
  };
}
