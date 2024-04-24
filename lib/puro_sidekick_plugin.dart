/// A Sidekick plugin that connects puro to the sidekick flutter command
library puro_sidekick_plugin;

import 'package:puro_sidekick_plugin/src/puro.dart';
import 'package:sidekick_core/sidekick_core.dart';

export 'package:puro_sidekick_plugin/src/commands/puro_command.dart';
export 'package:puro_sidekick_plugin/src/puro.dart';

void initializePuro(Directory sdk) {
  if (which('puro').notfound) {
    throw PuroNotFoundException();
  }
}

// ignore: unreachable_from_main
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
  print('Use Puro Flutter SDK: $envPath');
  return envPath!;
}

void main() {
  initializePuro(Directory.current);
}
