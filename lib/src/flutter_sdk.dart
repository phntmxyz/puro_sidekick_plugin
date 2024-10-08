import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Create an empty folder for flutter sdk symlink
String flutterSdkSymlink() {
  final flutterPath = Directory(
    "${SidekickContext.sidekickPackage.buildDir.absolute.path}/flutter",
  );
  flutterPath.createSync(recursive: true);
  return flutterPath.absolute.path;
}

/// Returns the Flutter SDK path from puro environment
/// throws [PuroNotFoundException] if puro is not found
String puroFlutterSdkPath(Directory packageDir) {
  String? envPath;
  final pathMatcher = RegExp(r'.*executing: \[(.*)\].*');
  final progress = Progress.capture();
  puro(
    ['flutter', '-v', '--version'],
    progress: progress,
    workingDirectory: packageDir,
  );
  final currentEnvs = progress.lines.join('\n');
  final match = pathMatcher.firstMatch(currentEnvs);
  if (match != null) {
    envPath = match.group(1);
  }
  if (envPath == null) {
    throw PuroNotFoundException();
  }
  return envPath!;
}

/// Create a symlink from link to target
int createSymlink(String link, String target) {
  final linkDir = Directory(link);
  final targetDir = Directory(target);
  if (linkDir.existsSync()) {
    linkDir.deleteSync();
  }

  if (Platform.isMacOS || Platform.isLinux) {
    final process = dcli.startFromArgs(
      'ln',
      ['-s', targetDir.path, linkDir.path],
      nothrow: true,
      progress: Progress.print(),
      terminal: true,
    );
    return process.exitCode ?? -1;
  } else if (Platform.isWindows) {
    final process = dcli.startFromArgs(
      'mklink',
      ['/D', linkDir.path, targetDir.path],
      nothrow: true,
      progress: Progress.print(),
      terminal: true,
    );
    return process.exitCode ?? -1;
  } else {
    print('Unsupported platform.');
    return -1;
  }
}
