import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wasmin/src/compile.dart';
import 'package:wasmin/wasmin.dart';

void main() async {
  final tempDir = await Directory.systemTemp.createTemp('wat-test');
  group('success', () {
    test('nothing', checkWat('nothing.wasmin', tempDir));
    test('trivial', checkWat('trivial.wasmin', tempDir));
    test('simple', checkWat('simple.wasmin', tempDir));
  });
}

Future<void> Function() checkWat(String wasminFile, Directory tempDir) {
  return () async {
    final input = 'test/test_programs/$wasminFile';
    if (!await File(input).exists()) {
      throw Exception('Cannot run test as $input file does not exist');
    }
    final expectedWatFile = File('test/test_programs/$wasminFile.wat');
    if (!await expectedWatFile.exists()) {
      throw Exception(
          'Cannot run test as ${expectedWatFile.path} file does not exist');
    }

    final expectedWat = await expectedWatFile.readAsString();
    final compileOutput = '${tempDir.path}/$wasminFile.wat';

    final result = await compile(input, compileOutput, TargetFormat.wat);

    expect(result, equals(CompilationResult.success));
    final wat = await File(compileOutput).readAsString();
    expect(wat, equalsIgnoringWhitespace(expectedWat));
  };
}
