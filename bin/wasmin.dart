import 'dart:io';

import 'package:args/args.dart';
import 'package:wasmin/src/compile.dart';

void main(List<String> args) async {
  exit(await run(args));
}

Future<int> run(List<String> args) async {
  final argParser = ArgParser();
  argParser
    ..addOption('output',
        abbr: 'o', help: 'output file (if not given, prints to stdout)')
    ..addOption('runtime',
        allowed: {'wasmtime', 'wasmer'},
        defaultsTo: 'wasmtime',
        abbr: 't',
        help: 'the runtime to use to run programs')
    ..addFlag('help', abbr: 'h', help: 'show help message')
    ..addFlag('run',
        abbr: 'r',
        help: 'run the program after compilation '
            '(must compile to a file by using the -o option)');

  ArgResults parsedArgs;
  try {
    parsedArgs = argParser.parse(args);
  } catch (e) {
    stderr.writeln('ERROR: ' + e.toString());
    return 1;
  }

  if (parsedArgs.wasParsed('help')) {
    print('wasmin version 0.0.0\n\nUsage:\n${argParser.usage}');
    return 0;
  }

  final inputs = parsedArgs.rest;

  if (inputs.isEmpty) {
    stderr.writeln('ERROR: At least one input file is required');
    return 1;
  }

  final output = parsedArgs['output']?.toString();

  final input = parsedArgs.rest.first;

  if (!await File(input).exists()) {
    stderr.writeln('ERROR: file does not exist: $input');
    return 1;
  }

  final result = await compile(input, output);

  switch (result) {
    case CompilationResult.error:
      stderr.writeln('There were compilation errors, '
          'see the compiler log for details');
      return 1;
    case CompilationResult.success:
    // continue
  }

  if (parsedArgs.wasParsed('run')) {
    if (output == null) {
      stderr.writeln('ERROR: Cannot run program as it was not compiled to a '
          'file.\nUse the -o option to compile the Wasmin program to a file.\n'
          'See usage (wasmin -h) for details.');
      return 2;
    } else {
      final runtime = parsedArgs['runtime'].toString();
      final result = await Process.run(runtime, [output]);
      print(result.stdout);
      print(result.stderr);
      return result.exitCode;
    }
  }

  return 0;
}
