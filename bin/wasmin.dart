import 'dart:io';

import 'package:args/args.dart';
import 'package:wasmin/src/compile.dart';

void main(List<String> args) async {
  final argParser = ArgParser();
  argParser
    ..addOption('output', abbr: 'o', help: 'output file')
    ..addOption('runtime',
        allowed: {'wasmtime', 'wasmer'},
        defaultsTo: 'wasmtime',
        abbr: 't',
        help: 'the runtime to use to run programs')
    ..addFlag('help', abbr: 'h', help: 'show help message')
    ..addFlag('run', abbr: 'r', help: 'run the program after compilation');

  ArgResults parsedArgs;
  try {
    parsedArgs = argParser.parse(args);
  } catch (e) {
    print(e.toString());
    exit(1);
  }

  if (parsedArgs.wasParsed('help')) {
    print('wasmin version 0.0.0\n\nUsage:\n${argParser.usage}');
    exit(0);
  }

  final inputs = parsedArgs.rest;

  if (inputs.isEmpty) {
    print('At least one input file is required');
    exit(1);
  }

  final output = parsedArgs['output']?.toString();

  final result = await compile(parsedArgs.rest.first, output);

  switch (result) {
    case CompilationResult.error:
      print('There were compilation errors, see the compiler log for details');
      exit(1);
      break;
    case CompilationResult.success:
    // continue
  }

  if (parsedArgs.wasParsed('run')) {
    final runtime = parsedArgs['runtime'].toString();
    final result = await Process.run(runtime, [output]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
}
