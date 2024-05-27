import 'package:dcli/dcli.dart' as dcli;
import 'package:sidekick_core/sidekick_core.dart';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
int puro(
  List<String> args, {
  Directory? workingDirectory,
  Directory? installDirectory,
  dcli.Progress? progress,
  String Function()? throwOnError,
}) {
  final workingDir = entryWorkingDirectory.absolute;
  final installDir = installDirectory ?? SidekickContext.sidekickPackage.buildDir;

  final puroPath = getPuroPath(installDir);

  if (puroPath == null) {
    throw PuroNotFoundException();
  }

  final process = dcli.startFromArgs(
    puroPath,
    args,
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

String? getPuroPath(Directory? installDirectory) {
  String? path;
  final result = dcli.find('puro', workingDirectory: getPuroBinPath(installDirectory), recursive: false);
  path = result.firstLine;
  if (path == null) {
    // Try to find puro in PATH
    final which = dcli.which('puro');
    if (which.found) {
      path = which.path;
    }
  }
  return path;
}

String getPuroBinPath(Directory? installDirectory) {
  final installDir = installDirectory ?? SidekickContext.sidekickPackage.buildDir;

  final puroPath = '${installDir.path}/bin/';
  if (!dcli.exists(puroPath)) {
    dcli.createDir(puroPath);
  }
  return puroPath;
}

/// Thrown when puro is not found
class PuroNotFoundException implements Exception {
  @override
  String toString() {
    return 'Puro not found. Please install puro first. Visit https://puro.dev/';
  }
}
