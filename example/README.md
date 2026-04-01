# example

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android backend override

This example can force the Android Impeller backend in `debug` and `profile`
builds so it is easier to reproduce rendering differences between `OpenGLES`
and `Vulkan`.

When the example runs on Android in `debug` or `profile`, the screen shows a
top-right banner with the current requested backend mode:

- `AUTO`: let Flutter choose the backend.
- `VULKAN`: request Vulkan for this debug/profile build.
- `OPENGL ES`: request OpenGLES for this debug/profile build.

The banner reads the value from the Android manifest at runtime, so it reflects
the build configuration that is actually installed on the device instead of a
manually duplicated Dart-side label.

Keep the default auto-selection:

```bash
flutter run
```

Force `Vulkan`:

```bash
flutter run --android-project-arg=impellerBackend=vulkan
```

Force `OpenGLES`:

```bash
flutter run --android-project-arg=impellerBackend=opengles
```

The override is only wired into the Android `debug` and `profile` manifests.
`release` builds continue to use Flutter's normal backend selection.
