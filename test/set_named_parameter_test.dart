import 'package:analyzer/dart/ast/ast.dart';
import 'package:indent/indent.dart';
import 'package:sidekick_core/sidekick_core.dart';
import 'package:test/test.dart';

import '../tool/src/main_file_modifiers.dart';
import '../tool/src/modifiable_source_file.dart';

void main() {
  test('add first parameter', () {
    final source = _tempSourceFile(
      StringIndentation("""
        |void main() {
        |  foo();
        |}
        """).trimMargin(),
    );
    final fooMethod = source.findMethodInvocationByName('foo');
    setNamedParameter(source, fooMethod, name: 'bar', value: "'c'");
    expect(source.content, contains("  foo(bar: 'c');"));
  });

  test('update first parameter', () {
    final source = _tempSourceFile(
      StringIndentation("""
        |void main() {
        |  foo(bar: 'a');
        |}
        """).trimMargin(),
    );
    final fooMethod = source.findMethodInvocationByName('foo');
    setNamedParameter(source, fooMethod, name: 'bar', value: "'c'");
    expect(source.content, contains("  foo(bar: 'c');"));
  });

  test('add second param single line', () {
    final source = _tempSourceFile(
      StringIndentation("""
        |void main() {
        |  foo(qwer: 'a');
        |}
        """).trimMargin(),
    );
    final fooMethod = source.findMethodInvocationByName('foo');
    setNamedParameter(source, fooMethod, name: 'bar', value: "'c'");
    expect(source.content, contains("  foo(qwer: 'a', bar: 'c');"));
  });

  test('add second param multi line', () {
    final source = _tempSourceFile(
      StringIndentation("""
        |void main() {
        |  foo(
        |    qwer: 'a',
        |  );
        |}
        """).trimMargin(),
    );
    final fooMethod = source.findMethodInvocationByName('foo');
    setNamedParameter(source, fooMethod, name: 'bar', value: "'c'");
    expect(
      source.content,
      contains("  foo(\n    qwer: 'a',\n    bar: 'c',\n  );"),
    );
  });
}

extension on ModifiableSourceFile {
  MethodInvocation findMethodInvocationByName(String name) {
    return analyze()
        .nodes
        .whereType<MethodInvocation>()
        .firstWhere((node) => node.methodName.name == name);
  }
}

ModifiableSourceFile _tempSourceFile(String content) {
  final dir = Directory.systemTemp.createTempSync('sidekick_puro_plugin');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = dir.file('source.dart')..createSync();
  file.writeAsStringSync(content);
  return ModifiableSourceFile(file);
}
