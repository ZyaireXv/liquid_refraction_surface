import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_refraction_surface/liquid_refraction_surface.dart';

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

enum _SurfacePreset { water, liquidGlass }

class LiquidRefractionDemoPage extends StatefulWidget {
  const LiquidRefractionDemoPage({super.key});

  @override
  State<LiquidRefractionDemoPage> createState() =>
      _LiquidRefractionDemoPageState();
}

class _LiquidRefractionDemoPageState extends State<LiquidRefractionDemoPage> {
  static const AssetImage _demoImage = AssetImage('assets/image.jpg');
  static const MethodChannel _backendChannel = MethodChannel(
    'liquid_refraction_surface/debug_backend',
  );

  LiquidRefractionPlacement _placement = LiquidRefractionPlacement.content;
  _SurfacePreset _preset = _SurfacePreset.water;
  double _metalness = 0.12;
  double _roughness = 0.16;
  double _displacementScale = 1.72;
  double _cellSize = 16.0;
  double _highlightOpacity = 0.2;
  double _chromaticAberration = 0.08;
  bool _autoDrops = false;
  LiquidRainIntensity _rainIntensity = LiquidRainIntensity.light;
  int _rainDropCount = 0;
  int _contentActionTapCount = 0;
  int _primaryActionTapCount = 0;
  int _cardTapCount = 0;
  String _requestedBackendBadge = 'AUTO';

  @override
  void initState() {
    super.initState();
    _applyPreset(_preset);
    _loadRequestedBackendBadge();
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
      rainIntensity: _rainIntensity,
      rainDropCount: _autoDrops && _rainDropCount > 0 ? _rainDropCount : null,
    );

    return Scaffold(
      body: _wrapWithRequestedBackendBanner(
        LiquidRefractionSurface(
          placement: _placement,
          backgroundColor: _placement == LiquidRefractionPlacement.content
              ? const Color(0xFF101B2A)
              : const Color(0xFF0F1824),
          backdrop: switch (_placement) {
            LiquidRefractionPlacement.content => null,
            LiquidRefractionPlacement.background => _buildBackdropStage(),
          },
          config: config,
          child: _buildStageChild(),
        ),
      ),
    );
  }

  Future<void> _loadRequestedBackendBadge() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final backend = await _backendChannel.invokeMethod<String>(
        'getRequestedBackend',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _requestedBackendBadge = _formatRequestedBackendBadge(backend);
      });
    } on PlatformException {
      // 角标只用于辅助定位 Android 图形后端测试目标。
      // 通道失败时保留默认值，不让调试标识反过来影响示例页本身的交互演示。
    }
  }

  String _formatRequestedBackendBadge(String? backend) {
    return switch ((backend ?? '').trim().toLowerCase()) {
      'vulkan' => 'VULKAN',
      'opengles' => 'OPENGL ES',
      _ => 'AUTO',
    };
  }

  Widget _wrapWithRequestedBackendBanner(Widget child) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || kReleaseMode) {
      return child;
    }

    // 角标展示的是当前 Android 调试包里声明的“目标后端模式”。
    //
    // 这里刻意不用页面内普通文本，而是挂到右上角固定展示，
    // 是因为这类信息只在排查图形问题时有价值，
    // 但一旦看漏，就很容易把 OpenGLES 和 Vulkan 的现象混在一起。
    // 用系统自带的 Banner 可以把提示固定在视野边缘，又不会打断主演示内容。
    return Banner(
      message: _requestedBackendBadge,
      location: BannerLocation.topEnd,
      color: _backendBadgeColor,
      child: child,
    );
  }

  Color get _backendBadgeColor {
    return switch (_requestedBackendBadge) {
      'VULKAN' => const Color(0xFF0D8B68),
      'OPENGL ES' => const Color(0xFF9C5416),
      _ => const Color(0xFF325E9F),
    };
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB8141B2A),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _placementTitle(_placement),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
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
            tooltip: 'Open settings',
          ),
        ),
      ],
    );
  }

  Widget _buildHintBanner() {
    final hint = switch (_placement) {
      LiquidRefractionPlacement.content =>
        'Content mode directly refracts the whole scene, so the full stage moves with the surface.',
      LiquidRefractionPlacement.background =>
        'Background mode keeps the liquid layer behind the content while the card stays untouched.',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xA6141B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          hint,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildStageChild() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTopBar(),
            const SizedBox(height: 14),
            _buildHintBanner(),
            const SizedBox(height: 20),
            Expanded(
              child: switch (_placement) {
                LiquidRefractionPlacement.content => _buildContentStage(),
                LiquidRefractionPlacement.background => _buildOverlayCard(
                    title: 'Background Mode',
                    description: 'The liquid layer sits underneath the card, so the content stays sharp while the background keeps reacting to touch.',
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStage() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final topGap = constraints.maxHeight > 720
            ? constraints.maxHeight * 0.24
            : 48.0;
        final bottomGap = constraints.maxHeight > 720
            ? constraints.maxHeight * 0.12
            : 28.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: _demoImage,
              fit: BoxFit.cover,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xB8142438),
                Color(0x8C102035),
                Color(0xAA0B182A),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 图片里亮部很多，直接把白字压上去会丢对比度。
              // 这里补一层深色遮罩，让标题、说明和按钮在波纹经过时依然能看清。
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          const Color(0xCC08111C),
                          const Color(0x8C0C1725),
                          const Color(0x520D1827),
                          const Color(0xB8142134),
                        ],
                        stops: const <double>[0, 0.26, 0.58, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -80,
                top: 120,
                child: IgnorePointer(
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          Color(0x66060D17),
                          Color(0x22060D17),
                          Color(0x00060D17),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 72),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(height: topGap),
                      const Text(
                        'LIQUID REFRACTION',
                        style: TextStyle(
                          color: Color(0xCCE6F1FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Content',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 70,
                          fontWeight: FontWeight.w700,
                          height: 0.95,
                        ),
                      ),
                      const Text(
                        'Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 70,
                          fontWeight: FontWeight.w700,
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'This view keeps the original full-stage refraction setup so the whole composition can move as one liquid surface.',
                        style: TextStyle(
                          color: Color(0xF0EEF5FF),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          FilledButton(
                            key: const ValueKey<String>('content-action-button'),
                            onPressed: () {
                              setState(() {
                                _contentActionTapCount++;
                              });
                            },
                            child: const Text('Tap in content mode'),
                          ),
                          _MetricTag(
                            label: 'Content taps',
                            value: '$_contentActionTapCount',
                            useDarkStyle: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'The button is part of the refracted content tree, so it visually bends with the surface while still keeping its normal Flutter tap behavior.',
                        style: TextStyle(
                          color: Color(0xE1E7F0FB),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: const <Widget>[
                          _FeatureCard(
                            title: 'Content',
                            description: 'The child becomes the refracted source, which works best for a full-stage treatment.',
                          ),
                          _FeatureCard(
                            title: 'Background',
                            description: 'The liquid layer stays behind the content, closer to a reactive background container.',
                          ),
                          _FeatureCard(
                            title: 'Image Source',
                            description: 'Both demos now use the bundled image so you can judge refraction against real texture instead of flat color alone.',
                          ),
                        ],
                      ),
                      SizedBox(height: bottomGap),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackdropStage() {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: _demoImage,
          fit: BoxFit.cover,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x66101B2A),
            Color(0x40112035),
            Color(0x80081424),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -40,
            right: -10,
            child: _buildGlow(size: 220, color: const Color(0x66A9C8F1)),
          ),
          Positioned(
            left: -20,
            bottom: 60,
            child: _buildGlow(size: 200, color: const Color(0x55F6C8D7)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x99FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Backdrop',
                      style: TextStyle(
                        color: Color(0xFF132131),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Shared',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 0.96,
                  ),
                ),
                const Text(
                  'Backdrop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 0.96,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The background demo uses the same widget-style source as the content demo, so the package keeps a consistent widget-first API.',
                  style: TextStyle(
                    color: Color(0xE0E7F0FF),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const <Widget>[
                    _BackdropChip(label: 'Widget Source'),
                    _BackdropChip(label: 'Interactive Ripples'),
                    _BackdropChip(label: 'No Image Required'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayCard({
    required String title,
    required String description,
  }) {
    const panelColor = Color(0xCCFFFFFF);
    const panelBorderColor = Color(0x30FFFFFF);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _cardTapCount++;
              });
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: panelBorderColor),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF121826),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xB3121826),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MetricTag(
                          label: 'Button taps',
                          value: '$_primaryActionTapCount',
                        ),
                        _MetricTag(
                          label: 'Card taps',
                          value: '$_cardTapCount',
                        ),
                        _MetricTag(
                          label: 'Tap mode',
                          value: 'Default',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OverflowBar(
                      spacing: 12,
                      overflowSpacing: 12,
                      alignment: MainAxisAlignment.start,
                      children: <Widget>[
                        FilledButton(
                          key: const ValueKey<String>('primary-action-button'),
                          onPressed: () {
                            setState(() {
                              _primaryActionTapCount++;
                            });
                          },
                          child: const Text('Primary action'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _cardTapCount = 0;
                              _primaryActionTapCount = 0;
                            });
                          },
                          child: const Text('Reset counters'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'In background mode the card keeps its original interaction while the liquid surface reacts underneath it.',
                      style: const TextStyle(
                        color: Color(0x99121826),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
        _rainIntensity = LiquidRainIntensity.light;
        _rainDropCount = 0;
      case _SurfacePreset.liquidGlass:
        _metalness = 0.42;
        _roughness = 0.3;
        _displacementScale = 2.25;
        _cellSize = 18.0;
        _highlightOpacity = 0.18;
        _chromaticAberration = 0.16;
        _autoDrops = false;
        _rainIntensity = LiquidRainIntensity.medium;
        _rainDropCount = 0;
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
                    color: const Color(0xFC101826),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x33FFFFFF)),
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
                                'This panel keeps content and background modes in one place so their layout and interaction behavior are easy to compare.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xD9E5EEFF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSectionLabel('Placement'),
                              const SizedBox(height: 8),
                              SegmentedButton<LiquidRefractionPlacement>(
                                segments:
                                    const <ButtonSegment<LiquidRefractionPlacement>>[
                                      ButtonSegment<LiquidRefractionPlacement>(
                                        value: LiquidRefractionPlacement.content,
                                        label: Text('Content'),
                                        icon: Icon(Icons.crop_landscape_rounded),
                                      ),
                                      ButtonSegment<LiquidRefractionPlacement>(
                                        value:
                                            LiquidRefractionPlacement.background,
                                        label: Text('Background'),
                                        icon: Icon(Icons.layers_clear_rounded),
                                      ),
                                    ],
                                selected: <LiquidRefractionPlacement>{
                                  _placement,
                                },
                                // 这里单独压住分段按钮的状态色。
                                // 深色弹窗里如果继续用 Material 默认色，未选中项会被压得太暗，
                                // 看起来像禁用态，用户很难一眼分清“可点”和“不可点”。
                                style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return const Color(0xFFDCE7FA);
                                        }

                                        return const Color(0x1E243247);
                                      }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return const Color(0xFF162132);
                                        }

                                        return const Color(0xFFF2F6FF);
                                      }),
                                  iconColor:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return const Color(0xFF304865);
                                        }

                                        return const Color(0xFFDCE8F8);
                                      }),
                                  side: const WidgetStatePropertyAll<BorderSide>(
                                    BorderSide(color: Color(0x52D3DEEE)),
                                  ),
                                  overlayColor:
                                      const WidgetStatePropertyAll<Color>(
                                        Color(0x143C6CA8),
                                      ),
                                  textStyle:
                                      const WidgetStatePropertyAll<TextStyle>(
                                        TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                ),
                                onSelectionChanged: (
                                  Set<LiquidRefractionPlacement> selection,
                                ) {
                                  updateControls(() {
                                    _placement = selection.first;
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
                              const SizedBox(height: 6),
                              _buildSectionLabel('Rain'),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _autoDrops,
                                activeThumbColor: const Color(0xFFF3F7FF),
                                activeTrackColor: const Color(0xFF4B78B4),
                                inactiveThumbColor: const Color(0xFFD8E6F8),
                                inactiveTrackColor: const Color(0x3D92A9C7),
                                onChanged: (bool value) {
                                  updateControls(() {
                                    _autoDrops = value;
                                  });
                                },
                                title: const Text(
                                  'Rain Mode',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFF3F7FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Adds idle rain-driven ripples. Intensity sets the default rhythm, and the count slider can override how many drops land in each burst.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xC6D8E9FF),
                                  ),
                                ),
                              ),
                              if (_autoDrops) ...<Widget>[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    _buildPresetChip(
                                      label: 'Light Rain',
                                      selected:
                                          _rainIntensity ==
                                          LiquidRainIntensity.light,
                                      onTap: () {
                                        updateControls(() {
                                          _rainIntensity =
                                              LiquidRainIntensity.light;
                                        });
                                      },
                                    ),
                                    _buildPresetChip(
                                      label: 'Medium Rain',
                                      selected:
                                          _rainIntensity ==
                                          LiquidRainIntensity.medium,
                                      onTap: () {
                                        updateControls(() {
                                          _rainIntensity =
                                              LiquidRainIntensity.medium;
                                        });
                                      },
                                    ),
                                    _buildPresetChip(
                                      label: 'Heavy Rain',
                                      selected:
                                          _rainIntensity ==
                                          LiquidRainIntensity.heavy,
                                      onTap: () {
                                        updateControls(() {
                                          _rainIntensity =
                                              LiquidRainIntensity.heavy;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildSlider(
                                  label: 'Drops per burst',
                                  value: _rainDropCount.toDouble(),
                                  min: 0,
                                  max: 8,
                                  divisions: 8,
                                  valueTextBuilder: (double value) {
                                    final count = value.round();
                                    return count == 0 ? 'Auto' : '$count';
                                  },
                                  onChanged: (double value) {
                                    updateControls(() {
                                      _rainDropCount = value.round();
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rainDropCount == 0
                                      ? 'Auto follows the current rain intensity.'
                                      : 'Manual count overrides the default drop count from the rain intensity.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xC6D8E9FF),
                                    height: 1.45,
                                  ),
                                ),
                              ],
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

  String _placementTitle(LiquidRefractionPlacement placement) {
    return switch (placement) {
      LiquidRefractionPlacement.content => 'Content Mode',
      LiquidRefractionPlacement.background => 'Background Mode',
    };
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
      // 预设按钮和分段按钮在同一个弹窗里，状态对比要一致。
      // 这里不用默认的 Chip 配色，避免深底上出现“按钮发灰、文字发白但不清楚”的情况。
      color: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFE6EEF8);
        }

        return const Color(0x22233248);
      }),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF10151F) : const Color(0xFFF2F6FF),
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFE6EEF8) : const Color(0x45C8D6EB),
      ),
      checkmarkColor: const Color(0xFF304865),
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
    int? divisions,
    String Function(double value)? valueTextBuilder,
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
              valueTextBuilder?.call(value) ?? value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
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

class _BackdropChip extends StatelessWidget {
  const _BackdropChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x96FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF182132),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MetricTag extends StatelessWidget {
  const _MetricTag({
    required this.label,
    required this.value,
    this.useDarkStyle = false,
  });

  final String label;
  final String value;
  final bool useDarkStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: useDarkStyle
            ? const Color(0xA2141C2B)
            : const Color(0x0F141A28),
        borderRadius: BorderRadius.circular(999),
        border: useDarkStyle
            ? Border.all(color: const Color(0x2ECFE0FF))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: useDarkStyle
                ? const Color(0xFFF2F7FF)
                : const Color(0xFF182132),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
