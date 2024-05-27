/// A Sidekick plugin that connects puro to the sidekick flutter command
library puro_sidekick_plugin;

import 'package:puro_sidekick_plugin/src/flutter_sdk.dart';
import 'package:puro_sidekick_plugin/src/install_puro.dart';
import 'package:sidekick_core/sidekick_core.dart';

export 'package:puro_sidekick_plugin/src/commands/puro_command.dart';
export 'package:puro_sidekick_plugin/src/flutter_sdk.dart' hide createSymlink, puroFlutterSdkPath;
export 'package:puro_sidekick_plugin/src/puro.dart';

void initializePuro(Directory sdk) {
  // Create folder for flutter sdk symlink
  final symlinkPath = flutterSdkSymlink();

  final resultCode = installPuro();
  if (resultCode != 0) {
    throw PuroInstallationFailedException();
  }

  // Create symlink to puro flutter sdk
  final flutterPath = puroFlutterSdkPath();
  print('Use Puro Flutter SDK: $flutterPath');
  createSymlink(symlinkPath, flutterPath);
}

/// Thrown when puro could not be installed
class PuroInstallationFailedException implements Exception {
  @override
  String toString() {
    return 'Puro could not be installer. Please install puro first. Visit https://puro.dev/';
  }
}
