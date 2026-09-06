import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:puro_sidekick_plugin/src/commands/puro_ide_command.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Makes the `puro` command available as subcommand
class PuroCommand extends ForwardCommand {
  @override
  final String description =
      'Call Puro commands; use puro ide to choose a personal IDE SDK';

  @override
  final String name = 'puro';

  @override
  Future<void> run() async {
    final args = argResults!.arguments;

    if (args.isNotEmpty && args.first == 'ide') {
      final ide = PuroIdeCommand();
      final runner = CommandRunner<void>('puro', description)..addCommand(ide);
      await runner.run(args);
      return;
    }

    final completion = await puro(args, nothrow: true);
    exitCode = completion.exitCode ?? 1;
  }
}
