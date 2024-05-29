import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/semantic_version.dart';
import 'package:sidekick_core/sidekick_core.dart';
import 'package:yaml/yaml.dart';

/// Create an empty folder for flutter sdk symlink
String flutterSdkSymlink() {
  final flutterPath = Directory("${SidekickContext.sidekickPackage.buildDir.absolute.absolute.path}/flutter");
  flutterPath.createSync(recursive: true);
  return flutterPath.absolute.path;
}

/// Returns the Flutter SDK path from puro environment
/// throws [PuroNotFoundException] if puro is not found
String puroFlutterSdkPath() {
  String? envPath;
  final pathMatcher = RegExp(r'.*executing: \[(.*)\].*');
  puro(
    ['flutter', '-v', '--version'],
    progress: Progress((line) {
      if (envPath != null) return;
      final match = pathMatcher.firstMatch(line);
      if (match != null) {
        envPath = match.group(1);
      }
    }),
  );
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

/// Reads the minimum flutter version from pubspec.yaml if available
/// If the flutter version is not available, it reads the dart sdk version
/// and returns the flutter version of the lower bound of the dart version constraint
/// Returns null if the version is not found
String? getMinSdkVersionFromPubspec(Directory packagePath, {bool useBeta = false}) {
  try {
    final package = DartPackage.fromDirectory(packagePath);
    final pubspecFile = package?.pubspec;
    if (pubspecFile == null || !pubspecFile.existsSync()) {
      return null;
    }
    final pubspecYamlContent = pubspecFile.readAsStringSync();

    // Check for valid package name
    final doc = loadYamlDocument(pubspecYamlContent);
    final pubspec = doc.contents.value as YamlMap;
    final packageName = pubspec['name'] as String?;
    if (packageName == null) {
      return null;
    }

    // Check for environment
    final environment = pubspec['environment'] as YamlMap?;

    // Get flutter version if available
    try {
      final flutterConstraint = environment?['flutter'] as String?;
      // Get version by Caret syntax
      final lowerFlutterBound = flutterConstraint?..split('^')[1];
      return lowerFlutterBound;
    } catch (_) {}

    // Get dart sdk version if flutter version is not available
    final dartConstraint = environment?['sdk'] as String?;
    String? lowerDartBound;
    try {
      lowerDartBound = dartConstraint?.split('>=')[1].split('<')[0];
    } catch (_) {}

    try {
      // Get version by Caret syntax
      lowerDartBound ??= dartConstraint?.split('^')[1];
    } catch (_) {}

    if (lowerDartBound == null) {
      return null;
    }

    return getBestFlutterVersion(lowerDartBound, useBeta: useBeta);
  } on FileSystemException catch (e) {
    print('Error reading pubspec.yaml: $e');
    return '';
  } on YamlException catch (e) {
    print('Error parsing pubspec.yaml: $e');
    return '';
  } catch (e) {
    print('Unexpected error: $e');
    return '';
  }
}

String getBestFlutterVersion(String dartVersion, {bool useBeta = false}) {
  final lines = <String>[];

  try {
    // List all available flutter and dart versions
    puro(
      ['ls-versions'],
      progress: Progress((line) {
        if (line.isNotEmpty) lines.add(line);
      }),
    );
  } catch (e) {
    print('Error getting flutter versions: $e');
  }

  final allVersions = lines.join('\n');
  return parseFlutterVersionToDartVersion(allVersions, dartVersion, useBeta: useBeta);
}

String parseFlutterVersionToDartVersion(String versions, String dartVersion, {bool useBeta = false}) {
  final semanticDartVersion = SemanticVersion.fromString(dartVersion);

  final lines = versions.split('\n');

  // Map off dart version to flutter version
  final versionMap = <SemanticVersion, SemanticVersion>{};
  final betaVersionMap = <SemanticVersion, SemanticVersion>{};

  bool isBetaRelease = false;

  // Parse the version list
  for (final line in lines) {
    if (line.contains('beta')) {
      isBetaRelease = true;
    }

    final parts = line.split('|');
    if (parts.length >= 3) {
      final flutterVersion = SemanticVersion.fromString(parts[0].replaceAll('Flutter', '').trim());
      final listedDartVersion = SemanticVersion.fromString(parts[3].replaceAll('Dart', '').trim());

      // Only add the latest version for each dart version
      if (isBetaRelease) {
        if (!betaVersionMap.containsKey(listedDartVersion)) {
          betaVersionMap[listedDartVersion] = flutterVersion;
        }
      } else {
        if (!versionMap.containsKey(listedDartVersion)) {
          versionMap[listedDartVersion] = flutterVersion;
        }
      }
    }
  }

  if (useBeta) {
    final bestDartVersion = getBestMatchingVersion(betaVersionMap.keys.toList(), semanticDartVersion);
    return betaVersionMap[bestDartVersion].toString();
  } else {
    final bestDartVersion = getBestMatchingVersion(versionMap.keys.toList(), semanticDartVersion);
    return versionMap[bestDartVersion].toString();
  }
}
