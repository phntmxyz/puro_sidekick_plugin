import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/src/ide/ide_preferences.dart';
import 'package:puro_sidekick_plugin/src/ide/puro_ide.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Personal IDE SDK configuration; invoked by [PuroCommand].
class PuroIdeCommand extends Command {
  PuroIdeCommand() {
    argParser
      ..addOption('workspace',
          help: 'Workspace path relative to the repository root.')
      ..addOption('package',
          help: 'Follow this package (path relative to repository root).')
      ..addOption('sdk', help: 'Use this Puro environment or Flutter version.')
      ..addOption('editor',
          allowed: ['vscode', 'intellij', 'both'],
          help: 'IDE to configure. Defaults to existing IDE configuration.')
      ..addFlag('reset',
          negatable: false, help: 'Follow the default SDK again.')
      ..addFlag('status',
          negatable: false, help: 'Show the saved choice without changes.');
  }

  @override
  String get name => 'ide';
  @override
  String get description =>
      'Choose a personal IDE SDK without changing command SDKs';

  @override
  Future<void> run() async {
    final args = argResults!;
    if (args.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${args.rest.join(' ')}');
    }
    final root = SidekickContext.projectRoot;
    final preferences = createIdePreferences(root, mainProject);
    final workspaceArg = args['workspace'] as String?;
    var workspace = workspaceArg == null
        ? preferences.workspaceFor(entryWorkingDirectory)
        : root.directory(workspaceArg).absolute;
    final packageArg = args['package'] as String?;
    final sdkArg = args['sdk'] as String?;
    final reset = args['reset'] as bool;
    final status = args['status'] as bool;
    if ([packageArg != null, sdkArg != null, reset, status]
            .where((v) => v)
            .length >
        1) {
      usageException(
          'Choose only one of --package, --sdk, --reset, or --status.');
    }
    if (status) {
      final saved = preferences.read(workspace);
      print('IDE workspace: ${workspace.path}');
      print(saved == null
          ? 'No saved SDK choice.'
          : 'Selection: ${saved['mode']} ${saved['value'] ?? ''}\nLast applied SDK: ${saved['sdk']}');
      print('Personal settings: ${preferences.stateFile(workspace).path}');
      return;
    }
    var mode = reset
        ? 'auto'
        : packageArg != null
            ? 'package'
            : sdkArg != null
                ? 'sdk'
                : 'auto';
    String? value = packageArg ?? sdkArg;
    if (!reset && packageArg == null && sdkArg == null) {
      if (!stdin.hasTerminal) {
        usageException(
            'Use --package, --sdk, --reset, or --status outside an interactive terminal.');
      }
      if (workspaceArg == null) {
        final choices = {
          root.path,
          ...preferences.packages.map((p) => p.root.path),
        }.toList();
        workspace = Directory(dcli.menu('IDE workspace:',
            options: choices,
            defaultOption:
                choices.contains(workspace.path) ? workspace.path : root.path));
      }
      final choice = dcli.menu('IDE SDK:', options: [
        'Follow the default package',
        'Follow a package',
        'Use a specific Puro environment',
      ]);
      if (choice == 'Follow a package') {
        mode = 'package';
        value = dcli.menu('Package:',
            options: preferences.packages
                .map((p) => relative(p.root.path, from: root.path))
                .toList());
      } else if (choice == 'Use a specific Puro environment') {
        mode = 'sdk';
        value = dcli.ask('Puro environment or Flutter version:');
      }
    }
    if (!workspace.existsSync() ||
        !(equals(root.resolveSymbolicLinksSync(),
                workspace.resolveSymbolicLinksSync()) ||
            isWithin(root.resolveSymbolicLinksSync(),
                workspace.resolveSymbolicLinksSync()))) {
      usageException(
          'Workspace must be an existing directory inside ${root.path}.');
    }
    var editors = switch (args['editor']) {
      'vscode' => {'vscode'},
      'intellij' => {'intellij'},
      'both' => {'vscode', 'intellij'},
      _ => preferences.savedSelection(workspace)?.editors ??
          preferences.detectedEditors(workspace),
    };
    if (editors.isEmpty && stdin.hasTerminal) {
      editors = {
        dcli.menu('Editor:', options: ['vscode', 'intellij'])
      };
    }
    if (editors.isEmpty) {
      usageException('Choose --editor vscode, intellij, or both.');
    }
    await preferences.apply(workspace,
        selection: IdeSelection(mode: mode, value: value, editors: editors));
  }
}
