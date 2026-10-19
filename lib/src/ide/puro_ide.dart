import 'dart:convert';

import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/ide/ide_preferences.dart';
import 'package:puro_sidekick_plugin/src/version_parser.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Register as `addAfterDepsHook(configurePuroIde)`.
/// Personal IDE choices never affect SDK selection for Sidekick commands.
Future<void> configurePuroIde(AfterDepsContext context) async {
  if (!context.isSuccess) {
    return;
  }
  final preferences = createIdePreferences(
    SidekickContext.projectRoot,
    mainProject,
  );
  await preferences.apply(preferences.workspaceFor(entryWorkingDirectory));
}

IdePreferences createIdePreferences(Directory root, DartPackage? mainPackage) {
  return IdePreferences(
    projectRoot: root,
    mainPackage: mainPackage,
    packages: findAllPackages(root)
        .where((p) => p.root.path != SidekickContext.sidekickPackage.root.path)
        .toList(),
    storage: Directory(dcli.HOME).directory('.config/sidekick/puro-ide'),
    resolvePackageSdk: (package) async {
      final versions = await VersionParser(
        packagePath: package.root,
        projectRoot: root,
        useBeta: true,
      ).getMaxFlutterSdkVersionFromPubspec();
      return versions.flutterVersion.toString();
    },
    writeConfiguration: writePuroIdeConfiguration,
  );
}

/// Let Puro edit copies, then publish only IDE files. `puro use` also changes
/// .puro.json and .gitignore; those must not change the project's command SDK.
Future<void> writePuroIdeConfiguration(
  Directory workspace,
  String sdk,
  Set<String> editors,
) async {
  final executable = getPuroPath();
  if (executable == null) {
    throw StateError(
        'Puro is not installed. Run a Flutter/Dart command first.');
  }
  final stage = Directory.systemTemp.createTempSync('sidekick_ide_');
  final environment = executable.parent.parent.directory('envs/$sdk/flutter');
  try {
    final roots = [
      if (editors.contains('vscode')) '.vscode',
      if (editors.contains('intellij')) '.idea',
    ];
    final originals = <String, List<int>>{};
    for (final root in roots) {
      final source = workspace.directory(root);
      if (FileSystemEntity.isLinkSync(source.path)) {
        throw StateError(
            'IDE configuration directory is a symlink: ${source.path}');
      }
      stage.directory(root).createSync();
      if (!source.existsSync()) {
        continue;
      }
      for (final entity
          in source.listSync(recursive: true, followLinks: false)) {
        if (entity is Link) {
          throw StateError(
              'IDE configuration contains a symlink: ${entity.path}');
        }
        if (entity is File) {
          final name = relative(entity.path, from: workspace.path);
          originals[name] = entity.readAsBytesSync();
          stage.file(name)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(originals[name]!);
        }
      }
    }
    if (editors.contains('intellij')) {
      for (final file in workspace
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.iml'))) {
        final name = basename(file.path);
        originals[name] = file.readAsBytesSync();
        stage.file(name).writeAsBytesSync(originals[name]!);
      }
    }
    await dcli.withEnvironmentAsync(() async {
      dcli.env['PURO_FLUTTER_BIN'] = null;
      dcli.env['PURO_ROOT'] = executable.parent.parent.path;
      if (!environment.existsSync()) {
        await puro(['create', sdk, sdk], progress: Progress.print());
      }
      await puro([
        'use',
        '--project',
        stage.path,
        if (editors.contains('vscode')) '--vscode' else '--no-vscode',
        if (editors.contains('intellij')) '--intellij' else '--no-intellij',
        sdk,
      ], progress: Progress.print());
    }, environment: {});
    for (final editor in editors) {
      final expected = editor == 'vscode'
          ? '.vscode/settings.json'
          : '.idea/libraries/Dart_SDK.xml';
      if (!stage.file(expected).existsSync()) {
        throw StateError('Puro did not generate $expected; IDE setup failed.');
      }
    }
    // Puro can report an optional IDE setup failure without a nonzero exit.
    // Validate the generated SDK paths, even when the stage had an old config.
    if (editors.contains('vscode')) {
      final settings = stage.file('.vscode/settings.json').readAsStringSync();
      for (final entry in {
        'dart.flutterSdkPath': environment.path,
        'dart.sdkPath': environment.directory('bin/cache/dart-sdk').path,
      }.entries) {
        final expected =
            RegExp('${RegExp.escape(jsonEncode(entry.key))}\\s*:\\s*'
                '${RegExp.escape(jsonEncode(entry.value))}');
        if (!expected.hasMatch(settings)) {
          throw StateError('Puro did not configure ${entry.key} for $sdk.');
        }
      }
    }
    if (editors.contains('intellij')) {
      final xml = stage.file('.idea/libraries/Dart_SDK.xml').readAsStringSync();
      final sdkUri =
          Uri.directory(environment.directory('bin/cache/dart-sdk/lib').path)
              .toString();
      final home = canonicalize(dcli.HOME).replaceAll('\\', '/');
      final homeRelative = sdkUri.replaceAll(home, r'$USER_HOME$');
      if (!xml.contains(sdkUri) && !xml.contains(homeRelative)) {
        throw StateError('Puro did not configure the IntelliJ SDK for $sdk.');
      }
    }
    // Check for concurrent edits before writing any result.
    for (final entry in originals.entries) {
      final file = workspace.file(entry.key);
      if (!file.existsSync() ||
          !_sameBytes(file.readAsBytesSync(), entry.value)) {
        throw StateError(
            'IDE configuration changed during setup: ${file.path}');
      }
    }
    for (final root in roots) {
      for (final file in stage
          .directory(root)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()) {
        if (file.path.endsWith('.bak')) {
          continue;
        }
        final name = relative(file.path, from: stage.path);
        final bytes = file.readAsBytesSync();
        if (!_sameBytes(bytes, originals[name])) {
          workspace.file(name)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(bytes);
        }
      }
    }
    for (final name in originals.keys.where((n) => n.endsWith('.iml'))) {
      final updated = stage.file(name).readAsBytesSync();
      if (!_sameBytes(updated, originals[name])) {
        workspace.file(name).writeAsBytesSync(updated);
      }
    }
  } finally {
    stage.deleteSync(recursive: true);
  }
}

bool _sameBytes(List<int> a, List<int>? b) {
  if (b == null || a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
