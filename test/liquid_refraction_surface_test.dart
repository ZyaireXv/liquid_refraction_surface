import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      rainIntensity: LiquidRainIntensity.light,
    );

    final updated = config.copyWith(
      displacementScale: 3.5,
      enableAutoDrops: true,
      rainIntensity: LiquidRainIntensity.heavy,
      rainDropCount: 4,
    );
    final reset = updated.copyWith(rainDropCount: null);

    expect(updated.metalness, 0.35);
    expect(updated.roughness, 0.45);
    expect(updated.displacementScale, 3.5);
    expect(updated.enableAutoDrops, isTrue);
    expect(updated.rainIntensity, LiquidRainIntensity.heavy);
    expect(updated.rainDropCount, 4);
    expect(reset.rainDropCount, isNull);
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

  testWidgets('background mode keeps child interaction available', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 240,
          child: LiquidRefractionSurface(
            placement: LiquidRefractionPlacement.background,
            backdrop: const ColoredBox(color: Color(0xFFEAF2FF)),
            child: Center(
              child: FilledButton(
                onPressed: () {
                  tapCount++;
                },
                child: const Text('Tap'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tap'), warnIfMissed: false);
    await tester.pump();

    expect(tapCount, 1);
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

  test('raindrop injection creates ripple energy away from the center', () {
    final field = LiquidDisplacementField(
      cellSize: 18,
      stiffness: 0.11,
      damping: 0.95,
    )..resize(const Size(320, 220));

    field.addRaindrop(
      const Offset(160, 110),
      radius: 28,
      strength: 0.3,
      rippleCount: 3,
      travelFactor: 1.6,
    );

    for (var frame = 0; frame < 4; frame++) {
      field.update(1 / 60);
    }

    final nearRing = field.sample(const Offset(188, 110));
    final farRing = field.sample(const Offset(214, 110));

    expect(nearRing.energy, greaterThan(0));
    expect(farRing.energy, greaterThan(0));
  });

  test('field activity naturally decays after enough updates', () {
    final field = LiquidDisplacementField(
      cellSize: 18,
      stiffness: 0.11,
      damping: 0.95,
    )..resize(const Size(240, 160));

    field.addImpulse(const Offset(120, 80), radius: 40, strength: 0.35);
    expect(field.hasActivity, isTrue);

    for (var frame = 0; frame < 360; frame++) {
      field.update(1 / 60);
    }

    expect(field.hasActivity, isFalse);
  });

  test('resize resets previous field state', () {
    final field = LiquidDisplacementField(
      cellSize: 18,
      stiffness: 0.11,
      damping: 0.95,
    )..resize(const Size(240, 160));

    field.addImpulse(const Offset(120, 80), radius: 40, strength: 0.35);
    field.update(1 / 60);
    expect(field.sample(const Offset(120, 80)).energy, greaterThan(0));

    field.resize(const Size(360, 220));

    final afterResize = field.sample(const Offset(120, 80));
    expect(field.columns, greaterThan(0));
    expect(field.rows, greaterThan(0));
    expect(field.hasActivity, isFalse);
    expect(afterResize.energy, 0);
    expect(afterResize.offset, Offset.zero);
  });
}
