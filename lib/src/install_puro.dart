import 'dart:convert';

import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

const puroFallbackVersion = '1.5.0';

/// Executes Flutter CLI via puro
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
Directory installPuro({
  dcli.Progress? progress,
}) {
  // Allow forcing global install via env var, useful in CI
  final envValue = Platform.environment['SIDEKICK_PURO_INSTALL_GLOBAL'];
  final installGlobal = envValue ?? dcli.ask(
    "Puro is not installed.\nDo you want to install Puro global? (y/N)",
    defaultValue: 'n',
  );

  final latestVersion = getLatestPuroVersion();
  print('Download Puro $latestVersion');

  if (installGlobal == 'y') {
    final globalPath = installPuroGlobal(latestVersion, progress);
    print('Puro installed global at ${globalPath.absolute.path}');
    return globalPath;
  } else {
    final localPath = installPuroStandalone(latestVersion, progress);
    print('Puro installed local at ${localPath.absolute.path}');
    return localPath;
  }
}

Directory installPuroGlobal(String version, dcli.Progress? progress) {
  int resultCode = -1;
  final downloadPath = Directory.systemTemp..createSync(recursive: true);
  if (Platform.isWindows) {
    resultCode = installPuroGlobalWindows(version, downloadPath, progress);
  } else if (Platform.isMacOS) {
    resultCode = installPuroGlobalUnix(version, downloadPath, progress);
  } else if (Platform.isLinux) {
    resultCode = installPuroGlobalUnix(version, downloadPath, progress);
  } else {
    print('Unsupported platform.');
  }
  if (resultCode != 0) {
    throw PuroInstallationFailedException();
  }

  final puroPath = getPuroPath();
  if (puroPath == null) {
    throw PuroInstallationFailedException();
  }
  print('Puro installed at ${puroPath.parent.parent.absolute.path}');
  return puroPath.parent.parent;
}

Directory installPuroStandalone(String version, dcli.Progress? progress) {
  final puroWindowsDownloadUrl =
      "https://puro.dev/builds/$version/windows-x64/puro.exe";
  final puroDarwinDownloadUrl =
      "https://puro.dev/builds/$version/darwin-x64/puro";
  final puroLinuxDownloadUrl =
      "https://puro.dev/builds/$version/linux-x64/puro";

  int resultCode = -1;
  final downloadPath = getPuroStandaloneBinPath(createIfNotExists: true);
  if (Platform.isWindows) {
    resultCode = installPuroStandaloneWindows(
      puroWindowsDownloadUrl,
      downloadPath,
      progress,
    );
  } else if (Platform.isMacOS) {
    resultCode = installPuroStandaloneMacOs(
      puroDarwinDownloadUrl,
      downloadPath,
      progress,
    );
  } else if (Platform.isLinux) {
    resultCode = installPuroStandaloneLinux(
      puroLinuxDownloadUrl,
      downloadPath,
      progress,
    );
  } else {
    print('Unsupported platform.');
  }
  if (resultCode != 0) {
    throw PuroInstallationFailedException();
  }
  return downloadPath.parent;
}

/// Default cache TTL of 24 hours
const _cacheTtl = Duration(hours: 24);

/// Checks if a cache file is still valid (exists and not expired).
bool _isCacheValid(File cacheFile, {Duration ttl = _cacheTtl}) {
  if (!cacheFile.existsSync()) return false;
  final lastModified = cacheFile.lastModifiedSync();
  return DateTime.now().difference(lastModified) < ttl;
}

/// Fetches the latest Puro version from GitHub releases.
///
/// The result is cached in the build folder for 24 hours.
/// [githubReleasesProvider] can be overridden for testing.
/// [cacheFile] can be overridden for testing.
String getLatestPuroVersion({
  String Function()? githubReleasesProvider,
  File? cacheFile,
}) {
  cacheFile ??= File(
    '${SidekickContext.sidekickPackage.buildDir.path}/puro_latest_version.txt',
  );

  // Return cached version if available and not expired
  if (_isCacheValid(cacheFile)) {
    final cached = cacheFile.readAsStringSync().trim();
    if (cached.isNotEmpty) {
      return cached;
    }
  }

  try {
    final resultJson =
        githubReleasesProvider?.call() ?? _fetchLatestPuroReleaseJson();
    if (resultJson == null) {
      return puroFallbackVersion;
    }
    final result = jsonDecode(resultJson);
    if (result is! List || result.isEmpty) {
      print('Unexpected response from GitHub API: $resultJson');
      return puroFallbackVersion;
    }
    final tagName = (result[0] as Map<String, dynamic>)['tag_name'];
    if (tagName is! String) {
      print('Missing or invalid tag_name in GitHub API response');
      return puroFallbackVersion;
    }

    // Cache the version (delete first to reset last modified time)
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(tagName);

    return tagName;
  } catch (e, stackTrace) {
    print('Failed to get the latest Puro version: $e');
    print(stackTrace);
    return puroFallbackVersion;
  }
}

String? _fetchLatestPuroReleaseJson() {
  final output = dcli.startFromArgs(
    'curl',
    ['https://api.github.com/repos/pingbird/puro/releases?per_page=1&page=1'],
    progress: Progress.capture(captureStderr: false),
  );
  if (output.exitCode != 0) {
    print('Failed to get the latest Puro version.');
    return null;
  }
  return output.lines.join('\n');
}

int installPuroStandaloneMacOs(
  String downloadUrl,
  Directory downloadPath,
  dcli.Progress? progress,
) {
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

int installPuroStandaloneLinux(
  String downloadUrl,
  Directory downloadPath,
  dcli.Progress? progress,
) {
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

int installPuroStandaloneWindows(
  String downloadUrl,
  Directory downloadPath,
  dcli.Progress? progress,
) {
  final command =
      'Invoke-WebRequest -Uri "$downloadUrl" -OutFile "\$env:temp\\puro.exe"; &"\$env:temp\\puro.exe"';

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

int installPuroGlobalUnix(
  String version,
  Directory downloadPath,
  dcli.Progress? progress,
) {
  final process = dcli.startFromArgs(
    'bash',
    [
      '-c',
      'curl -o- https://puro.dev/install.sh | PURO_VERSION="$version" bash',
    ],
    workingDirectory: downloadPath.path,
    nothrow: true,
    progress: progress,
    terminal: progress == null,
  );

  return process.exitCode ?? -1;
}

int installPuroGlobalWindows(
  String version,
  Directory downloadPath,
  dcli.Progress? progress,
) {
  final command =
      'Invoke-WebRequest -Uri "https://puro.dev/builds/$version/windows-x64/puro.exe" -OutFile "\$env:temp\\puro.exe"; &"\$env:temp\\puro.exe" install-puro --promote"';

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
