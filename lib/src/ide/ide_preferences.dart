import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sidekick_core/sidekick_core.dart';
import 'package:yaml/yaml.dart';

/// A personal SDK selection, independent of the project's command SDK.
class IdeSelection {
  IdeSelection({this.mode = 'auto', this.value, required this.editors});

  final String mode;
  final String? value;
  final Set<String> editors;
}

/// Resolves workspace defaults and owns the personal IDE configuration policy.
class IdePreferences {
  IdePreferences({
    required this.projectRoot,
    required this.mainPackage,
    required this.packages,
    required this.storage,
    required this.resolvePackageSdk,
    required this.writeConfiguration,
  });

  final Directory projectRoot;
  final DartPackage? mainPackage;
  final List<DartPackage> packages;
  final Directory storage;
  final Future<String> Function(DartPackage) resolvePackageSdk;
  final Future<void> Function(Directory, String, Set<String>)
      writeConfiguration;

  Directory workspaceFor(Directory invocation) {
    final root = projectRoot.resolveSymbolicLinksSync();
    var dir = Directory(invocation.resolveSymbolicLinksSync());
    while (isWithin(root, dir.path)) {
      if (DartPackage.fromDirectory(dir) != null &&
          (dir.directory('.idea').existsSync() ||
              dir.directory('.vscode').existsSync())) {
        return dir;
      }
      dir = dir.parent;
    }
    return projectRoot;
  }

  DartPackage? defaultPackage(Directory workspace) {
    if (workspace.resolveSymbolicLinksSync() ==
        projectRoot.resolveSymbolicLinksSync()) {
      return mainPackage ??
          DartPackage.fromDirectory(projectRoot) ??
          (packages.length == 1 ? packages.single : null);
    }
    return DartPackage.fromDirectory(workspace);
  }

  File stateFile(Directory workspace) => storage.file(
        '${sha256.convert(utf8.encode(workspace.resolveSymbolicLinksSync()))}.yaml',
      );

  Map<String, String> configuration(Directory workspace) {
    final result = <String, String>{};
    for (final folder in ['.vscode', '.idea']) {
      final dir = workspace.directory(folder);
      if (!dir.existsSync()) {
        continue;
      }
      for (final file in dir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()) {
        // Only files that Puro may configure. IDE caches and window state
        // must not count as manual SDK changes.
        final name = relative(file.path, from: workspace.path);
        if (name == '.vscode/settings.json' ||
            name == '.idea/libraries/Dart_SDK.xml' ||
            name == '.idea/modules.xml' ||
            name.endsWith('.iml')) {
          result[name] = sha256.convert(file.readAsBytesSync()).toString();
        }
      }
    }
    return result;
  }

  YamlMap? read(Directory workspace) {
    final file = stateFile(workspace);
    if (!file.existsSync()) {
      return null;
    }
    final data = loadYaml(file.readAsStringSync());
    if (data is! YamlMap ||
        data['schema'] != 1 ||
        data['workspace'] != workspace.resolveSymbolicLinksSync()) {
      throw StateError('Invalid IDE preferences: ${file.path}');
    }
    return data;
  }

  IdeSelection? savedSelection(Directory workspace) {
    final data = read(workspace);
    if (data == null) {
      return null;
    }
    final mode = data['mode'];
    final value = data['value'];
    final editors = data['editors'];
    if (mode is! String ||
        !['auto', 'package', 'sdk'].contains(mode) ||
        (mode != 'auto' && value is! String) ||
        editors is! YamlList ||
        editors.isEmpty ||
        editors.any((e) => e != 'vscode' && e != 'intellij')) {
      throw StateError('Invalid IDE selection: ${stateFile(workspace).path}');
    }
    return IdeSelection(
      mode: mode,
      value: value is String ? value : null,
      editors: editors.cast<String>().toSet(),
    );
  }

  Set<String> detectedEditors(Directory workspace) => {
        if (workspace.directory('.vscode').existsSync()) 'vscode',
        if (workspace.directory('.idea').existsSync()) 'intellij',
      };

  Future<void> apply(Directory workspace, {IdeSelection? selection}) async {
    final explicit = selection != null;
    final saved = read(workspace);
    var effectiveSelection = selection ?? savedSelection(workspace);
    final current = configuration(workspace);
    if (!explicit) {
      if (saved != null) {
        final previous = saved['files'];
        if (previous is! YamlMap ||
            previous.length != current.length ||
            current.entries.any((e) => previous[e.key] != e.value)) {
          print(
              'Keeping manually changed IDE configuration in ${workspace.path}. '
              'Use puro ide to choose an SDK.');
          return;
        }
      } else {
        final settings = workspace.file('.vscode/settings.json');
        if (workspace.file('.idea/libraries/Dart_SDK.xml').existsSync() ||
            (settings.existsSync() &&
                RegExp(r'dart\.(flutterSdkPath|sdkPath)')
                    .hasMatch(settings.readAsStringSync()))) {
          print('Keeping existing IDE SDK in ${workspace.path}. '
              'Use puro ide to manage it.');
          return;
        }
      }
    }
    effectiveSelection ??= IdeSelection(editors: detectedEditors(workspace));
    if (effectiveSelection.editors.isEmpty) {
      print('No IDE configuration found in ${workspace.path}. '
          'Use puro ide --editor vscode or --editor intellij to set it up.');
      return;
    }
    String sdk;
    if (effectiveSelection.mode == 'sdk') {
      sdk = effectiveSelection.value!;
    } else {
      final package = effectiveSelection.mode == 'package'
          ? DartPackage.fromDirectory(
              projectRoot.directory(effectiveSelection.value!))
          : defaultPackage(workspace);
      if (package == null) {
        if (explicit || effectiveSelection.mode == 'package') {
          throw StateError(
              'No SDK package found. Select one with puro ide --package.');
        }
        print('No default IDE SDK package. Use puro ide --package <path>.');
        return;
      }
      sdk = await resolvePackageSdk(package);
    }
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(sdk)) {
      throw ArgumentError.value(sdk, 'sdk', 'Expected a Puro environment name');
    }
    await writeConfiguration(workspace, sdk, effectiveSelection.editors);
    final file = stateFile(workspace);
    file.parent.createSync(recursive: true);
    // JSON is a YAML subset; the YAML reader also permits hand-edited files.
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'workspace': workspace.resolveSymbolicLinksSync(),
      'mode': effectiveSelection.mode,
      'value': effectiveSelection.value,
      'editors': effectiveSelection.editors.toList()..sort(),
      'sdk': sdk,
      'files': configuration(workspace),
    }));
    print('IDE SDK: $sdk (${effectiveSelection.mode}) → ${workspace.path}');
  }
}
