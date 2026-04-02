# liquid_refraction_surface

[English](README.md) | [简体中文](README_ZH.md)

`liquid_refraction_surface` 是一个专注于环境氛围与高级物理特效的 Flutter 液态折射容器。
它可以将任何 Flutter `Widget` 无缝包裹，并在底层基于连续位移场和 Fragment Shader 实时接管光影、高光与色散的解算，为你提供极其真实、优雅的水面折射与流体互动体验。

## 效果预览

| 内容模式 (Content) | 背景模式 (Background) |
| --- | --- |
| <img src="https://raw.githubusercontent.com/ZyaireXv/liquid_refraction_surface/main/docs/content_mode.gif" alt="Content mode" width="320" /> | <img src="https://raw.githubusercontent.com/ZyaireXv/liquid_refraction_surface/main/docs/background_mode.gif" alt="Background mode" width="320" /> |

它是一套**可复用的高规格流体物理基座**。不管你是想让整个界面像水波一样荡漾，还是只想在常规内容底下铺一层灵动的液体背景，它都能优雅地实现：

- 渲染引擎与业务布局的双向配合，完全不影响原有的精准点击区域。
- 纯粹的 Shader 管线解算，在移动端兼顾高精度的流体连贯性与性能。
- 支持全屏以及任意局部容器的无缝嵌套。

## 核心亮点

- **`LiquidRefractionSurface`**：统一的调用入口，提供极其灵活的材质与物理参数开放。
- **两种透视模式**：支持 `content`（连同 Widget 一并折射）和 `background`（上层内容免受波段打扰，静置于水面之上）两种深度逻辑。
- **真实的物理微气候**：自带极强的互动性。无论是手指的一抹、轻点，还是开启内置的自动降雨（支持 `light`/`medium`/`heavy` 多挡雨势），它都能在底层生动推演出符合流体力学的连续涟漪和反弹扩散回波。
- **高自由度材质调配**：从基础的 `displacementScale` (空间扭曲力)、`metalness` (金属高光)，再到高级的 `chromaticAberration` (边缘色散) 和 `roughness` (表面柔化感)，都可以被任意调教，轻易产出诸如清澈冷泉、黏稠糖浆甚至极具厚重感的液态玻璃等独特效果。

## 安装指南

在工程的 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  liquid_refraction_surface: ^0.1.1
```

## 快速上手

### 1. 把整个界面投入水中 (Content 模式)

如果在海报展出或概念登录页中，你希望**整块内容**能伴随着手指的触碰发生光怪陆离的扭转和游弋，请大胆使用这种模式。

```dart
import 'package:flutter/material.dart';
import 'package:liquid_refraction_surface/liquid_refraction_surface.dart';

class ContentModeDemo extends StatelessWidget {
  const ContentModeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidRefractionSurface(
      placement: LiquidRefractionPlacement.content,
      backgroundColor: const Color(0xFF101B2A),
      config: const LiquidRefractionConfig(
        metalness: 0.12,
        roughness: 0.16,
        displacementScale: 1.72,
        cellSize: 16,
        highlightOpacity: 0.2,
        chromaticAberration: 0.08, // 开启轻微的色差弥散，质感拉满
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Text(
              'Liquid Refraction', 
              style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            Text(
              '轻点或划过水面，感受波纹反馈。', 
              style: TextStyle(color: Color(0xD9FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2. 局部沉浸式背景容器 (Background 模式)

当你想在核心的交互型卡片（例如个人中心、数据面板）下方，铺垫一层极具张力的流体背景，而不希望扰乱前景文字的识别度时，这种模式是最佳选择。

> **小贴士**：你可以通过往 `backdrop` 属性传入任意的渐变卡片、图片，甚至是其他复杂的视觉组件，`LiquidRefractionSurface` 会自动抓取这些底色信息，并为你算出惊艳的反射波光。

```dart
import 'package:flutter/material.dart';
import 'package:liquid_refraction_surface/liquid_refraction_surface.dart';

class BackgroundModeDemo extends StatelessWidget {
  const BackgroundModeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidRefractionSurface(
      placement: LiquidRefractionPlacement.background,
      backgroundColor: const Color(0xFF0F1824),
      backdrop: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF13263B), Color(0xFF0E1724)],
          ),
        ),
        child: const SizedBox.expand(),
      ),
      config: const LiquidRefractionConfig(
        metalness: 0.12,
        roughness: 0.16,
        displacementScale: 1.72,
        cellSize: 16,
        highlightOpacity: 0.2,
      ),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xD9FFFFFF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            '底部波涛汹涌，前台卡片依然稳如泰山。', 
            style: TextStyle(color: Color(0xFF121826), fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
```

## 进阶与调优配置

### 唤起一场淅淅沥沥的微雨

如果静态水面让你感到沉寂，完全可以通过配置唤起内置的“自然天气”系统。底层引擎不仅仅是在粗暴地定时刷新波纹，而是为从“稀疏小雨(`light`)”到“狂风暴雨(`heavy`)”规划了严密的节奏、单独水花的弹射波长与扩散强度。

```dart
const config = LiquidRefractionConfig(
  enableAutoDrops: true, 
  rainIntensity: LiquidRainIntensity.medium, // 设定中等强度的降雨节律
  // rainDropCount: 4, // 如果你有严苛的控制欲，可以通过此常数剥夺系统的智能接管权
);
```

### 理解连续位移场带来的阻尼黏连感

和使用离散的飘落粒子（例如 `ambient_effects_container` 的落雪与萤火虫）截然不同，液态折射背后的本质是一张通过计算搭建的能量拉扯拓扑网络。
正因如此，当你的手指数次来回划过水面，所有的横向拨动冲击波并不会各自为战，而是在网格拓扑模型中产生交汇、融合甚至衍生干涉驻波，这正是真实流体力学所该有的黏滞与反馈特性。

## 详细参数参考

### `LiquidRefractionSurface`

这是整个液态空间的核心舞台容器，承载着视图架构与逻辑的挂载：

| 属性参量 | 内在说明 |
| --- | --- |
| **`child`** | **必填项**。你需要保护或是被折射的那棵业务视图树。 |
| `placement` | 关键布局分支：`content` (同业务 UI 一并折射扭曲) 或是 `background` (只做为基底沉寂于下方)。 |
| `backdrop` | `background` 深度模式下极其核心的背景采样组件。强建议提供色彩丰富的渐变或图案，让波峰的高光质感显得通透。 |
| `backgroundColor` | 垫图方案的备用基础底色。 |
| `backgroundImage` | 用于兼容一些历史场景的底图参数。 |
| `config` | 掌控一切波浪手感、流控材质以及天气系统的综合配置项。 |

### `LiquidRefractionConfig`

精准微调流场表现的前线控制面板：

| 内部属性 | 魔法效果 |
| --- | --- |
| `displacementScale` | 空间扭曲力度。参数越大，透过水纹观察下方视界的折角与拉扯感越夸张。 |
| `metalness` | 金属质感，调节高后能显著增加反光的冷冽与干练，可做出“黑水胶”感。 |
| `roughness` | 控制表面柔化程度。越高的数值代表液面波纹消散得越自然平稳；数值小则显得锋锐且脆生。 |
| `chromaticAberration`| 边缘色散散列强度。能让受推挤的水流顶端透出一圈近乎赛博朋克一般的 RGB 彩虹弥散光晕。 |
| `cellSize` | 底层引擎推演物理位移的网格单元尺寸。数值越小意味着波澜计算越密集。 |
| `interactionRadius` | 手指点按或划过介入时，系统推演出的物理扰动波核心半径。 |
| `highlightOpacity` | 液面高光反光的能见度上限。 |
| `enableAutoDrops` | 是否开启自动全天候驻场的降雨拨动。 |
| `rainIntensity` / `rainDropCount` | 用来细分调节降雨的密集程度或者粗暴定量的参数组。 |

## 平台声明

本组件底层基于 Flutter 的 `FragmentProgram` + `AnimatedSampler` 着色器管线构建，这套管线在所有 Flutter 目标平台上均已提供支持：

- ✅ Android
- ✅ iOS
- ✅ Web (CanvasKit / skwasm)
- ✅ macOS
- ✅ Windows
- ✅ Linux

> **关于 Android 渲染后端的说明**：无论是 OpenGL ES 还是 Vulkan 后端，现在的坐标处理均已统一在着色器内部消化。无论设备支持哪种 Impeller 后端，水波效果和反馈位置都保持一致，不再出现坐标倒置的问题。

## 示例工程

仓库内包含一个开箱即用的交互式演练工程，存放在 `example/` 目录中。
十分建议你现在就将它运行起来，并在调试面板里畅快地用手指感受各种材质与流变效果。

```bash
cd example
flutter run
```
