# Puro Sidekick Plugin

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

### Workspace

You can add `resolution: workspace` to your package-level `pubspec.yaml` to always use the Flutter and Dart versions from the root `pubspec.yaml`.

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