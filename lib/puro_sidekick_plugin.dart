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

bool _alreadyCheckedForUpdate = false;

/// print for verbose messages
void printVerbose(String message) {
  if (dcli.env['PURO_SIDEKICK_PLUGIN_VERBOSE'] == 'true') {
    dcli.printerr(message);
  }
}

Future<void> initializePuro(SdkInitializerContext context) async {
  // Create folder for flutter sdk symlink
  final symlinkPath = flutterSdkSymlink();

  Directory? puroRootDir;
  final puroPath = getPuroPath();
  bool checkForUpdates = false;

  // Check if puro is already installed
  if (puroPath != null && puroPath.existsSync()) {
    printVerbose(
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
  if (checkForUpdates && !_alreadyCheckedForUpdate) {
    _alreadyCheckedForUpdate = true;
    printVerbose('Checking for updates...');
    final latestVersion = Version.parse(getLatestPuroVersion());
    printVerbose('Latest Puro version: $latestVersion');

    final currentPuro = await getCurrentPuroVersion();
    final currentVersion = Version.parse(currentPuro.version);
    printVerbose(
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
      printVerbose('Puro is up to date.');
    }
  }

  // getting the puro flutter sdk path only work when no bin override is set
  // https://github.com/pingbird/puro/blob/46d9753ffe8e60f0efa7256fad8e5efbf107e39a/puro/lib/src/config.dart#L147
  dcli.env['PURO_FLUTTER_BIN'] = null;

  final packageDir = context.packageDir?.root ?? SidekickContext.projectRoot;
  final versions = await VersionParser(
    packagePath: packageDir,
    projectRoot: SidekickContext.projectRoot,
    useBeta: true,
  ).getMaxFlutterSdkVersionFromPubspec();

  // Setup puro environment
  await _createPuroEnvironment(packageDir, versions.flutterVersion);
  await _binPuroToProject(packageDir, versions.flutterVersion);

  // Create symlink to puro flutter sdk
  final flutterPath = await puroFlutterSdkPath(packageDir);
  final flutterBinPath = Directory(flutterPath).directory('bin');
  printVerbose('Use Puro Flutter SDK: $flutterPath');

  dcli.env['PURO_FLUTTER_BIN'] = flutterBinPath.absolute.path;
  createSymlink(symlinkPath, flutterPath);

  print(
    'Using Flutter ${versions.flutterVersion} (Dart ${versions.dartVersion})',
  );
}

Future<void> _createPuroEnvironment(
  Directory packageDir,
  Version flutterSdkVersion,
) async {
  final progress = Progress.capture();
  await puro(['ls'], progress: progress);
  final currentEnvs = progress.lines.join('\n');

  final versionString = flutterSdkVersion.toString();
  if (!currentEnvs.contains(versionString)) {
    printVerbose('Create new Puro environment: $flutterSdkVersion');
    await puro(
      ['create', versionString, versionString],
      progress: Progress.print(),
    );
  }
}

Future<void> _binPuroToProject(
  Directory packageDir,
  Version flutterSdkVersion,
) async {
  final versionString = flutterSdkVersion.toString();
  printVerbose('Use Puro environment: $versionString');
  await puro(
    ['use', '--project', packageDir.absolute.path, versionString],
    progress: Progress.printStdErr(),
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
