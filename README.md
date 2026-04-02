# liquid_refraction_surface

[English](README.md) | [简体中文](README_ZH.md)

`liquid_refraction_surface` is a Flutter liquid refraction container dedicated to environmental atmospheres and advanced physical effects.
It can seamlessly wrap any Flutter `Widget` and take over the calculation of light, specular highlights, and chromatic aberration under the hood using a continuous displacement field and Fragment Shader in real-time. It provides you with an extremely realistic, elegant water surface refraction and fluid interaction experience.

## Effect Preview

| Content Mode | Background Mode |
| --- | --- |
| <img src="https://raw.githubusercontent.com/ZyaireXv/liquid_refraction_surface/main/docs/content_mode.gif" alt="Content mode" width="320" /> | <img src="https://raw.githubusercontent.com/ZyaireXv/liquid_refraction_surface/main/docs/background_mode.gif" alt="Background mode" width="320" /> |

It is a **reusable, high-spec fluid physics foundation**. Whether you want the entire interface to ripple like water, or just want to lay a vivid liquid background beneath your normal content, it handles both elegantly:

- Bi-directional coordination between the rendering engine and business layout, without affecting the original precise hit test areas.
- Pure Shader pipeline calculation, balancing high-precision fluid coherence and performance on mobile devices.
- Supports seamless nesting for both full-screen and any local containers.

## Core Highlights

- **`LiquidRefractionSurface`**: Unified entry point, offering extremely flexible material and physical parameters.
- **Two Perspective Modes**: Supports `content` (refracting the Widget together) and `background` (upper layer content remains undisturbed, resting stably above the water surface).
- **Realistic Physical Microclimate**: Comes with strong interactivity. Whether it's a swipe, a tap, or enabling the built-in automatic rain (supports `light`/`medium`/`heavy` rain intensities), it can vividly deduce continuous ripples and bouncing diffusion echoes that comply with fluid dynamics under the hood.
- **High-freedom Material Tuning**: From the basic `displacementScale` and `metalness` to the advanced `chromaticAberration` and `roughness`, everything can be freely tuned to easily produce unique effects such as a clear cold spring, viscous syrup, or even heavy liquid glass.

## Installation Guide

Add the following dependency in your project's `pubspec.yaml`:

```yaml
dependencies:
  liquid_refraction_surface: ^0.1.1
```


## Quick Start

### 1. Submerge the Entire Interface (Content Mode)

If you want the **entire content** to undergo bizarre twists and turns moving along with the user's touch (such as in poster displays or conceptual login pages), feel free to use this mode boldly.

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
        chromaticAberration: 0.08, // Enable slight chromatic dispersion for a premium feel
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
              'Tap or drag to disturb the surface.', 
              style: TextStyle(color: Color(0xD9FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2. Local Immersive Background Container (Background Mode)

When you want to lay a highly tense fluid background under core interactive cards (e.g., personal center, data panels) without disrupting the readability of foreground text, this mode is your best choice.

> **Tip**: You can pass any gradient card, image, or even other complex visual components directly into the `backdrop` property. `LiquidRefractionSurface` will automatically capture these background colors and calculate stunning reflective ripples for you.

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
            'The bottom is stormy, but the foreground card remains as stable as a mountain.', 
            style: TextStyle(color: Color(0xFF121826), fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
```

## Advanced & Tuning Configurations

### Summon a Pattering Drizzle

If a static water surface feels too quiet for you, you can easily awaken the built-in "natural weather" system through configurations. The underlying engine doesn't just roughly refresh ripples on a timer; it meticulously plans the rhythm, the bounce wavelength, and the diffusion intensity of individual water splashes ranging from a "sparse drizzle (`light`)" to a "heavy storm (`heavy`)".

```dart
const config = LiquidRefractionConfig(
  enableAutoDrops: true, 
  rainIntensity: LiquidRainIntensity.medium, // Set a medium-intensity rainfall rhythm
  // rainDropCount: 4, // If you have strict control desires, you can override the smart system with this constant
);
```

### Understanding the Damping Adhesion of a Continuous Displacement Field

Completely different from using discrete falling particles (like the snow and fireflies in `ambient_effects_container`), the essence behind liquid refraction is an energy-pulling topological network built through computational grids.
Because of this, when your finger swipes back and forth across the water surface multiple times, all the lateral disturbance shockwaves don't just act independently. Instead, they converge, merge, and even derive interference standing waves within the grid topology model. This is exactly the adhesion and feedback characteristics that true fluid mechanics should have.

## Detailed Parameter Reference

### `LiquidRefractionSurface`

This is the core stage container of the entire liquid space, hosting the view architecture and logic mounting:

| Property | Description |
| --- | --- |
| **`child`** | **Required**. The business view tree you need to protect or refract. |
| `placement` | Key layout branch: `content` (refracted and distorted along with the business UI) or `background` (acting solely as a silent base below). |
| `backdrop` | An extremely core background sampling component under the `background` depth mode. It is highly recommended to provide rich gradients or patterns to make the specular highlights of the wave crests appear transparent. |
| `backgroundColor` | The fallback base color for the backdrop. |
| `backgroundImage` | Used for backward compatibility with some historical base image scenarios. |
| `config` | The comprehensive configuration commander controlling all wave feels, flow materials, and the weather system. |

### `LiquidRefractionConfig`

The frontline control panel for precisely fine-tuning flow field performances:

| Property | Magic Effect |
| --- | --- |
| `displacementScale` | Spatial distortion strength. The larger the parameter, the more exaggerated the refraction angle and pulling sensation when observing the world beneath the water ripples. |
| `metalness` | Metallic feel. Tuning it high can significantly increase the coldness and crispness of reflections, creating a "black water gel" sensation. |
| `roughness` | Controls the level of surface softening. Higher values mean the liquid ripples dissipate more naturally and steadily; smaller values make it look sharp and brittle. |
| `chromaticAberration`| Edge dispersion scattering strength. Allows a somewhat cyberpunk-like RGB rainbow diffuse halo to show through the top of pushed water currents. |
| `cellSize` | The grid cell size used by the underlying engine to deduce physical displacement. Smaller numbers mean denser ripple calculations. |
| `interactionRadius` | The core radius of the physical disturbance wave deduced by the system when a finger taps or swipes across. |
| `highlightOpacity` | The maximum visibility limit for the liquid's specular reflections. |
| `enableAutoDrops` | Whether to enable continuous, automatic rainfall background disturbances. |
| `rainIntensity` / `rainDropCount` | Parameter group used to granularly adjust the rainfall density or forcefully quantify it. |

## Platform Declaration

The package uses the Flutter `FragmentProgram` + `AnimatedSampler` shader pipeline, which is supported across all Flutter targets:

- ✅ Android
- ✅ iOS
- ✅ Web (CanvasKit / skwasm)
- ✅ macOS
- ✅ Windows
- ✅ Linux

> **Note on Android backends**: Both OpenGL ES and Vulkan are handled correctly. Y-axis coordinate correction is applied entirely inside the shader, so behaviour is consistent regardless of which Impeller backend is selected.

## Example Project

The repository contains an out-of-the-box interactive demo project located in the `example/` directory.
It is highly recommended that you run it right now and freely use your fingers to feel the feedback arcs of various materials and flow effects in the debugging panel.

```bash
cd example
flutter run
```
