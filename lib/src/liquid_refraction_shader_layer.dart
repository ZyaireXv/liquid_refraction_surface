import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'liquid_refraction_config.dart';

const String _shaderAssetKey =
    'packages/liquid_refraction_surface/shaders/liquid_refraction.frag';

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
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, animationTime)
          ..setFloat(3, config.displacementScale)
          ..setFloat(4, config.highlightOpacity)
          ..setFloat(5, config.chromaticAberration)
          ..setFloat(6, config.metalness)
          ..setFloat(7, config.roughness)
          ..setImageSampler(0, image, filterQuality: FilterQuality.medium)
          ..setImageSampler(
            1,
            fieldTexture,
            filterQuality: FilterQuality.medium,
          );

        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      }, child: shaderChild);
    });
  }
}
