import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:wasmin/src/compile.dart';
import 'package:wasmin/wasmin.dart';

void main() async {
  // compile Wasmin to WASM
  await compile('example.wasmin', 'output.wasm');

  // compile Wasmin to WAT
  await compile('example.wasmin', 'output.wat', TargetFormat.wat);

  // compile only to the AST, then print the AST to stdout
  final astSink = StreamController<AstNode>();
  await stdout.addStream(astSink.stream
      .map((node) => node.toString() + "\n")
      .transform(const Utf8Encoder()));

  await compileWasmin(
    'input-source-name',
    ['let x = 10;', 'let y = 20;'],
    astSink,
  );
}
