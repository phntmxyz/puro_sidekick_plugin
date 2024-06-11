import 'package:dcli/dcli.dart' as dcli;
import 'package:sidekick_core/sidekick_core.dart';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
int puro(
  List<String> args, {
  Directory? workingDirectory,
  dcli.Progress? progress,
  String Function()? throwOnError,
}) {
  final workingDir = entryWorkingDirectory.absolute;

  final puroPath = getPuroPath();

  if (puroPath == null) {
    throw PuroNotFoundException();
  }

  final process = dcli.startFromArgs(
    puroPath.path,
    ['--no-update-check', '--no-install', ...args],
    workingDirectory: workingDir.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  final exitCode = process.exitCode ?? -1;

  if (exitCode != 0 && throwOnError != null) {
    throw throwOnError();
  }

  return exitCode;
}

File? getPuroPath() {
  String? path;
  // Try to find puro in PATH
  final which = dcli.which('puro');
  if (which.found) {
    path = which.path;
  }
  if (path == null) {
    final result = dcli.find('puro', workingDirectory: getPuroBinPath().path, recursive: false);
    path = result.firstLine;
  }
  return path != null ? File(path) : null;
}

Directory getPuroBinPath() {
  final installDir = Directory("${SidekickContext.sidekickPackage.buildDir.absolute.path}/puro");

  final puroPath = '${installDir.path}/bin/';
  if (!dcli.exists(puroPath)) {
    dcli.createDir(puroPath, recursive: true);
  }
  return Directory(puroPath);
}

/// Thrown when puro is not found
class PuroNotFoundException implements Exception {
  @override
  String toString() {
    return 'Puro not found. Please install puro first. Visit https://puro.dev/';
  }
}
