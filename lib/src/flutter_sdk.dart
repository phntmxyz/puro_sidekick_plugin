import 'package:dcli/dcli.dart' as dcli;
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
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
/// and returns the lower bound of the version constraint
/// Returns null if the version is not found
String? getMinSdkVersionFromPubspec(Directory packagePath) {
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

    // TODO - Get matching Flutter version for Dart SDK version
    return lowerDartBound;
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

String getFlutterVersionsFromPuro() {
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

  return lines.join('\n');
}

String? parseFlutterVersionToDartVersion(String versions, String dartVersion, {bool useBeta = false}) {
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
    for (final dartVersion in betaVersionMap.keys) {
      if (semanticDartVersion == dartVersion) {
        return betaVersionMap[dartVersion].toString();
      }
    }
  } else {
    for (final dartVersion in versionMap.keys) {
      if (semanticDartVersion == dartVersion) {
        return versionMap[dartVersion].toString();
      }
    }
  }

  print(red('No matching Flutter version found for Dart version $dartVersion'));
  return null;
}

class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  SemanticVersion._(this.major, this.minor, this.patch, this.preRelease);

  factory SemanticVersion.fromString(String version) {
    List<String> versionParts = [];
    String? preRelease;

    // Check for pre-release version
    if (version.contains('-')) {
      final parts = version.split('-');
      versionParts = parts[0].split('.');
      preRelease = parts[1];
    } else {
      versionParts = version.split('.');
    }

    if (versionParts.length < 3) {
      throw ArgumentError('Invalid version string');
    }
    return SemanticVersion._(
      int.parse(versionParts[0]),
      int.parse(versionParts[1]),
      int.parse(versionParts[2]),
      preRelease,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SemanticVersion && runtimeType == other.runtimeType && compareTo(other) == 0;

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode ^ preRelease.hashCode;

  @override
  String toString() {
    if (preRelease != null) {
      return '$major.$minor.$patch-$preRelease';
    }
    return '$major.$minor.$patch';
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major - other.major; // Major version comparison
    } else if (minor != other.minor) {
      return minor - other.minor; // Minor version comparison
    } else if (patch != other.patch) {
      return patch - other.patch; // Patch version comparison
    } else if (preRelease != null && other.preRelease == null) {
      return 1; // Stable version is considered greater than pre-release
    } else if (preRelease == null && other.preRelease != null) {
      return -1; // Pre-release version is considered less than stable
    } else if (preRelease != null) {
      // Compare pre-release versions (lexicographic comparison)
      return preRelease!.compareTo(other.preRelease!);
    }
    return 0; // Versions are equal
  }
}
