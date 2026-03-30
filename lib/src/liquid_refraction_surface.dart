import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'liquid_displacement_field.dart';
import 'liquid_field_texture.dart';
import 'liquid_refraction_config.dart';
import 'liquid_refraction_shader_layer.dart';

/// 液态折射舞台组件。
///
/// 这个包单独承接整屏位移场和折射表现，不复用粒子系统那套抽象。
/// 当前实现只保留移动端 shader 路线，避免同一套交互逻辑长期维护两套渲染结果。
class LiquidRefractionSurface extends StatefulWidget {
  const LiquidRefractionSurface({
    super.key,
    this.child,
    this.backgroundImage,
    this.backgroundColor,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.config = const LiquidRefractionConfig(),
  });

  /// 放在液态表面下方的内容。
  ///
  /// 参考项目里既有文字舞台，也有图片实验页。
  /// 这里先统一成 child，是为了避免一开始就把文字版和图片版拆成两套组件。
  final Widget? child;

  /// 直接作为底图输入的图片资源。
  ///
  /// 如果后续页面只需要图片折射，可以直接传这一个参数；
  /// 如果要做文字舞台，则由调用方先把文字排版成 child。
  final ImageProvider<Object>? backgroundImage;
  final Color? backgroundColor;
  final BoxFit fit;
  final Alignment alignment;
  final Clip clipBehavior;
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
  double _autoDropTime = 0.0;
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

    if (oldWidget.config.enableAutoDrops != widget.config.enableAutoDrops) {
      _autoDropEnabled = widget.config.enableAutoDrops;
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
      _autoDropTime += dt;
      final autoDropInterval = 0.9 + (widget.config.roughness * 0.7);
      if (_autoDropTime >= autoDropInterval) {
        _autoDropTime = 0.0;
        _injectDisturbance(
          Offset(
            _randomBetween(_size.width * 0.16, _size.width * 0.84),
            _randomBetween(_size.height * 0.16, _size.height * 0.84),
          ),
          strength: 0.22,
          isSplash: false,
        );
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
    _field.addImpulseTrail(
      previousPosition,
      position,
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

    _field.addImpulse(
      center,
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

  Widget _buildContent() {
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
        ...?(widget.child == null ? null : <Widget>[widget.child!]),
      ],
    );
  }

  Widget _buildUnsupportedMessage() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildContent(),
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
    final content = _buildContent();

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
              ? LiquidRefractionShaderLayer(
                  config: widget.config,
                  fieldTexture: _fieldTexture,
                  animationTime: _animationTime,
                  child: content,
                )
              : _buildUnsupportedMessage(),
        ),
      ),
    );
  }

  double _randomBetween(double min, double max) {
    return min + ((max - min) * _random.nextDouble());
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}
