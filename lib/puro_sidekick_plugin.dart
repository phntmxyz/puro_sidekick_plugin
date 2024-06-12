/// A Sidekick plugin that connects puro to the sidekick flutter command
library puro_sidekick_plugin;

import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/flutter_sdk.dart';
import 'package:puro_sidekick_plugin/src/install_puro.dart';
import 'package:puro_sidekick_plugin/src/version_parser.dart';
import 'package:sidekick_core/sidekick_core.dart';

export 'package:puro_sidekick_plugin/src/commands/puro_command.dart';
export 'package:puro_sidekick_plugin/src/flutter_sdk.dart'
    hide createSymlink, puroFlutterSdkPath;
export 'package:puro_sidekick_plugin/src/puro.dart';

void initializePuro(Directory sdk) {
  // Create folder for flutter sdk symlink
  final symlinkPath = flutterSdkSymlink();

  final puroRootDir = installPuro();
  dcli.env['PURO_ROOT'] = puroRootDir.absolute.path;

  // Setup puro environment
  _setupFlutterEnvironment();

  // Create symlink to puro flutter sdk
  final flutterPath = puroFlutterSdkPath();
  print('Use Puro Flutter SDK: $flutterPath');
  createSymlink(symlinkPath, flutterPath);
}

void _setupFlutterEnvironment() {
  final sdkVersion = VersionParser(
    packagePath: entryWorkingDirectory,
    projectRoot: SidekickContext.projectRoot,
  ).getMaxFlutterSdkVersionFromPubspec();
  if (sdkVersion == null) {
    throw Exception('No Flutter SDK version found in pubspec.yaml');
  }

  final progress = Progress.capture();
  puro(['ls'], progress: progress);
  final currentEnvs = progress.lines.join('\n');

  if (!currentEnvs.contains(sdkVersion)) {
    print('Create new Puro environment: $sdkVersion');
    puro(['create', sdkVersion, sdkVersion], progress: Progress.print());
  }
  print('Use Puro environment: $sdkVersion');
  puro(
    ['use', '--project', entryWorkingDirectory.path, sdkVersion],
    progress: Progress.print(),
  );
}

/// Thrown when puro could not be installed
class PuroInstallationFailedException implements Exception {
  @override
  String toString() {
    return 'Puro could not be installer. Please install puro first. Visit https://puro.dev/';
  }
}
