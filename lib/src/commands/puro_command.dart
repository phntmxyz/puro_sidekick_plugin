import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Makes the `puro` command available as subcommand
class PuroCommand extends ForwardCommand {
  @override
  final String description = 'Call Puro commands from the project';

  @override
  final String name = 'puro';

  @override
  Future<void> run() async {
    final args = argResults!.arguments;

    final completion = await puro(args, nothrow: true);
    exitCode = completion.exitCode ?? 1;
  }
}
