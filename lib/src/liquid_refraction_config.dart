/// 液态折射效果的基础参数。
///
/// 第一版先把已经从参考项目里验证过、并且能直观看出差异的参数收进来。
/// 这样后面接更重的渲染实现时，外部调用方式可以保持稳定，不需要一边写实现一边改 API。
class LiquidRefractionConfig {
  const LiquidRefractionConfig({
    this.metalness = 0.35,
    this.roughness = 0.45,
    this.displacementScale = 2.0,
    this.chromaticAberration = 0.0,
    this.enableAutoDrops = false,
    this.cellSize = 18.0,
    this.interactionRadius = 86.0,
    this.highlightOpacity = 0.14,
  });

  /// 金属感越高，反射高光越强，更接近液态金属或镜面质感。
  final double metalness;

  /// 粗糙度越低，折射表面越锐利；值越高，表面会更雾、更散。
  final double roughness;

  /// 位移幅度决定折射扭曲的强弱。
  ///
  /// 这个值后面会直接参与位移场采样，所以保留和参考实现一致的命名，
  /// 避免迁移时同一个概念在不同代码里出现两套说法。
  final double displacementScale;

  /// 色散强度，主要控制 RGB 偏移的幅度。
  ///
  /// 参考项目把这层效果单独叠在图片版上，这里先保留参数入口，
  /// 后续实现时可以根据平台能力决定是走 shader 还是额外的后处理层。
  final double chromaticAberration;

  /// 是否自动注入随机波纹。
  ///
  /// 默认关闭，是因为这个包的核心是“交互式液态折射”。
  /// 自动落滴更像附加氛围，不应该先于手势反馈成为默认行为。
  final bool enableAutoDrops;

  /// 采样网格尺寸。
  ///
  /// 这里控制的是位移场网格密度，不是屏幕像素级精度。
  /// 值越小，液面细节越丰富；值越大，场更新成本越低，但局部变化会更钝一些。
  final double cellSize;

  /// 单次交互影响范围。
  ///
  /// 这里不直接叫“波纹半径”，是因为后面接真实位移场时，
  /// 它既会影响初始波峰宽度，也会影响拖动时的扰动覆盖范围。
  final double interactionRadius;

  /// 高光覆盖强度。
  ///
  /// 折射如果只有位移，没有一点表面高光，画面会更像热浪扭曲，
  /// 不像一层有厚度的液体。
  final double highlightOpacity;

  LiquidRefractionConfig copyWith({
    double? metalness,
    double? roughness,
    double? displacementScale,
    double? chromaticAberration,
    bool? enableAutoDrops,
    double? cellSize,
    double? interactionRadius,
    double? highlightOpacity,
  }) {
    return LiquidRefractionConfig(
      metalness: metalness ?? this.metalness,
      roughness: roughness ?? this.roughness,
      displacementScale: displacementScale ?? this.displacementScale,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      enableAutoDrops: enableAutoDrops ?? this.enableAutoDrops,
      cellSize: cellSize ?? this.cellSize,
      interactionRadius: interactionRadius ?? this.interactionRadius,
      highlightOpacity: highlightOpacity ?? this.highlightOpacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LiquidRefractionConfig &&
            other.metalness == metalness &&
            other.roughness == roughness &&
            other.displacementScale == displacementScale &&
            other.chromaticAberration == chromaticAberration &&
            other.enableAutoDrops == enableAutoDrops &&
            other.cellSize == cellSize &&
            other.interactionRadius == interactionRadius &&
            other.highlightOpacity == highlightOpacity;
  }

  @override
  int get hashCode => Object.hash(
    metalness,
    roughness,
    displacementScale,
    chromaticAberration,
    enableAutoDrops,
    cellSize,
    interactionRadius,
    highlightOpacity,
  );
}
