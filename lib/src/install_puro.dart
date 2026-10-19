import 'dart:ffi' show Abi;

import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// The puro2 version this plugin installs
const puro2Version = '2.0.0';

/// Downloads and installs puro2, globally or into the sidekick build folder
///
/// https://github.com/phntmxyz/puro_sidekick_plugin
Future<Directory> installPuro({
  dcli.Progress? progress,
}) async {
  // Allow forcing global install via env var, useful in CI
  final envValue = Platform.environment['SIDEKICK_PURO_INSTALL_GLOBAL'];
  final installGlobal = envValue ??
      dcli.ask(
        "Puro2 is not installed.\nDo you want to install Puro2 globally? (y/N)",
        defaultValue: 'n',
      );

  print('Download Puro2 $puro2Version');

  if (installGlobal == 'y') {
    final globalPath = await installPuroGlobal(progress);
    print('Puro2 installed global at ${globalPath.absolute.path}');
    return globalPath;
  } else {
    final localPath = await installPuroStandalone();
    print('Puro2 installed local at ${localPath.absolute.path}');
    return localPath;
  }
}

/// Installs puro2 into `~/.puro` (or `$PURO_ROOT`) and adds it to the PATH
Future<Directory> installPuroGlobal(dcli.Progress? progress) async {
  final download = puro2Download(Abi.current());
  if (download == null) {
    print('Unsupported platform/architecture: ${Abi.current()}');
    throw PuroInstallationFailedException();
  }

  final tempDir = Directory.systemTemp.createTempSync('puro2_');
  try {
    final executable = File('${tempDir.path}/${download.fileName}');
    await downloadPuro2(download, executable);

    // Same as the official install script: puro2 moves itself into the
    // bin folder and links the flutter and dart commands
    final process = dcli.startFromArgs(
      executable.path,
      ['install-puro2', '--promote'],
      nothrow: true,
      progress: progress,
      terminal: progress == null,
    );
    if (process.exitCode != 0) {
      throw PuroInstallationFailedException();
    }
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }

  // install-puro2 updates the shell profile but the current process still has
  // the old PATH. Add the puro2 bin directory so getPuroPath() finds it.
  final puroBin = Directory('${_globalPuroRoot()}/bin');
  if (puroBin.existsSync()) {
    final separator = Platform.isWindows ? ';' : ':';
    dcli.env['PATH'] = '${puroBin.path}$separator${dcli.env['PATH'] ?? ''}';
  }

  final puroPath = getPuroPath();
  if (puroPath == null) {
    throw PuroInstallationFailedException();
  }
  print('Puro2 installed at ${puroPath.parent.parent.absolute.path}');
  return puroPath.parent.parent;
}

/// Installs puro2 into the build folder of the sidekick package
Future<Directory> installPuroStandalone() async {
  final download = puro2Download(Abi.current());
  if (download == null) {
    print('Unsupported platform/architecture: ${Abi.current()}');
    throw PuroInstallationFailedException();
  }

  final binDir = getPuroStandaloneBinPath(createIfNotExists: true);
  await downloadPuro2(download, File('${binDir.path}${download.fileName}'));
  return binDir.parent;
}

String _globalPuroRoot() {
  final puroRoot = Platform.environment['PURO_ROOT'];
  if (puroRoot != null && puroRoot.isNotEmpty) {
    return puroRoot;
  }
  if (Platform.isWindows) {
    return '${Platform.environment['USERPROFILE']}/.puro';
  }
  return '${Platform.environment['HOME']}/.puro';
}

/// Where to download a puro2 binary from and the name of the executable once
/// installed
class Puro2Download {
  const Puro2Download({
    required this.url,
    required this.fileName,
  });

  final Uri url;
  final String fileName;
}

/// Returns the puro2 [puro2Version] download for the given [abi], or `null` if
/// puro2 does not publish a build for that target.
///
/// puro2 publishes binaries for `darwin-x64`, `darwin-arm64`, `linux-x64` and
/// `windows-x64`. On Apple Silicon (`Abi.macosArm64`) the arm64 build must be
/// used, running the x64 binary without Rosetta 2 installed fails with macOS'
/// "Bad CPU type in executable" (exit 86).
Puro2Download? puro2Download(Abi abi) {
  final target = switch (abi) {
    Abi.macosArm64 => 'darwin-arm64',
    Abi.macosX64 => 'darwin-x64',
    Abi.linuxX64 => 'linux-x64',
    Abi.windowsX64 => 'windows-x64',
    _ => null,
  };
  if (target == null) {
    return null;
  }
  final extension = abi == Abi.windowsX64 ? '.exe' : '';
  return Puro2Download(
    url: Uri.parse(
      'https://github.com/phntmxyz/puro2/releases/download/'
      '$puro2Version/puro2-$target$extension',
    ),
    fileName: 'puro2$extension',
  );
}

/// Downloads the puro2 binary to [destination] and makes it executable
///
/// Throws [PuroInstallationFailedException] when the download fails.
/// [destination] is left untouched in that case.
Future<void> downloadPuro2(Puro2Download download, File destination) async {
  final List<int> bytes;
  final client = HttpClient();
  try {
    final request = await client.getUrl(download.url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      print('Failed to download ${download.url}: HTTP ${response.statusCode}');
      throw PuroInstallationFailedException();
    }
    bytes =
        await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
  } on SocketException catch (e, stackTrace) {
    print('Failed to download ${download.url}: $e');
    print(stackTrace);
    throw PuroInstallationFailedException();
  } finally {
    client.close();
  }

  destination.parent.createSync(recursive: true);
  destination.writeAsBytesSync(bytes);
  if (!Platform.isWindows) {
    final chmod = Process.runSync('chmod', ['+x', destination.path]);
    if (chmod.exitCode != 0) {
      print('Failed to make ${destination.path} executable: ${chmod.stderr}');
      throw PuroInstallationFailedException();
    }
  }
}
