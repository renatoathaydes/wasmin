import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final testProgramsDir = Directory('test/test_programs');

  await run(args, tasks: {await WatCompiler(testProgramsDir).toTask()});
}

class WatCompiler {
  final Directory testProgramsDir;

  WatCompiler(this.testProgramsDir);

  Future<void> call(List<String> _) async {
    final watFiles = await _watFiles();
    final testWasmFiles = watFiles
        .map((entity) => path.setExtension(entity.path, '.wasm'))
        .toList();

    for (var i = 0; i < watFiles.length; i++) {
      final wat = watFiles[i];
      final wasm = testWasmFiles[i];

      final proc = await Process.runSync('wat2wasm', [wat.path, '-o', wasm]);

      if (proc.exitCode != 0) {
        print(proc.stdout);
        print(proc.stderr);
        throw DartleException(message: 'Unable to compile $wat');
      }
    }
  }

  Future<List<FileSystemEntity>> _watFiles() {
    return testProgramsDir
        .list()
        .where((entity) => path.extension(entity.path) == '.wat')
        .toList();
  }

  Future<Task> toTask() async {
    final watFiles = await _watFiles();
    final testWasmFiles = watFiles
        .map((entity) => path.setExtension(entity.path, '.wasm'))
        .toList();

    return Task(this,
        name: 'compileWatTestFiles',
        description: 'Compiles the test WAT files to WASM',
        runCondition: RunOnChanges(
          inputs: FileCollection(watFiles),
          outputs: files(testWasmFiles),
        ));
  }
}
