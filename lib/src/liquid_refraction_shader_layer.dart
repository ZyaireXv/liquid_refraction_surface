import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'liquid_refraction_config.dart';

const String _shaderAssetKey =
    'packages/liquid_refraction_surface/shaders/liquid_refraction.frag';

// 这里把 uniform 下标和 shader 变量名一一对应写清楚。
// FragmentShader 的绑定完全靠顺序，没有运行时校验。
// 一旦 .frag 里调整了 uniform 声明顺序，而这里没有同步改，画面会直接错乱，
// 但调试时只会看到“效果不对”，很难第一时间定位到是绑定错位。
const int _uSizeXIndex = 0;
const int _uSizeYIndex = 1;
const int _uTimeIndex = 2;
const int _uDisplacementScaleIndex = 3;
const int _uHighlightOpacityIndex = 4;
const int _uChromaticAberrationIndex = 5;
const int _uMetalnessIndex = 6;
const int _uRoughnessIndex = 7;

const int _uTextureSamplerIndex = 0;
const int _uFieldSamplerIndex = 1;

/// 基于 fragment shader 的液态折射层。
///
/// 这里不再自己截图 child，而是直接复用 `AnimatedSampler`。
/// 这样 GPU 路线的输入和输出都收敛在同一层里，后面继续加 sampler 或 uniform 时更容易维护。
class LiquidRefractionShaderLayer extends StatelessWidget {
  const LiquidRefractionShaderLayer({
    super.key,
    required this.child,
    required this.config,
    required this.fieldTexture,
    required this.animationTime,
  });

  final Widget child;
  final LiquidRefractionConfig config;
  final ui.Image? fieldTexture;
  final double animationTime;

  @override
  Widget build(BuildContext context) {
    final fieldTexture = this.fieldTexture;
    if (fieldTexture == null) {
      return child;
    }

    return ShaderBuilder(assetKey: _shaderAssetKey, child: child, (
      BuildContext context,
      ui.FragmentShader shader,
      Widget? child,
    ) {
      final shaderChild = child;
      if (shaderChild == null) {
        return const SizedBox.shrink();
      }

      return AnimatedSampler(enabled: true, (
        ui.Image image,
        Size size,
        Canvas canvas,
      ) {
        shader
          ..setFloat(_uSizeXIndex, size.width)
          ..setFloat(_uSizeYIndex, size.height)
          ..setFloat(_uTimeIndex, animationTime)
          ..setFloat(_uDisplacementScaleIndex, config.displacementScale)
          ..setFloat(_uHighlightOpacityIndex, config.highlightOpacity)
          ..setFloat(
            _uChromaticAberrationIndex,
            config.chromaticAberration,
          )
          ..setFloat(_uMetalnessIndex, config.metalness)
          ..setFloat(_uRoughnessIndex, config.roughness)
          ..setImageSampler(
            _uTextureSamplerIndex,
            image,
            filterQuality: FilterQuality.medium,
          )
          ..setImageSampler(
            _uFieldSamplerIndex,
            fieldTexture,
            filterQuality: FilterQuality.medium,
          );

        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      }, child: shaderChild);
    });
  }
}
