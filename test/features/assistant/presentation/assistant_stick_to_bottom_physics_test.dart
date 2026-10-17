import 'package:dony/features/assistant/presentation/widgets/assistant_stick_to_bottom_physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FixedScrollMetrics _metrics({
  required double pixels,
  required double max,
  required double viewport,
}) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: max,
  pixels: pixels,
  viewportDimension: viewport,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 1,
);

void main() {
  const physics = AssistantStickToBottomPhysics();

  double adjust(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition, {
    bool isScrolling = false,
  }) => physics.adjustPositionForNewDimensions(
    oldPosition: oldPosition,
    newPosition: newPosition,
    isScrolling: isScrolling,
    velocity: 0,
  );

  test('applyTo garde la physique de la plateforme en parent', () {
    final applied = physics.applyTo(const BouncingScrollPhysics());
    expect(applied, isA<AssistantStickToBottomPhysics>());
    expect(applied.parent, isA<BouncingScrollPhysics>());
  });

  test('zone visible réduite au bas : recolle au nouveau bas', () {
    expect(
      adjust(
        _metrics(pixels: 1000, max: 1000, viewport: 500),
        _metrics(pixels: 1000, max: 1300, viewport: 200),
      ),
      1300,
    );
  });

  test('à quelques pixels du bas : considéré au bas', () {
    expect(
      adjust(
        _metrics(pixels: 990, max: 1000, viewport: 500),
        _metrics(pixels: 990, max: 1100, viewport: 400),
      ),
      1100,
    );
  });

  test('zone visible agrandie au bas : suit le bas sans dépasser', () {
    expect(
      adjust(
        _metrics(pixels: 1300, max: 1300, viewport: 200),
        _metrics(pixels: 1300, max: 1000, viewport: 500),
      ),
      1000,
    );
  });

  test('remonté pour lire : position inchangée', () {
    expect(
      adjust(
        _metrics(pixels: 600, max: 1000, viewport: 500),
        _metrics(pixels: 600, max: 1300, viewport: 200),
      ),
      600,
    );
  });

  test('défilement en cours : position inchangée', () {
    expect(
      adjust(
        _metrics(pixels: 1000, max: 1000, viewport: 500),
        _metrics(pixels: 1000, max: 1300, viewport: 200),
        isScrolling: true,
      ),
      1000,
    );
  });

  test('contenu ajouté sans changement de hauteur visible : pas touché', () {
    expect(
      adjust(
        _metrics(pixels: 1000, max: 1000, viewport: 500),
        _metrics(pixels: 1000, max: 1200, viewport: 500),
      ),
      1000,
    );
  });
}
