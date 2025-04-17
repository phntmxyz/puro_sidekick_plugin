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

Future<void> initializePuro(SdkInitializerContext context) async {
  // Create folder for flutter sdk symlink
  final symlinkPath = flutterSdkSymlink();

  Directory? puroRootDir;
  final puroPath = getPuroPath();
  bool checkForUpdates = false;

  // Check if puro is already installed
  if (puroPath != null && puroPath.existsSync()) {
    print(
      'Puro is already installed at ${puroPath.parent.parent.absolute.path}',
    );
    puroRootDir = puroPath.parent.parent;
    checkForUpdates = true;
  } else {
    // Install puro
    puroRootDir = installPuro();
  }
  dcli.env['PURO_ROOT'] = puroRootDir.absolute.path;

  // Check if puro is up to date
  if (checkForUpdates) {
    print('Checking for updates...');
    final latestVersion = Version.parse(getLatestPuroVersion());
    print('Latest Puro version: $latestVersion');

    final currentPuro = await getCurrentPuroVersion();
    final currentVersion = Version.parse(currentPuro.version);
    print(
      'Current Puro version: $currentVersion - Standalone: ${currentPuro.standalone}',
    );
    if (currentVersion < latestVersion) {
      print('Puro is outdated. Updating to $latestVersion');
      if (currentPuro.standalone) {
        puroRootDir = installPuro();
      } else {
        await puro(['upgrade-puro'], progress: Progress.print());
        puroRootDir = puroPath!.parent.parent;
      }
      dcli.env['PURO_ROOT'] = puroRootDir.absolute.path;
    } else {
      print('Puro is up to date.');
    }
  }

  // Setup puro environment
  await _setupFlutterEnvironment(context);

  // Create symlink to puro flutter sdk
  final packageDir = context.packageDir?.root ?? SidekickContext.projectRoot;
  final flutterPath = puroFlutterSdkPath(packageDir);

  final flutterBinPath = Directory(flutterPath).directory('bin');

  dcli.env['PURO_FLUTTER_BIN'] = flutterBinPath.absolute.path;
  print('Use Puro Flutter SDK: $flutterPath');
  createSymlink(symlinkPath, flutterPath);
}

Future<void> _setupFlutterEnvironment(SdkInitializerContext context) async {
  final packageDir = context.packageDir?.root ?? SidekickContext.projectRoot;

  final sdkVersion = VersionParser(
    packagePath: packageDir,
    projectRoot: SidekickContext.projectRoot,
  ).getMaxFlutterSdkVersionFromPubspec();

  final progress = Progress.capture();
  await puro(['ls'], progress: progress);
  final currentEnvs = progress.lines.join('\n');

  if (!currentEnvs.contains(sdkVersion)) {
    print('Create new Puro environment: $sdkVersion');
    await puro(['create', sdkVersion, sdkVersion], progress: Progress.print());
  }
  print('Use Puro environment: $sdkVersion');
  await puro(
    ['use', '--project', packageDir.absolute.path, sdkVersion],
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

Future<({bool standalone, String version})> getCurrentPuroVersion() async {
  final puroPath = getPuroPath();
  if (puroPath == null) {
    throw PuroInstallationFailedException();
  }
  final progress = Progress.capture();
  await puro(
    ['--version'],
    progress: progress,
    workingDirectory: puroPath.parent.parent.absolute,
  );
  final versionLine = progress.lines.firstWhere(
    (line) => line.contains('[i] Puro'),
  );

  final regex = RegExp(r'\b\d+\.\d+\.\d+\b');
  final match = regex.firstMatch(versionLine);

  String? version;
  if (match != null) {
    version = match.group(0);
  }
  if (version == null) {
    throw PuroInstallationFailedException();
  }
  final standalone = versionLine.contains('standalone');
  return (standalone: standalone, version: version);
}
