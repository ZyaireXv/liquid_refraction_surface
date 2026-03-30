import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'liquid_displacement_field.dart';

/// 把连续位移场编码成 shader 可采样的小纹理。
///
/// 当前把法线近似、局部运动强度和液面高度一起写进 RGBA。
/// 这样 shader 不只能拿到“朝哪边偏”和“鼓起了多少”，
/// 还能区分出哪些区域正在快速运动，方便把亮痕和高光跟拖动节奏绑在一起。
class LiquidFieldTextureBuilder {
  LiquidFieldTextureBuilder._();

  /// 直接把场数据写进 RGBA 缓冲区，再交给引擎解码成图像。
  ///
  /// 这里不用 `Canvas.drawRect` 一格一格画，是因为位移场会在动画阶段频繁更新。
  /// 如果继续走录制 `Picture` 的路径，CPU 时间会被大量消耗在矢量绘制上，
  /// 和这类“本质是字节纹理”的数据结构并不匹配。
  static Future<ui.Image?> build(LiquidDisplacementField field) async {
    if (!field.isReady) {
      return null;
    }

    final width = field.columns;
    final height = field.rows;
    final pixels = Uint8List(width * height * 4);
    var byteOffset = 0;

    for (var row = 0; row < field.rows; row++) {
      for (var column = 0; column < field.columns; column++) {
        final sample = field.sampleAtCell(column, row);
        final encodedNormalX = ((sample.offset.dx * 0.5) + 0.5).clamp(0.0, 1.0);
        final encodedNormalY = ((sample.offset.dy * 0.5) + 0.5).clamp(0.0, 1.0);
        final encodedSpeed = sample.speed.clamp(0.0, 1.0);
        final encodedHeight = ((sample.height * 0.5) + 0.5).clamp(0.0, 1.0);

        pixels[byteOffset] = (encodedNormalX * 255).round().clamp(0, 255);
        pixels[byteOffset + 1] = (encodedNormalY * 255).round().clamp(0, 255);
        pixels[byteOffset + 2] = (encodedSpeed * 255).round().clamp(0, 255);
        pixels[byteOffset + 3] = (encodedHeight * 255).round().clamp(0, 255);
        byteOffset += 4;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (
      ui.Image image,
    ) {
      completer.complete(image);
    }, rowBytes: width * 4);
    return completer.future;
  }
}
