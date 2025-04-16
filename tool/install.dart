import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart'
    hide cliName, mainProject, repository;
import 'package:sidekick_core/sidekick_core.dart';
import 'package:sidekick_plugin_installer/sidekick_plugin_installer.dart';

import 'src/main_file_modifiers.dart';
import 'src/modifiable_source_file.dart';
import 'src/require_dependency_version.dart';

Future<void> main() async {
  final SidekickPackage package = PluginContext.sidekickPackage;

  requireDependencyVersion(
    package,
    'sidekick_core',
    VersionConstraint.parse('>=3.0.0-preview.5 <4.0.0'),
  );

  addSelfAsDependency();
  pubGet(package);

  final mainFile = package.cliMainFile;
  if (!mainFile.existsSync()) {
    throw "Could not find file ${mainFile.path} to register the dart commands";
  }

  final ModifiableSourceFile mainSourceFile = ModifiableSourceFile(mainFile);
  mainSourceFile.addFlutterSdkPath('flutterSdkSymlink()');
  mainSourceFile.addImport(
    "import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';",
  );
  mainSourceFile.registerSdkInitializer(
    'addSdkInitializer(initializePuro);',
  );
  mainSourceFile.flush();

  // Usually the Flutter and Dart command from sidekick_core are already present
  // Add them in case they are not
  final mainContent = mainFile.readAsStringSync();
  if (!mainContent.contains('FlutterCommand()')) {
    await registerPlugin(
      sidekickCli: package,
      command: 'FlutterCommand()',
    );
  }
  if (!mainContent.contains('DartCommand()')) {
    await registerPlugin(
      sidekickCli: package,
      command: 'DartCommand()',
    );
  }
  if (!mainContent.contains('PuroCommand()')) {
    await registerPlugin(
      sidekickCli: package,
      command: 'PuroCommand()',
    );
  }

  final initialPackage =
      DartPackage.fromDirectory(SidekickContext.projectRoot) ??
          SidekickContext.sidekickPackage;
  await initializePuro(SdkInitializerContext(packageDir: initialPackage));
  await puro(['flutter', '--version'], workingDirectory: initialPackage.root);

  print(green('Successfully installed sidekick Puro plugin'));
  print('\nUsage: You can now execute the commands:\n'
      '- ${package.cliName} flutter\n'
      '- ${package.cliName} dart\n'
      '- ${package.cliName} puro\n'
      'to run flutter or dart commands with the Puro Flutter SDK.');
}
