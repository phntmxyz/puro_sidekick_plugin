import 'package:dcli/dcli.dart' as dcli;
import 'package:sidekick_core/sidekick_core.dart';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
Future<ProcessCompletion> puro(
  List<String> args, {
  Directory? workingDirectory,
  dcli.Progress? progress,
  bool nothrow = false,
  String Function()? throwOnError,
}) async {
  final puroPath = getPuroPath();

  if (puroPath == null) {
    throw PuroNotFoundException();
  }

  int exitCode = -1;
  try {
    final process = dcli.startFromArgs(
      puroPath.path,
      ['--no-update-check', '--no-install', ...args],
      workingDirectory: workingDirectory?.absolute.path,
      nothrow: nothrow || throwOnError != null,
      progress: progress,
      terminal: progress == null,
    );

    exitCode = process.exitCode ?? -1;
  } catch (e) {
    if (e is dcli.RunException) {
      exitCode = e.exitCode ?? 1;
    }
    if (throwOnError == null) {
      rethrow;
    }
  }
  if (exitCode != 0 && throwOnError != null) {
    throw throwOnError();
  }

  return ProcessCompletion(exitCode: exitCode);
}

File? getPuroPath() {
  String? path;
  // Try to find puro in PATH
  final which = dcli.which('puro');
  if (which.found) {
    path = which.path;
  }
  if (path == null) {
    final standalonePath = getPuroStandaloneBinPath();
    if (standalonePath.existsSync()) {
      final result = dcli.find(
        'puro',
        workingDirectory: standalonePath.path,
        recursive: false,
      );
      path = result.firstLine;
    }
  }
  return path != null ? File(path) : null;
}

/// Returns the puro standalone bin path. It may not exist.
Directory getPuroStandaloneBinPath({bool createIfNotExists = false}) {
  final path = Directory(
    "${SidekickContext.sidekickPackage.buildDir.absolute.path}/puro/bin/",
  );
  if (createIfNotExists && !path.existsSync()) {
    path.createSync(recursive: true);
  }
  return path;
}

/// Parses environment names from `puro ls` output.
///
/// The output format is:
/// ```txt
///     ~ stable    (stable / 3.38.5 / f6ff1529fd)
///       beta      (beta / 3.40.0-0.2.pre / ebde138e38)
///     * 3.27.4    (stable / 3.27.4 / d8a9f9a52e)
/// ```
///
/// Returns a set of environment names like {'stable', 'beta', '3.27.4'}
Set<String> parsePuroEnvironments(String output) {
  final envNames = <String>{};
  // Match lines with optional prefix (spaces, ~, *) followed by environment name and details in parentheses
  final envPattern = RegExp(r'^\s*[~*]?\s*(\S+)\s+\(', multiLine: true);

  for (final match in envPattern.allMatches(output)) {
    final envName = match.group(1);
    if (envName != null) {
      envNames.add(envName);
    }
  }

  return envNames;
}

/// Thrown when puro is not found
class PuroNotFoundException implements Exception {
  @override
  String toString() {
    return 'Puro not found. Please install puro first. Visit https://puro.dev/';
  }
}
