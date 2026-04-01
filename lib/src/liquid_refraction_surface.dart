import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'liquid_displacement_field.dart';
import 'liquid_field_texture.dart';
import 'liquid_refraction_config.dart';
import 'liquid_rain_intensity.dart';
import 'liquid_refraction_placement.dart';
import 'liquid_refraction_shader_layer.dart';

/// 液态折射舞台组件。
///
/// 这个包单独承接整屏位移场和折射表现，不复用粒子系统那套抽象。
/// 当前实现只保留移动端 shader 路线，避免同一套交互逻辑长期维护两套渲染结果。
class LiquidRefractionSurface extends StatefulWidget {
  const LiquidRefractionSurface({
    super.key,
    required this.child,
    this.backdrop,
    this.backgroundImage,
    this.backgroundColor,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.placement = LiquidRefractionPlacement.content,
    this.config = const LiquidRefractionConfig(),
  });

  /// 放在液态表面下方的内容。
  ///
  /// 这里改成必传，是为了让调用方式和容器型组件保持一致：
  /// 页面总有一棵明确的内容树，液态层只是决定包在它外面、压在它上面，
  /// 还是直接作用到它本身。
  final Widget child;

  /// 提供给液态层采样的底层内容。
  ///
  /// `content` 模式下通常不需要单独传，因为 child 自己就会被直接折射。
  /// `background` 模式下更建议提供这一层，
  /// 否则液态层只能基于纯色或透明底做采样，折射层次会弱很多。
  final Widget? backdrop;

  /// 直接作为底图输入的图片资源。
  ///
  /// 这条路径先保留，是为了兼容当前仓库里已经存在的图片试验方式。
  /// 但后续主推荐用法会转到 `backdrop`，让外部统一走 widget 组合。
  final ImageProvider<Object>? backgroundImage;
  final Color? backgroundColor;
  final BoxFit fit;
  final Alignment alignment;
  final Clip clipBehavior;
  final LiquidRefractionPlacement placement;
  final LiquidRefractionConfig config;

  @override
  State<LiquidRefractionSurface> createState() =>
      _LiquidRefractionSurfaceState();
}

class _LiquidRefractionSurfaceState extends State<LiquidRefractionSurface>
    with SingleTickerProviderStateMixin {
  /// shader 每帧都会重绘，但位移纹理不需要同样频率地重建。
  ///
  /// 这里把上传频率压到 45fps，主要是为了控制纹理重建成本。
  /// 交互注入时仍然会强制刷新，因此不会明显损失手势阶段的跟手感。
  static const double _fieldTextureRefreshInterval = 1 / 45;

  final math.Random _random = math.Random();

  late final AnimationController _controller;
  late LiquidDisplacementField _field;

  ui.Image? _fieldTexture;
  Size _size = Size.zero;
  Duration _lastElapsed = Duration.zero;
  double _animationTime = 0.0;
  double _fieldTextureElapsed = 0.0;
  Offset? _lastPointerPosition;
  bool _autoDropEnabled = false;
  double _autoDropElapsed = 0.0;
  double _nextAutoDropDelay = 0.0;
  // 位移场更新得比纹理构建更快时，这组状态用来合并请求。
  // 这样动画高频阶段最多只保留“当前正在构建的一张”和“最新的一张待构建”，
  // 不会因为旧帧还没完成就继续堆积无意义的中间结果。
  bool _isBuildingFieldTexture = false;
  int _queuedFieldRevision = -1;
  int _uploadedFieldRevision = -1;
  int _fieldTextureBuildToken = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(_handleTick);
    _field = _createField(widget.config);
    _autoDropEnabled = widget.config.enableAutoDrops;
    _resetAutoDropSchedule();
  }

  @override
  void didUpdateWidget(covariant LiquidRefractionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);

    final configAffectsField =
        oldWidget.config.cellSize != widget.config.cellSize ||
        oldWidget.config.roughness != widget.config.roughness;
    if (configAffectsField) {
      _field = _createField(widget.config);
      _field.resize(_size);
      _fieldTextureElapsed = _fieldTextureRefreshInterval;
      _refreshFieldTexture(force: true);
      _syncTicker();
    }

    final autoDropConfigChanged =
        oldWidget.config.enableAutoDrops != widget.config.enableAutoDrops ||
        oldWidget.config.rainIntensity != widget.config.rainIntensity ||
        oldWidget.config.rainDropCount != widget.config.rainDropCount;
    if (autoDropConfigChanged) {
      _autoDropEnabled = widget.config.enableAutoDrops;
      _resetAutoDropSchedule();
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _disposeFieldTexture();
    super.dispose();
  }

  LiquidDisplacementField _createField(LiquidRefractionConfig config) {
    final normalizedRoughness = config.roughness.clamp(0.0, 1.0);
    return LiquidDisplacementField(
      cellSize: config.cellSize,
      // 当前目标不是做厚重、迟滞的黏稠液体，而是更接近水面的回弹。
      // 所以这里把恢复力和保能量都往上提了一档：
      // 恢复力更强，波峰不会长时间鼓在原地；
      // 阻尼更弱，能量会先传播成波，再衰减，而不是刚被拖动就塌成一团。
      stiffness: 0.14 + ((1.0 - normalizedRoughness) * 0.055),
      damping: 0.958 + ((1.0 - normalizedRoughness) * 0.02),
    );
  }

  void _disposeFieldTexture() {
    _fieldTextureBuildToken++;
    _fieldTexture?.dispose();
    _fieldTexture = null;
    _isBuildingFieldTexture = false;
    _queuedFieldRevision = -1;
    _uploadedFieldRevision = -1;
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _handleTick() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(
      0.0,
      0.033,
    );
    _lastElapsed = elapsed;
    _animationTime += dt;
    _fieldTextureElapsed += dt;

    _field.update(dt);
    _refreshFieldTextureIfNeeded();

    if (_autoDropEnabled && _size.isFinite && !_size.isEmpty) {
      _autoDropElapsed += dt;
      while (_autoDropElapsed >= _nextAutoDropDelay) {
        _autoDropElapsed -= _nextAutoDropDelay;
        _injectAutoRainBurst();
        _nextAutoDropDelay = _resolveNextAutoDropDelay();
      }
    }

    if (_field.hasActivity || _autoDropEnabled) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _lastElapsed = Duration.zero;
    _controller.stop();
  }

  void _syncTicker() {
    final needsAnimation = _field.hasActivity || _autoDropEnabled;
    if (!needsAnimation) {
      _lastElapsed = Duration.zero;
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (_controller.isAnimating) {
      return;
    }

    _controller.repeat(min: 0, max: 1, period: const Duration(days: 1));
  }

  void _handleSizeChanged(Size size) {
    if (_size == size || !size.isFinite || size.isEmpty) {
      return;
    }

    _size = size;
    _field.resize(size);
    _fieldTextureElapsed = _fieldTextureRefreshInterval;
    _refreshFieldTexture(force: true);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.localPosition;
    _injectDisturbance(event.localPosition, strength: 0.9, isSplash: true);
  }

  /// 每次切换自动雨滴配置时，都重新计算下一次注入的时机。
  ///
  /// 如果这里不重置，用户刚把“小雨”切到“大雨”时，界面还会先沿用上一档的等待时间，
  /// 手感会有一种“明明切了，但半天没变化”的迟滞。
  void _resetAutoDropSchedule() {
    _autoDropElapsed = 0.0;
    _nextAutoDropDelay = _resolveNextAutoDropDelay();
  }

  void _handlePointerMove(PointerEvent event) {
    final position = event.localPosition;
    final previousPosition = _lastPointerPosition;
    _lastPointerPosition = position;

    if (previousPosition == null) {
      _injectDisturbance(position, strength: 0.38, isSplash: false);
      return;
    }

    final distance = (position - previousPosition).distance;
    final threshold = math.max(6.0, widget.config.cellSize * 0.45);
    if (distance < threshold) {
      return;
    }

    final strength = (0.18 + (distance / widget.config.interactionRadius))
        .clamp(0.16, 0.58);
    final fieldPreviousPosition = _mapPointerToFieldSpace(previousPosition);
    final fieldPosition = _mapPointerToFieldSpace(position);
    _field.addImpulseTrail(
      fieldPreviousPosition,
      fieldPosition,
      // 拖动覆盖范围收窄以后，液面会更像被手势掠过，
      // 而不是整条路径都被“抹出一层厚浆”。
      radius: widget.config.interactionRadius * 0.5,
      strength: strength,
    );
    _fieldTextureElapsed = _fieldTextureRefreshInterval;
    _refreshFieldTextureIfNeeded(force: true);
    _syncTicker();
    if (mounted) {
      setState(() {});
    }
  }

  void _injectDisturbance(
    Offset center, {
    required double strength,
    required bool isSplash,
  }) {
    if (_size.isEmpty) {
      return;
    }

    final fieldCenter = _mapPointerToFieldSpace(center);
    _field.addImpulse(
      fieldCenter,
      radius: widget.config.interactionRadius * (isSplash ? 0.82 : 0.58),
      strength: strength,
    );
    _fieldTextureElapsed = _fieldTextureRefreshInterval;
    _refreshFieldTextureIfNeeded(force: true);

    _syncTicker();
    if (mounted) {
      setState(() {});
    }
  }

  /// 自动雨滴和手势波纹共用同一张位移场，但它们的注入形态不该一样。
  ///
  /// 手势更像一团连续外推的能量，雨滴则应该是一个短促的落点加几圈外扩波纹。
  /// 这里单独走 `addRaindrop`，是为了把“像雨滴”这件事落在场本身，而不是只靠 shader 硬描边。
  void _injectRaindrop(
    Offset center, {
    required double radius,
    required double strength,
    required int rippleCount,
    required double travelFactor,
  }) {
    if (_size.isEmpty) {
      return;
    }

    final fieldCenter = _mapPointerToFieldSpace(center);
    _field.addRaindrop(
      fieldCenter,
      radius: radius,
      strength: strength,
      rippleCount: rippleCount,
      travelFactor: travelFactor,
    );
  }

  /// 自动模式下一次注入一批雨滴。
  ///
  /// 当前实现不是粒子系统，所以这里的“数量”指的是一次节拍里同时打进位移场的落点数。
  /// 这样做的好处是保留了连续位移场的优势，同时也能把“小雨稀疏、大雨成片”的节奏做出来。
  void _injectAutoRainBurst() {
    if (_size.isEmpty) {
      return;
    }

    final profile = _resolveAutoRainProfile();
    final burstCount = _resolveAutoRainBurstCount(profile);
    final horizontalMargin = _size.width * 0.14;
    final verticalMargin = _size.height * 0.14;

    for (var dropIndex = 0; dropIndex < burstCount; dropIndex++) {
      _injectRaindrop(
        Offset(
          _randomBetween(horizontalMargin, _size.width - horizontalMargin),
          _randomBetween(verticalMargin, _size.height - verticalMargin),
        ),
        radius:
            widget.config.interactionRadius *
            _randomBetween(profile.minRadiusFactor, profile.maxRadiusFactor),
        strength: _randomBetween(profile.minStrength, profile.maxStrength),
        rippleCount: _randomInt(profile.minRippleCount, profile.maxRippleCount),
        travelFactor: _randomBetween(
          profile.minTravelFactor,
          profile.maxTravelFactor,
        ),
      );
    }

    _fieldTextureElapsed = _fieldTextureRefreshInterval;
    _refreshFieldTextureIfNeeded(force: true);
    _syncTicker();
    if (mounted) {
      setState(() {});
    }
  }

  _AutoRainProfile _resolveAutoRainProfile() {
    return switch (widget.config.rainIntensity) {
      // 小雨不只是更稀，而是单滴更轻，波圈也更短。
      // 这样画面会更安静，不会把整个表面一直搅得很满。
      LiquidRainIntensity.light => const _AutoRainProfile(
          minInterval: 0.62,
          maxInterval: 0.96,
          defaultBurstCount: 1,
          minRadiusFactor: 0.18,
          maxRadiusFactor: 0.28,
          minStrength: 0.16,
          maxStrength: 0.24,
          minRippleCount: 2,
          maxRippleCount: 2,
          minTravelFactor: 0.92,
          maxTravelFactor: 1.2,
        ),
      LiquidRainIntensity.medium => const _AutoRainProfile(
          minInterval: 0.34,
          maxInterval: 0.62,
          defaultBurstCount: 2,
          minRadiusFactor: 0.24,
          maxRadiusFactor: 0.34,
          minStrength: 0.2,
          maxStrength: 0.3,
          minRippleCount: 2,
          maxRippleCount: 3,
          minTravelFactor: 1.18,
          maxTravelFactor: 1.5,
        ),
      LiquidRainIntensity.heavy => const _AutoRainProfile(
          minInterval: 0.16,
          maxInterval: 0.3,
          defaultBurstCount: 3,
          minRadiusFactor: 0.3,
          maxRadiusFactor: 0.46,
          minStrength: 0.26,
          maxStrength: 0.4,
          minRippleCount: 3,
          maxRippleCount: 4,
          minTravelFactor: 1.5,
          maxTravelFactor: 2.0,
        ),
    };
  }

  /// 默认数量会跟屏幕面积一起轻微缩放，手动覆盖时则尊重调用方输入。
  ///
  /// 这样做和 `ambient_effects_container` 的思路一致：
  /// 档位负责给出合理默认值，手动数量负责覆盖默认值。
  /// 这里不把面积缩放做得太激进，是为了避免大屏下一口气注入太多落点，直接把液面打成噪声。
  int _resolveAutoRainBurstCount(_AutoRainProfile profile) {
    final manualCount = widget.config.rainDropCount;
    if (manualCount != null) {
      return manualCount.clamp(1, 12);
    }

    const referenceArea = 390.0 * 844.0;
    final areaScale = ((_size.width * _size.height) / referenceArea).clamp(
      0.82,
      1.45,
    );
    return math.max(1, (profile.defaultBurstCount * areaScale).round());
  }

  double _resolveNextAutoDropDelay() {
    final profile = _resolveAutoRainProfile();
    return _randomBetween(profile.minInterval, profile.maxInterval);
  }

  void _refreshFieldTextureIfNeeded({bool force = false}) {
    if (!_isSupportedPlatform) {
      return;
    }
    if (!force &&
        _fieldTexture != null &&
        _fieldTextureElapsed < _fieldTextureRefreshInterval) {
      return;
    }
    _refreshFieldTexture(force: force);
  }

  void _refreshFieldTexture({bool force = false}) {
    if (!_isSupportedPlatform) {
      _disposeFieldTexture();
      return;
    }

    final revision = _field.revision;
    if (!force && revision == _uploadedFieldRevision) {
      return;
    }
    _queuedFieldRevision = revision;

    if (_isBuildingFieldTexture) {
      return;
    }

    unawaited(_buildFieldTexture());
  }

  /// 异步重建位移纹理，并在构建结束后只保留最新结果。
  ///
  /// 位移场本身仍然在 Dart 侧逐帧推进，但纹理解码已经变成异步过程。
  /// 如果这里不做版本合并，快速拖动时就会出现前一批构建还没完成，
  /// 后一批构建又继续排队的情况，最终把性能浪费在过时帧上。
  Future<void> _buildFieldTexture() async {
    if (!_isSupportedPlatform || _isBuildingFieldTexture) {
      return;
    }

    final revision = _queuedFieldRevision >= 0
        ? _queuedFieldRevision
        : _field.revision;
    final buildToken = ++_fieldTextureBuildToken;
    _isBuildingFieldTexture = true;

    final nextTexture = await LiquidFieldTextureBuilder.build(_field);
    _isBuildingFieldTexture = false;

    if (!mounted || buildToken != _fieldTextureBuildToken) {
      nextTexture?.dispose();
      return;
    }
    if (nextTexture == null) {
      return;
    }

    final previous = _fieldTexture;
    _uploadedFieldRevision = revision;
    _fieldTextureElapsed = 0.0;
    setState(() {
      _fieldTexture = nextTexture;
    });
    previous?.dispose();

    if (_queuedFieldRevision > revision) {
      unawaited(_buildFieldTexture());
    }
  }

  bool get _hasBackdropSource {
    return widget.backgroundColor != null ||
        widget.backgroundImage != null ||
        widget.backdrop != null;
  }

  Widget _buildBackdropSource() {
    if (!_hasBackdropSource) {
      // 背景模式下，调用方有时只想要一层轻薄的液面高光，
      // 不一定每次都准备一套完整的底图。
      // 这里用透明盒子兜住尺寸，保证 shader 和手势链路还能工作，
      // 只是折射信息会比提供 backdrop 时更少。
      return const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.backgroundColor != null)
          ColoredBox(color: widget.backgroundColor!),
        if (widget.backgroundImage != null)
          Image(
            image: widget.backgroundImage!,
            fit: widget.fit,
            alignment: widget.alignment,
          ),
        if (widget.backdrop != null) widget.backdrop!,
      ],
    );
  }

  Widget _buildPresentedChild() {
    return widget.child;
  }

  Widget _buildContentSource() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_hasBackdropSource) _buildBackdropSource(),
        _buildPresentedChild(),
      ],
    );
  }

  Widget _buildVisibleSceneWithoutEffect() {
    switch (widget.placement) {
      case LiquidRefractionPlacement.content:
        return _buildContentSource();
      case LiquidRefractionPlacement.background:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_hasBackdropSource) _buildBackdropSource(),
            _buildPresentedChild(),
          ],
        );
    }
  }

  Offset _mapPointerToFieldSpace(Offset position) {
    // 交互坐标这里始终保留 Flutter 本地坐标系，不再额外做 Android 侧翻转。
    //
    // 原来的做法是在 Dart 层把 Android 触点的 Y 轴先反过来，
    // 但 shader 里又已经针对 OpenGLES 做了纹理采样方向修正。
    // 这会让“触点坐标修正”和“采样坐标修正”分散在两层里，并且判断条件还不一致：
    // - Dart 层只按“是不是 Android”判断
    // - shader 层按“当前是不是 OpenGLES 后端”判断
    //
    // 一旦某些 Android 设备走 Vulkan、另一些走 OpenGLES，
    // 同一份代码就会出现有的机型正常、有的机型上下颠倒的问题。
    //
    // 这里统一把坐标语义收口到一处：
    // 交互输入始终使用 Flutter 的本地坐标，
    // 图形后端差异只交给 shader 里的采样坐标转换处理。
    return position;
  }

  Widget _buildEffectScene() {
    switch (widget.placement) {
      case LiquidRefractionPlacement.content:
        return LiquidRefractionShaderLayer(
          config: widget.config,
          fieldTexture: _fieldTexture,
          animationTime: _animationTime,
          child: _buildContentSource(),
        );
      case LiquidRefractionPlacement.background:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: LiquidRefractionShaderLayer(
                config: widget.config,
                fieldTexture: _fieldTexture,
                animationTime: _animationTime,
                child: _buildBackdropSource(),
              ),
            ),
            _buildPresentedChild(),
          ],
        );
    }
  }

  Widget _buildUnsupportedMessage() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildVisibleSceneWithoutEffect(),
        const Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: Color(0xA6141822))),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF1171C27),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Liquid refraction is unsupported on this platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This effect requires the mobile shader pipeline and currently supports only iOS and Android.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipBehavior: widget.clipBehavior,
      child: _MeasureSize(
        onChange: _handleSizeChanged,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerHover: _handlePointerMove,
          onPointerUp: (_) => _lastPointerPosition = null,
          onPointerCancel: (_) => _lastPointerPosition = null,
          child: _isSupportedPlatform
              ? _buildEffectScene()
              : _buildUnsupportedMessage(),
        ),
      ),
    );
  }

  double _randomBetween(double min, double max) {
    return min + ((max - min) * _random.nextDouble());
  }

  int _randomInt(int min, int max) {
    return min + _random.nextInt((max - min) + 1);
  }
}

class _AutoRainProfile {
  const _AutoRainProfile({
    required this.minInterval,
    required this.maxInterval,
    required this.defaultBurstCount,
    required this.minRadiusFactor,
    required this.maxRadiusFactor,
    required this.minStrength,
    required this.maxStrength,
    required this.minRippleCount,
    required this.maxRippleCount,
    required this.minTravelFactor,
    required this.maxTravelFactor,
  });

  final double minInterval;
  final double maxInterval;
  final int defaultBurstCount;
  final double minRadiusFactor;
  final double maxRadiusFactor;
  final double minStrength;
  final double maxStrength;
  final int minRippleCount;
  final int maxRippleCount;
  final double minTravelFactor;
  final double maxTravelFactor;
}

/// 通过渲染对象拿到布局后的真实尺寸。
///
/// 这里只在尺寸真正变化后回调一次，避免位移场在布局尚未稳定时反复重建，
/// 否则首帧阶段会重复分配网格和纹理，直接放大无意义的初始化成本。
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();

    final newSize = child?.size ?? size;
    if (_lastReportedSize == newSize) {
      return;
    }

    _lastReportedSize = newSize;
    // 这里不在布局阶段直接回调，是为了避开“父级还在继续布局，子级已经开始重建场”的节奏冲突。
    // 位移场一旦在布局链路中同步重建，很容易把本来只该发生一次的初始化放大成多次。
    // 放到下一帧再上报，虽然晚半拍，但尺寸会更稳定，也更符合这个组件的使用场景。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}
