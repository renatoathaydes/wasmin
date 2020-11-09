import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:path/path.dart' as path;

FileFilter dartFileFilter = (f) => path.extension(f.path) == '.dart';

final libDirDartFiles = dir('lib', fileFilter: dartFileFilter);
final allDartFiles = dir('.', fileFilter: dartFileFilter);

final checkImportsTask = Task(checkImports,
    description: 'Checks dart file imports are allowed',
    runCondition: RunOnChanges(inputs: libDirDartFiles));

final formatCodeTask = Task(formatCode,
    description: 'Formats all Dart source code',
    runCondition: RunOnChanges(inputs: allDartFiles));

final analyzeCodeTask = Task(analyzeCode,
    description: 'Analyzes Dart source code',
    runCondition: RunOnChanges(inputs: allDartFiles));

final compileWatTask = WatCompiler(Directory('test/test_programs')).toTask();

final testTask = Task(test,
    description: 'Runs all tests. Arguments can be used to provide the '
        'platforms the tests should run on.',
    dependsOn: {analyzeCodeTask.name, compileWatTask.name},
    argsValidator: const AcceptAnyArgs(),
    runCondition:
        RunOnChanges(inputs: dirs(const ['lib', 'bin', 'test', 'example'])));

final verifyTask = Task((_) => null, // no action, just grouping other tasks
    name: 'verify',
    description: 'Verifies code style and linters, runs tests',
    dependsOn: {'checkImports', 'formatCode', 'analyzeCode', 'test'});

final cleanTask = Task(
    (_) async =>
        await ignoreExceptions(() => deleteOutputs({testTask, compileWatTask})),
    name: 'clean',
    description: 'Deletes the outputs of all other tasks');

Future<void> main(List<String> args) async {
  await run(args, tasks: {
    cleanTask,
    checkImportsTask,
    formatCodeTask,
    analyzeCodeTask,
    compileWatTask,
    testTask,
    verifyTask,
  }, defaultTasks: {
    verifyTask
  });
}

Future<void> test(List<String> platforms) async {
  if (platforms.isEmpty) {
    platforms = const ['chrome', 'vm'];
  }
  final platformArgs = platforms.expand((p) => ['-p', p]);
  final code = await execProc(Process.start('dart', ['test', ...platformArgs]),
      name: 'Dart Tests');
  if (code != 0) failBuild(reason: 'Tests failed');
}

Future<void> checkImports(List<String> _) async {
  await for (final file in libDirDartFiles.files) {
    final illegalImports = (await file.readAsLines()).where(
        (line) => line.contains(RegExp("^import\\s+['\"]package:wasmin")));
    if (illegalImports.isNotEmpty) {
      failBuild(
          reason: 'File ${file.path} contains '
              'self import to the dartle package: ${illegalImports}');
    }
  }
}

Future<void> formatCode(List<String> _) async {
  final code = await execProc(Process.start('dart', const ['format', '.']),
      name: 'Dart Formatter');
  if (code != 0) failBuild(reason: 'Dart Formatter failed');
}

Future<void> analyzeCode(List<String> _) async {
  final code = await execProc(Process.start('dart', const ['analyze', '.']),
      name: 'Dart Analyzer', successMode: StreamRedirectMode.stdout_stderr);
  if (code != 0) failBuild(reason: 'Dart Analyzer failed');
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

  List<FileSystemEntity> _watFiles() {
    return testProgramsDir
        .listSync()
        .where((entity) => path.extension(entity.path) == '.wat')
        .toList();
  }

  Task toTask() {
    final watFiles = _watFiles();
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
