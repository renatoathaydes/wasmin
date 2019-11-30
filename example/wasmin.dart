import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:wasmin/src/compile.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  // compile Wasmin to WASM
  compile('example.wasmin', 'output.wasm');

  // compile Wasmin to WAT
  compile('example.wasmin', 'output.wat', TargetFormat.wat);

  // to compile only to the AST (e.g. print the AST to stdout)
  final astSink = StreamController<AstNode>();
  stdout.addStream(astSink.stream
      .map((node) => node.toString() + "\n")
      .transform(const Utf8Encoder()));

  compileWasmin(
    'input-source-name',
    ['let x = 10;', 'let y = 20;'],
    astSink,
  );
}
