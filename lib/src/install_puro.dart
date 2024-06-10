import 'dart:convert';

import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

const puroFallbackVersion = '1.4.6';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
Directory installPuro({
  dcli.Progress? progress,
}) {
  final puroPath = getPuroPath();

  if (puroPath != null) {
    print('Puro is already installed at $puroPath');
    return puroPath.parent.parent;
  }

  final latestVersion = getLatestPuroVersion();
  print('Download Puro $latestVersion');

  final puroWindowsDownloadUrl = "https://puro.dev/builds/$latestVersion/windows-x64/puro.exe";
  final puroDarwinDownloadUrl = "https://puro.dev/builds/$latestVersion/darwin-x64/puro";
  final puroLinuxDownloadUrl = "https://puro.dev/builds/$latestVersion/linux-x64/puro";

  int resultCode = -1;
  final downloadPath = getPuroBinPath();
  if (Platform.isWindows) {
    resultCode = installPuroWindows(puroWindowsDownloadUrl, downloadPath, progress);
  } else if (Platform.isMacOS) {
    resultCode = installPuroMacOs(puroDarwinDownloadUrl, downloadPath, progress);
  } else if (Platform.isLinux) {
    resultCode = installPuroLinux(puroLinuxDownloadUrl, downloadPath, progress);
  } else {
    print('Unsupported platform.');
  }
  if (resultCode != 0) {
    throw PuroInstallationFailedException();
  }
  return downloadPath.parent;
}

String? getLatestPuroVersion() {
  try {
    const command = 'curl https://api.github.com/repos/pingbird/puro/releases?per_page=1&page=1';
    final output = dcli.start(command, progress: Progress.capture(captureStderr: false));
    if (output.exitCode != 0) {
      print('Failed to get the latest Puro version.');
      return puroFallbackVersion;
    }
    final resultJson = output.lines.join('\n');
    final result = jsonDecode(resultJson);
    return ((result as List<dynamic>)[0] as Map<String, dynamic>)['tag_name'] as String;
  } catch (e) {
    print('Failed to get the latest Puro version: $e');
    return puroFallbackVersion;
  }
}

int installPuroMacOs(String downloadUrl, Directory downloadPath, dcli.Progress? progress) {
  final downloadProcess = dcli.startFromArgs(
    'bash',
    [
      '-c',
      'curl -O $downloadUrl',
    ],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  if (downloadProcess.exitCode != 0) {
    return downloadProcess.exitCode ?? -1;
  }

  final chmodProcess = dcli.startFromArgs(
    'bash',
    [
      '-c',
      'chmod +x puro',
    ],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  dcli.env['PURO_ROOT'] = "$downloadPath../";

  return chmodProcess.exitCode ?? -1;
}

int installPuroLinux(String downloadUrl, Directory downloadPath, dcli.Progress? progress) {
  final downloadProcess = dcli.startFromArgs(
    'bash',
    [
      '-c',
      'curl -O $downloadUrl',
    ],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  if (downloadProcess.exitCode != 0) {
    return downloadProcess.exitCode ?? -1;
  }

  final chmodProcess = dcli.startFromArgs(
    'bash',
    [
      '-c',
      'chmod +x puro',
    ],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  dcli.env['PURO_ROOT'] = "$downloadPath../";

  return chmodProcess.exitCode ?? -1;
}

int installPuroWindows(String downloadUrl, Directory downloadPath, dcli.Progress? progress) {
  final command = 'Invoke-WebRequest -Uri "$downloadUrl" -OutFile "\$env:temp\\puro.exe"; &"\$env:temp\\puro.exe"';

  final process = dcli.startFromArgs(
    'powershell.exe',
    ['-Command', command],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  return process.exitCode ?? -1;
}
