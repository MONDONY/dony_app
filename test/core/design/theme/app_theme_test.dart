import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme', () {
    testWidgets('light has Brightness.light', (tester) async {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    testWidgets('dark has Brightness.dark', (tester) async {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    testWidgets('light vs dark have different surfaces', (tester) async {
      expect(
        AppTheme.light.colorScheme.surface,
        isNot(AppTheme.dark.colorScheme.surface),
      );
    });

    testWidgets('dark uses recalibrated primary blue', (tester) async {
      expect(AppTheme.dark.colorScheme.primary, DonyColors.blueDark500);
      expect(AppTheme.light.colorScheme.primary, DonyColors.primary);
    });

    testWidgets('dark scaffold background is neutralDark0', (tester) async {
      expect(AppTheme.dark.scaffoldBackgroundColor, DonyColors.neutralDark0);
    });

    testWidgets('dark text color uses neutralDark700', (tester) async {
      expect(AppTheme.dark.colorScheme.onSurface, DonyColors.neutralDark700);
    });
  });
}
