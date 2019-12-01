import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ast.dart';
import 'iterator.dart';
import 'parse.dart';
import 'text_sink.dart';

enum TargetFormat { wat, wasm }

Future<void> compile(String inputFile, String outputFile,
    [TargetFormat targetFormat = TargetFormat.wasm]) async {
  final lines = await File(inputFile)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();

  final out = File(outputFile);

  out.openWrite().use((writer) async {
    final sink = TextSink(writer);
    final source = compileWasmin(inputFile, lines);
    await for (final node in source) {
      sink.add(node);
    }
    sink.close();
  });
}

Stream<AstNode> compileWasmin(
    String inputName, Iterable<String> inputLines) async* {
  final parser = WasminParser();

  final iterator = ParserIterator.fromLines(inputLines);
  Stream<AstNode> ast = parser.parse(iterator);

  try {
    await for (final node in ast) {
      yield node;
    }
  } on Exception catch (e) {
    print("[ERROR] ${inputName}:${iterator.position} - $e");
  }
}

extension on IOSink {
  FutureOr<void> use(FutureOr<void> Function(IOSink) user) async {
    try {
      await user(this);
    } finally {
      await close();
    }
  }
}
