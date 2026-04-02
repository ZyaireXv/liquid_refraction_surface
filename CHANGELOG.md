## 0.1.1

- Fixed Android coordinate handling: moved Y-axis correction entirely into the shader, eliminating per-backend mismatches between Vulkan and OpenGL ES devices
- Removed the `_mapPointerToFieldSpace` pass-through wrapper that no longer served a purpose after the coordinate fix
- Expanded platform support to Web (CanvasKit / skwasm), macOS, Windows, and Linux — all platforms supported by `FragmentProgram` + `AnimatedSampler` are now enabled
- Aligned the `kReleaseMode` guard in the example app's debug backend badge so the channel is not called in release builds

## 0.1.0

- Reworked the package around two stable layouts: `content` and `background`
- Added shader-driven content refraction and responsive background refraction
- Added automatic rain ripples with `light`, `medium`, and `heavy` intensity presets
- Added manual rain burst count override for automatic rain mode
- Improved Android coordinate handling so ripple input matches the visual position
- Refined the example app with image-based demos, settings controls, and interactive content mode


