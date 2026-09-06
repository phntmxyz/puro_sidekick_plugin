import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Disposable end-to-end demo. Run with a workspace path and CLI arguments:
/// dart run example/ide_demo.dart /tmp/sidekick-ide-demo deps
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError('Supply a disposable demo directory and a command.');
  }
  final root = Directory(args.first).absolute;
  final marker = root.file('.sidekick-ide-demo');
  if (!marker.existsSync()) {
    if (root.existsSync() && root.listSync().isNotEmpty) {
      throw StateError(
          'Refusing to initialize a nonempty directory: ${root.path}');
    }
    root.createSync(recursive: true);
    marker.writeAsStringSync('Disposable Sidekick/Puro IDE demo\n');
    final git = await Process.run('git', ['init', '-q', root.path]);
    if (git.exitCode != 0) {
      throw StateError('Cannot initialize demo git repository');
    }
    for (final entry in {'app': '3.32.8', 'library': '3.27.4'}.entries) {
      final package = root.directory('packages/${entry.key}')
        ..createSync(recursive: true);
      package.file('pubspec.yaml').writeAsStringSync('''
name: demo_${entry.key}
environment:
  sdk: '>=3.6.0 <4.0.0'
sidekick:
  puro:
    useFlutterSdk: '${entry.value}'
''');
    }
    root.file('demo').writeAsStringSync('#!/bin/sh\n');
    root.file('tool/demo_sidekick/pubspec.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
name: demo_sidekick
environment:
  sdk: '>=3.6.0 <4.0.0'
sidekick:
  cli_version: 3.1.1
''');
    root.directory('.vscode').createSync();
    root.file('.vscode/settings.json').writeAsStringSync(
        '{\n  // A personal setting that must survive SDK setup\n  "editor.tabSize": 4\n}\n');
    root.directory('packages/library/.vscode').createSync();
    root.file('.puro.json').writeAsStringSync('{"env":"3.27.4"}\n');
  }
  final canonicalRoot = Directory(root.resolveSymbolicLinksSync());
  final invocation = dcli.env['SIDEKICK_IDE_DEMO_CWD'];
  Directory.current = invocation == null
      ? canonicalRoot
      : isAbsolute(invocation)
          ? Directory(invocation)
          : canonicalRoot.directory(invocation);
  dcli.env['SIDEKICK_PACKAGE_HOME'] =
      canonicalRoot.directory('tool/demo_sidekick').path;
  dcli.env['SIDEKICK_ENTRYPOINT_HOME'] = canonicalRoot.path;
  dcli.env['SIDEKICK_ENTRYPOINT_FILE'] = canonicalRoot.file('demo').path;
  dcli.env['SIDEKICK_ENABLE_UPDATE_CHECK'] = 'false';
  final runner = initializeSidekick(
    mainProjectPath: 'packages/app',
    flutterSdkPath: flutterSdkSymlink(),
  );
  addSdkInitializer(initializePuro);
  addDepsHook(configurePuroIde);
  runner
    ..addCommand(DepsCommand())
    ..addCommand(PuroCommand());
  await runner.run(args.skip(1));
}
