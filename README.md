# liquid_refraction_surface

一个专门用于实现液态折射舞台的 Flutter 包。

当前仓库只服务这一类效果，不混入雨雪粒子、场景容器或其它展示组件。范围收紧以后，后续实现位移场、折射采样、色散和高光时，代码边界会更清楚。

## 当前阶段

当前已经完成首个可运行原型：

- `LiquidRefractionSurface` 可直接包裹图片或任意静态内容
- 支持鼠标移动、拖拽、点击打出波纹
- 已接入位移扭曲、高光覆盖和可选色散
- 已切换到移动端 shader 主路径，不再保留 CPU 渲染分支
- 已提供 `example/` 调参演示页

当前实现取舍：

- 当前版本采用“连续位移场 + fragment shader 折射采样”
- 位移场仍由 Dart 侧更新，再编码成纹理喂给 shader
- 后续重点是继续打磨法线、高光和材质层次，不再维护双渲染分支

## 目录结构

```text
lib/
  liquid_refraction_surface.dart
  src/
    liquid_refraction_config.dart
    liquid_displacement_field.dart
    liquid_field_texture.dart
    liquid_refraction_shader_layer.dart
    liquid_refraction_surface.dart
docs/
  implementation_plan.md
example/
  lib/main.dart
```

## 使用方式

```dart
LiquidRefractionSurface(
  backgroundColor: const Color(0xFFF5F5F5),
  config: const LiquidRefractionConfig(
    metalness: 0.35,
    roughness: 0.45,
    displacementScale: 2,
    chromaticAberration: 0.18,
    cellSize: 18,
    highlightOpacity: 0.14,
  ),
  child: const Center(
    child: Text(
      'Liquid Refraction',
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
)
```

## 当前参数

- `metalness`：控制表面高光和镜面感
- `roughness`：控制表面柔化程度
- `displacementScale`：控制扭曲幅度
- `chromaticAberration`：控制色散强度
- `cellSize`：控制位移场网格密度
- `highlightOpacity`：控制液面高光覆盖强度
- `enableAutoDrops`：控制是否自动注入随机波纹

## 当前限制

- 当前仅支持 `iOS` 和 `Android`
- 不支持的平台会直接显示错误提示，不再回退到 CPU 路径
- 当前版本已经具备连续位移场和 shader 折射，但材质层次仍在继续调整

## 运行示例

```bash
cd /Volumes/data/Git/liquid_refraction_surface/example
flutter run
```

## 开发

```bash
cd /Volumes/data/Git/liquid_refraction_surface
flutter test
flutter analyze
```
