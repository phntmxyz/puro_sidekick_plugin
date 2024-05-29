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

// Get best matching semantic version
SemanticVersion getBestMatchingVersion(List<SemanticVersion> versions, SemanticVersion targetVersion) {
  SemanticVersion? bestMatch;
  for (final version in versions) {
    if (version.major == targetVersion.major && version.minor == targetVersion.minor) {
      if (bestMatch == null || version.compareTo(bestMatch) > 0) {
        bestMatch = version;
      }
    }
  }
  return bestMatch ?? versions.first;
}
