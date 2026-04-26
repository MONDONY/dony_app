import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_avatar.dart';
import 'package:dony/core/design/widgets/dony_badge.dart';
import 'package:dony/core/design/widgets/dony_card.dart';
import 'package:dony/core/design/widgets/dony_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DonyTextField', () {
    testWidgets('renders TextFormField', (tester) async {
      await tester.pumpWidget(_wrap(const DonyTextField(hint: 'Enter text')));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(_wrap(const DonyTextField(label: 'Email')));
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('calls onChanged on input', (tester) async {
      String? changed;
      await tester.pumpWidget(_wrap(DonyTextField(onChanged: (v) => changed = v)));
      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changed, 'hello');
    });
  });

  group('DonyCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(_wrap(const DonyCard(child: Text('Card content'))));
      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('adds InkWell when onTap provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DonyCard(onTap: () => tapped = true, child: const Text('Tap me')),
      ));
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('no InkWell when no onTap', (tester) async {
      await tester.pumpWidget(_wrap(const DonyCard(child: Text('No tap'))));
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('DonyBadge', () {
    testWidgets('renders label in uppercase', (tester) async {
      await tester.pumpWidget(_wrap(const DonyBadge(label: 'active')));
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyBadge(label: 'test', icon: Icons.check),
      ));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('info type is default', (tester) async {
      await tester.pumpWidget(_wrap(const DonyBadge(label: 'test')));
      expect(find.byType(DonyBadge), findsOneWidget);
    });
  });

  group('DonyAvatar', () {
    testWidgets('shows initials when no imageUrl', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(initials: 'Ibrahima')));
      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('sm size has radius 16', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(size: DonyAvatarSize.sm)));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 16.0);
    });

    testWidgets('md size has radius 22', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(size: DonyAvatarSize.md)));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 22.0);
    });

    testWidgets('lg size has radius 28', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(size: DonyAvatarSize.lg)));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 28.0);
    });

    testWidgets('shows question mark when no initials', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar()));
      expect(find.text('?'), findsOneWidget);
    });
  });
}