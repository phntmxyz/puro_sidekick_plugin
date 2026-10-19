# Local Sidekick + Puro IDE demo

This demo uses real `DepsCommand`, `initializePuro`, and Puro IDE generation in a disposable project.
It never opens an IDE or changes another project's settings.

## Local dependency setup

The Sidekick global `addAfterDepsHook` API is merged but not yet released.
The plugin requires the release that carries it, planned as 3.2.0.
Until then, use a local `pubspec_overrides.yaml` pointing at a Sidekick checkout on `main`:

```yaml
dependency_overrides:
  sidekick_core:
    path: ../sidekick/sidekick_core
```

From this plugin checkout, run `dart pub get`.
Use Dart 3.8 for the repository's lint and formatting conventions.
Puro must already be installed; the demo can download missing Flutter environments.

## Try it

```bash
dart run example/ide_demo.dart /tmp/sidekick-ide-demo deps
dart run example/ide_demo.dart /tmp/sidekick-ide-demo puro ide --sdk 3.47.1
dart run example/ide_demo.dart /tmp/sidekick-ide-demo deps
dart run example/ide_demo.dart /tmp/sidekick-ide-demo puro ide --status

# Configure the library opened on its own, independently of the root workspace.
dart run example/ide_demo.dart /tmp/sidekick-ide-demo puro ide --workspace packages/library --reset --editor both
SIDEKICK_IDE_DEMO_CWD=packages/library dart run example/ide_demo.dart /tmp/sidekick-ide-demo deps

# Interactive selection, or restore the repository's default:
dart run example/ide_demo.dart /tmp/sidekick-ide-demo puro ide
dart run example/ide_demo.dart /tmp/sidekick-ide-demo puro ide --reset
```

The app uses Flutter 3.32.8 (Dart 3.8.1); the library uses Flutter 3.27.4 (Dart 3.6.2).
The default root IDE SDK is 3.32.8.
After explicitly selecting 3.47.1, `deps` still executes each package's own SDK and leaves the root IDE on 3.47.1.
The standalone library IDE stays on 3.27.4.

Inspect `.vscode/settings.json` at the root and in `packages/library`, plus `packages/library/.idea/libraries/Dart_SDK.xml`.
The root JSONC comment and `editor.tabSize` setting survive configuration.
The root `.puro.json` remains on 3.27.4 regardless of the personal IDE choice.

Personal demo preferences live outside this project, under the path printed by `puro ide --status`.
Remove that specific file if you want to repeat initial setup.
Use a new empty demo directory for a completely fresh run.
