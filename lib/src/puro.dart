import 'package:dcli/dcli.dart' as dcli;
import 'package:sidekick_core/sidekick_core.dart';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
int puro(
  List<String> args, {
  Directory? workingDirectory,
  dcli.Progress? progress,
}) {
  if (which('puro').notfound) {
    throw PuroNotFoundException();
  }

  final workingDir = workingDirectory?.absolute ?? entryWorkingDirectory.absolute;

  final process = dcli.startFromArgs(
    'puro',
    args,
    workingDirectory: workingDir.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );
  return process.exitCode ?? -1;
}

/// Thrown when puro is not found
class PuroNotFoundException implements Exception {
  @override
  String toString() {
    return 'Puro not found. Please install puro first. Visit https://puro.dev/';
  }
}
