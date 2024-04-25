import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
int installPuro({
  Directory? workingDirectory,
  dcli.Progress? progress,
}) {
  if (dcli.which('puro').found) {
    print('Puro is already installed.');
    return 0;
  }

  final workingDir = workingDirectory?.absolute ?? entryWorkingDirectory.absolute;

  if (Platform.isWindows) {
    const command =
        'Invoke-WebRequest -Uri "https://puro.dev/builds/1.4.6/windows-x64/puro.exe" -OutFile "\$env:temp\\puro.exe"; &"\$env:temp\\puro.exe" install-puro --promote';

    final process = dcli.startFromArgs(
      'powershell.exe',
      ['-Command', command],
      workingDirectory: workingDir.path,
      nothrow: true,
      progress: progress,
      terminal: progress == null,
    );
    puro(['upgrade-puro']);
    puro(['version']);

    return process.exitCode ?? -1;
  } else {
    final process = dcli.startFromArgs(
      'bash',
      [
        '-c',
        'curl -o- https://puro.dev/install.sh | PURO_VERSION="1.4.6" bash',
      ],
      workingDirectory: workingDir.path,
      nothrow: true,
      progress: progress,
      terminal: progress == null,
    );
    puro(['upgrade-puro']);
    puro(['version']);

    return process.exitCode ?? -1;
  }
}
