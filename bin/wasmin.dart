import 'dart:io';

import 'package:args/args.dart';
import 'package:wasmin/src/compile.dart';

void main(List<String> args) async {
  final argParser = ArgParser();
  argParser
    ..addOption('output', abbr: 'o', help: 'output file')
    ..addFlag('help', abbr: 'h', help: 'show help message');

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

  if (!parsedArgs.wasParsed('output')) {
    print('No -o option provided. See usage with the --help flag.');
    exit(1);
  }

  await compile(parsedArgs.rest.first, parsedArgs['output'].toString());
}
