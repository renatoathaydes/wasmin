import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'parse/iterator.dart';
import 'parse/parse.dart';
import 'text_sink.dart';

enum TargetFormat { wat, wasm }

enum CompilationResult { success, error }

typedef WasminSink = Future<CompilationResult> Function(
    Future<WasminUnit> programUnit);

Future<CompilationResult> compile(String inputFile,
    [String outputFile, TargetFormat targetFormat = TargetFormat.wasm]) async {
  final chunks =
      await File(inputFile).openRead().transform(utf8.decoder).toList();

  _WasminWriter out;

  if (outputFile == null) {
    out = const _SysoutWriter();
  } else {
    out = _FileWriter(File(outputFile));
  }

  return await out.use((writer) async {
    final WasminSink sink = WasmTextSink(writer);
    final programUnit = compileWasmin(inputFile, chunks);
    return await sink(programUnit);
  });
}

Future<WasminUnit> compileWasmin(
    String inputName, Iterable<String> chunks) async {
  final parser = WasminParser();

  final parserState = ParserState.fromChunks(chunks);

  try {
    final program = await parser.parse(parserState);
    return program;
  } on Exception catch (e) {
    print('[ERROR] ${inputName}:${parserState.position} - $e');
    rethrow;
  }
}

mixin _WasminWriter {
  FutureOr<T> use<T>(FutureOr<T> Function(IOSink) user);
}

class _SysoutWriter with _WasminWriter {
  const _SysoutWriter();

  @override
  FutureOr<T> use<T>(FutureOr<T> Function(IOSink) user) {
    return user(stdout);
  }
}

class _FileWriter with _WasminWriter {
  final File file;

  _FileWriter(this.file);

  @override
  FutureOr<T> use<T>(FutureOr<T> Function(IOSink) user) {
    return file.openWrite().use(user);
  }
}

extension on IOSink {
  FutureOr<T> use<T>(FutureOr<T> Function(IOSink) user) async {
    try {
      return await user(this);
    } finally {
      await close();
    }
  }
}
