import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'parse/iterator.dart';
import 'parse/parse.dart';
import 'text_sink.dart';

enum TargetFormat { wat, wasm }

typedef Future<void> WasminSink(Future<WasminUnit> programUnit);

Future<void> compile(String inputFile, String outputFile,
    [TargetFormat targetFormat = TargetFormat.wasm]) async {
  final chunks =
      await File(inputFile).openRead().transform(utf8.decoder).toList();

  final out = File(outputFile);

  await out.openWrite().use((writer) async {
    final WasminSink sink = WasmTextSink(writer);
    final programUnit = compileWasmin(inputFile, chunks);
    await sink(programUnit);
  });
}

Future<WasminUnit> compileWasmin(
    String inputName, Iterable<String> chunks) async {
  final parser = WasminParser();

  final iterator = ParserIterator.fromChunks(chunks);

  try {
    final program = await parser.parse(iterator);
    return program;
  } on Exception catch (e) {
    print('[ERROR] ${inputName}:${iterator.position} - $e');
    // FIXME emit compilation error elements instead of rethrowing
    rethrow;
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
