import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_refraction_surface/liquid_refraction_surface.dart';
import 'package:liquid_refraction_surface/src/liquid_displacement_field.dart';

void main() {
  test('liquid refraction config supports stable copyWith updates', () {
    const config = LiquidRefractionConfig(
      metalness: 0.35,
      roughness: 0.45,
      displacementScale: 2.0,
      chromaticAberration: 0.0,
      enableAutoDrops: false,
    );

    final updated = config.copyWith(
      displacementScale: 3.5,
      enableAutoDrops: true,
    );

    expect(updated.metalness, 0.35);
    expect(updated.roughness, 0.45);
    expect(updated.displacementScale, 3.5);
    expect(updated.enableAutoDrops, isTrue);
  });

  testWidgets('liquid refraction surface keeps child in widget tree', (
    WidgetTester tester,
  ) async {
    const targetKey = ValueKey<String>('liquid-refraction-child');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 240,
          child: LiquidRefractionSurface(
            backgroundColor: Color(0xFFF5F5F5),
            child: ColoredBox(key: targetKey, color: Color(0xFF111111)),
          ),
        ),
      ),
    );

    expect(find.byType(LiquidRefractionSurface), findsOneWidget);
    expect(find.byKey(targetKey), findsOneWidget);
  });

  testWidgets('unsupported platform shows explicit error message', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 240,
          child: LiquidRefractionSurface(
            backgroundColor: Color(0xFFF5F5F5),
            child: ColoredBox(color: Color(0xFF111111)),
          ),
        ),
      ),
    );

    expect(
      find.text('Liquid refraction is unsupported on this platform'),
      findsOneWidget,
    );
    expect(
      find.text(
        'This effect requires the mobile shader pipeline and currently supports only iOS and Android.',
      ),
      findsOneWidget,
    );

    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  test('continuous displacement field responds to injected impulse', () {
    final field = LiquidDisplacementField(
      cellSize: 18,
      stiffness: 0.11,
      damping: 0.95,
    )..resize(const Size(240, 160));

    final before = field.sample(const Offset(120, 80));
    expect(before.offset, Offset.zero);
    expect(before.energy, 0);

    field.addImpulse(const Offset(120, 80), radius: 48, strength: 0.6);
    field.update(1 / 60);

    final after = field.sample(const Offset(120, 80));
    expect(field.hasActivity, isTrue);
    expect(after.energy, greaterThan(0));
    expect(after.speed, greaterThan(0));
  });

  test('drag trail injects energy across the movement path', () {
    final field = LiquidDisplacementField(
      cellSize: 18,
      stiffness: 0.11,
      damping: 0.95,
    )..resize(const Size(320, 180));

    field.addImpulseTrail(
      const Offset(60, 90),
      const Offset(220, 90),
      radius: 42,
      strength: 0.52,
    );
    field.update(1 / 60);

    final midpoint = field.sample(const Offset(140, 90));
    final endpoint = field.sample(const Offset(220, 90));

    expect(midpoint.energy, greaterThan(0));
    expect(endpoint.energy, greaterThan(0));
    expect(midpoint.speed, greaterThan(0));
  });
}
