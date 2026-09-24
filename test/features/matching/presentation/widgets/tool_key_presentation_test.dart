import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/tool_key_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes des cinq outils', () {
    expect(ToolKey.addresses.route, '/profile/addresses');
    expect(ToolKey.recipients.route, '/profile/recipients');
    expect(ToolKey.alerts.route, '/corridor-alerts');
    expect(ToolKey.tripTemplates.route, '/trip-templates');
    expect(ToolKey.priceGrid.route, '/profile/price-grid');
  });
}
