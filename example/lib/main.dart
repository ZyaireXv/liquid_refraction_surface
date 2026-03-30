import 'package:flutter/material.dart';
import 'package:liquid_refraction_surface/liquid_refraction_surface.dart';

enum _DemoBackdropMode { text, image }

enum _SurfacePreset { water, liquidGlass }

void main() {
  runApp(const LiquidRefractionExampleApp());
}

class LiquidRefractionExampleApp extends StatelessWidget {
  const LiquidRefractionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Refraction Surface',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF88A8D8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LiquidRefractionDemoPage(),
    );
  }
}

class LiquidRefractionDemoPage extends StatefulWidget {
  const LiquidRefractionDemoPage({super.key});

  @override
  State<LiquidRefractionDemoPage> createState() =>
      _LiquidRefractionDemoPageState();
}

class _LiquidRefractionDemoPageState extends State<LiquidRefractionDemoPage> {
  static const AssetImage _demoImage = AssetImage('assets/image.jpg');

  _DemoBackdropMode _backdropMode = _DemoBackdropMode.text;
  _SurfacePreset _preset = _SurfacePreset.water;
  double _metalness = 0.12;
  double _roughness = 0.16;
  double _displacementScale = 1.72;
  double _cellSize = 16.0;
  double _highlightOpacity = 0.2;
  double _chromaticAberration = 0.08;
  bool _autoDrops = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_preset);
  }

  @override
  Widget build(BuildContext context) {
    final config = LiquidRefractionConfig(
      metalness: _metalness,
      roughness: _roughness,
      displacementScale: _displacementScale,
      cellSize: _cellSize,
      highlightOpacity: _highlightOpacity,
      chromaticAberration: _chromaticAberration,
      enableAutoDrops: _autoDrops,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          LiquidRefractionSurface(
            backgroundColor: _backdropMode == _DemoBackdropMode.text
                ? const Color(0xFFF4F6FA)
                : null,
            backgroundImage: _backdropMode == _DemoBackdropMode.image
                ? _demoImage
                : null,
            config: config,
            child: _buildStage(),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB8141B2A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Text(
                  _backdropMode == _DemoBackdropMode.text
                      ? 'Move, drag, or tap to disturb the surface'
                      : 'Image mode helps inspect refraction and trailing glints',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 14),
              child: Align(
                alignment: Alignment.topRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xB8141B2A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: IconButton(
                    key: const ValueKey<String>('open-settings-button'),
                    onPressed: _openSettingsSheet,
                    icon: const Icon(Icons.tune_rounded, color: Colors.white),
                    tooltip: 'Open surface settings',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    return switch (_backdropMode) {
      _DemoBackdropMode.text => _buildTextStage(),
      _DemoBackdropMode.image => _buildImageStage(),
    };
  }

  Widget _buildTextStage() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFF6F8FD),
            Color(0xFFF0F3F9),
            Color(0xFFE7ECF5),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -60,
            left: -40,
            child: _buildGlow(size: 240, color: const Color(0x66B9CCF6)),
          ),
          Positioned(
            right: -30,
            bottom: 100,
            child: _buildGlow(size: 220, color: const Color(0x55F7C7DB)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Spacer(),
                const Text(
                  'LIQUID REFRACTION',
                  style: TextStyle(
                    color: Color(0x881A2233),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Surface',
                  style: TextStyle(
                    color: Color(0xFF141A28),
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
                const Text(
                  'Prototype',
                  style: TextStyle(
                    color: Color(0xFF141A28),
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'A Flutter-first experiment for liquid displacement, water highlights, and interactive refraction.',
                  style: TextStyle(
                    color: Color(0xB3141A28),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: const <Widget>[
                    _FeatureCard(
                      title: 'Water Preset',
                      description:
                          'A lighter preset that favors clean reflections and quicker wave rebound.',
                    ),
                    _FeatureCard(
                      title: 'Image Mode',
                      description:
                          'Switch to the package asset scene to inspect refraction over real detail.',
                    ),
                    _FeatureCard(
                      title: 'Bottom Sheet',
                      description:
                          'All controls now live in a bottom drawer so the main stage stays visible.',
                    ),
                  ],
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStage() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                const Color(0xFF06111E).withValues(alpha: 0.08),
                const Color(0xFF03080F).withValues(alpha: 0.24),
                const Color(0xFF02050A).withValues(alpha: 0.46),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x8C08111E),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Image Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Water Surface',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  height: 0.98,
                  shadows: <Shadow>[
                    Shadow(
                      color: Color(0x44000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 320),
                child: const Text(
                  'Use the package image backdrop to inspect refraction, motion glints and the lighter water response.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applyPreset(_SurfacePreset preset) {
    _preset = preset;

    switch (preset) {
      case _SurfacePreset.water:
        _metalness = 0.12;
        _roughness = 0.16;
        _displacementScale = 1.72;
        _cellSize = 16.0;
        _highlightOpacity = 0.2;
        _chromaticAberration = 0.08;
        _autoDrops = false;
      case _SurfacePreset.liquidGlass:
        _metalness = 0.42;
        _roughness = 0.3;
        _displacementScale = 2.25;
        _cellSize = 18.0;
        _highlightOpacity = 0.18;
        _chromaticAberration = 0.16;
        _autoDrops = false;
    }
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            void updateControls(VoidCallback update) {
              setState(update);
              setSheetState(() {});
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xF1111722),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 18,
                      right: 18,
                      top: 14,
                      bottom: 18 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.white),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Surface Settings',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey<String>(
                                      'close-settings-button',
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Close settings',
                                  ),
                                ],
                              ),
                              const Text(
                                'Switch the backdrop, apply a preset, then tune the surface without covering the main stage when the drawer is closed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xB3FFFFFF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSectionLabel('Backdrop'),
                              const SizedBox(height: 8),
                              SegmentedButton<_DemoBackdropMode>(
                                segments:
                                    const <ButtonSegment<_DemoBackdropMode>>[
                                      ButtonSegment<_DemoBackdropMode>(
                                        value: _DemoBackdropMode.text,
                                        label: Text('Text'),
                                        icon: Icon(Icons.text_fields_rounded),
                                      ),
                                      ButtonSegment<_DemoBackdropMode>(
                                        value: _DemoBackdropMode.image,
                                        label: Text('Image'),
                                        icon: Icon(Icons.image_rounded),
                                      ),
                                    ],
                                selected: <_DemoBackdropMode>{_backdropMode},
                                onSelectionChanged:
                                    (Set<_DemoBackdropMode> selection) {
                                      updateControls(() {
                                        _backdropMode = selection.first;
                                      });
                                    },
                              ),
                              const SizedBox(height: 14),
                              _buildSectionLabel('Preset'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  _buildPresetChip(
                                    label: 'Water',
                                    selected: _preset == _SurfacePreset.water,
                                    onTap: () {
                                      updateControls(() {
                                        _applyPreset(_SurfacePreset.water);
                                      });
                                    },
                                  ),
                                  _buildPresetChip(
                                    label: 'Liquid Glass',
                                    selected:
                                        _preset == _SurfacePreset.liquidGlass,
                                    onTap: () {
                                      updateControls(() {
                                        _applyPreset(
                                          _SurfacePreset.liquidGlass,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSlider(
                                label: 'Metalness',
                                value: _metalness,
                                min: 0,
                                max: 1,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _metalness = value;
                                  });
                                },
                              ),
                              _buildSlider(
                                label: 'Roughness',
                                value: _roughness,
                                min: 0,
                                max: 1,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _roughness = value;
                                  });
                                },
                              ),
                              _buildSlider(
                                label: 'Displacement',
                                value: _displacementScale,
                                min: 0.4,
                                max: 4.5,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _displacementScale = value;
                                  });
                                },
                              ),
                              _buildSlider(
                                label: 'Cell Size',
                                value: _cellSize,
                                min: 10,
                                max: 28,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _cellSize = value;
                                  });
                                },
                              ),
                              _buildSlider(
                                label: 'Highlight',
                                value: _highlightOpacity,
                                min: 0,
                                max: 0.3,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _highlightOpacity = value;
                                  });
                                },
                              ),
                              _buildSlider(
                                label: 'Chromatic',
                                value: _chromaticAberration,
                                min: 0,
                                max: 1,
                                onChanged: (double value) {
                                  updateControls(() {
                                    _chromaticAberration = value;
                                  });
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _autoDrops,
                                onChanged: (bool value) {
                                  updateControls(() {
                                    _autoDrops = value;
                                  });
                                },
                                title: const Text(
                                  'Auto Drops',
                                  style: TextStyle(fontSize: 14),
                                ),
                                subtitle: const Text(
                                  'Inject slow ripples in the background while keeping the main stage unobstructed.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0x99FFFFFF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xCCFFFFFF),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF10151F) : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: const Color(0xFFE6EEF8),
      backgroundColor: const Color(0x1AFFFFFF),
      side: BorderSide(
        color: selected ? const Color(0xFFE6EEF8) : const Color(0x26FFFFFF),
      ),
    );
  }

  Widget _buildGlow({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: color.a * 0.28),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF121826),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xB3121826),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
