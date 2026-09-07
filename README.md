# Puro Sidekick Plugin

[![pub package](https://img.shields.io/pub/v/puro_sidekick_plugin.svg)](https://pub.dev/packages/puro_sidekick_plugin)

This is a plugin for [phntmxyz/sidekick](https://github.com/phntmxyz/sidekick) that integrates with [`puro`](https://github.com/pingbird/puro) to manage Flutter versions. It provides three commands through the Sidekick CLI:

- `<cli> flutter` - Executes the Flutter version managed by Puro
- `<cli> dart` - Executes the Dart version managed by Puro
- `<cli> puro` - Executes Puro

The `flutterSdkPath:` binds the current Puro environment SDK, allowing the `flutter()` and `dart()` functions in your scripts to use the pinned versions. If you prefer, you can use `puro()` for explicitness.

## Installation

Install the plugin with the following command:

```bash
<cli> sidekick plugins install puro_sidekick_plugin
```

After installation, the plugin is available in the Sidekick CLI.
Afterward it will check if `puro` is installed already, if not it will aks you to install `puro` globally
or if you want to use it locally for the current project.

```bash
~/project master > <cli> flutter --version                                                                                                                   5s
Puro is not installed.
Do you want to install Puro global? (y/n) [n] 
```

## Usage

When you execute `flutter`, `dart`, or `puro`, the plugin uses the `pubspec.yaml` file in the current directory to determine the Flutter and Dart versions for the Puro environment. It sets up the Puro environment and then runs the command. If you execute these commands in a package directory, it uses that package's `pubspec.yaml` to set up the Puro environment.

The plugin interprets Flutter and Dart version constraints and defaults to the minimum version if a range is provided.

```yaml
name: package_name

environment:
  sdk: '>=3.3.0 <4.0.0'
```

```bash
<cli> flutter --version // Outputs Flutter version 3.10.6
<cli> puro flutter --version // Also outputs Flutter version 3.10.6
```

You can also specify a particular Flutter version.

```yaml
name: package_name

environment:
  flutter: '^3.19.6'
  sdk: '>=3.3.0 <4.0.0'
```

```bash
<cli> flutter --version // Outputs Flutter version 3.19.6
```

### Preferred Version for Pub Packages

When developing pub packages that support a wide range of Flutter/Dart versions, you often want to use a specific version for linting and formatting while maintaining broad compatibility. Use `sidekick.puro.useFlutterSdk` or `sidekick.puro.useDartSdk` to pin an exact version for tooling without affecting your package's version constraints:

```yaml
name: my_pub_package

sidekick:
  puro:
    useFlutterSdk: '3.22.1'  # Used by puro for linting/formatting

environment:
  flutter: '>=3.0.0 <4.0.0'  # Broad support range for package users
  sdk: '>=3.0.0 <4.0.0'
```

```bash
<cli> flutter --version // Outputs Flutter version 3.22.1 (from useFlutterSdk)
<cli> dart format .     // Uses Dart 3.4.1 (bundled with Flutter 3.22.1)
```

You can also use `useDartSdk` if you only need to pin the Dart version:

```yaml
name: my_dart_package

sidekick:
  puro:
    useDartSdk: '3.4.1'      # Used by puro for linting/formatting

environment:
  sdk: '>=3.0.0 <4.0.0'      # Broad support range for package users
```

**Priority order:**

1. `sidekick.puro.useFlutterSdk` (highest - overrides everything)
2. `flutter`
3. `sidekick.puro.useDartSdk`
4. `sdk` (lowest)

**Note:** `useFlutterSdk` and `useDartSdk` must be exact versions (e.g., `'3.22.1'`), not ranges. Using a range like `'^3.22.0'` will result in an error.

### Workspace

You can add `resolution: workspace` to your package-level `pubspec.yaml` to always use the Flutter and Dart versions from the root `pubspec.yaml`.

### Personal IDE SDK

Requires the Sidekick `addAfterDepsHook` API, merged and awaiting the sidekick_core 3.2.0 release.
Plugin installation registers its hook alongside the SDK initializer.
For an existing CLI, register it explicitly:

```dart
addAfterDepsHook(configurePuroIde);
runner.addCommand(DepsCommand());
```

`<cli> deps` configures a detected IDE workspace after all selected packages have fetched dependencies successfully.
The repository workspace follows `mainProject`; a standalone package workspace follows its own requirements.
Existing manually configured SDKs are preserved until you explicitly opt in.

```bash
<cli> puro ide                             # Interactive workspace and SDK choice
<cli> puro ide --status                    # Show the saved choice
<cli> puro ide --package packages/app      # Follow this package's requirements
<cli> puro ide --sdk 3.47.1                 # Pin an experimental SDK/environment
<cli> puro ide --reset                     # Follow the default package again
<cli> puro ide --workspace packages/lib --reset --editor intellij
```

`--workspace` and `--package` are paths relative to the repository root.
Choose `--editor vscode`, `--editor intellij` (also Android Studio), or `--editor both` when the workspace has no existing IDE configuration.
Non-interactive terminals require an explicit choice.

Automatic workspace detection uses the invocation directory and existing `.idea` or `.vscode` folders.
It cannot identify a live IDE window; use `--workspace` when you opened a different folder, or when multiple workspace roots are involved.
VS Code `.code-workspace` files are not edited by this command.

Choices are personal and stored outside the repository under `~/.config/sidekick/puro-ide/`, keyed by the workspace's resolved path.
A package choice tracks its requirements; a named SDK stays selected across `deps` runs.
Root and standalone package workspaces have independent choices.
Manual changes to managed IDE settings are preserved; run `puro ide` again to resume management.
`deps --package` filters dependency fetching, not the IDE SDK choice.

The plugin asks Puro to generate IDE configuration in an isolated directory and copies the IDE files back.
Personal SDK selection does not change `.puro.json`, `pubspec.yaml`, or the SDK used by Sidekick's `dart`/`flutter` commands.
The global deps hook receives per-package results even after failures; this plugin checks `context.isSuccess` and skips IDE setup when dependency fetching failed.
IDE setup errors fail `deps` instead of being silently ignored.

See [the local demo](example/IDE_DEMO.md) for a complete example using both local packages before releasing the Sidekick API.

### Debugging

Something seems fishy?
You can enable debug logging for the plugin by setting the `PURO_SIDEKICK_PLUGIN_VERBOSE` environment variable to `true`:

```bash
export PURO_SIDEKICK_PLUGIN_VERBOSE=true
```

## License

```
Copyright 2024 PHNTM GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
