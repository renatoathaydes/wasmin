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
    [String? outputFile, TargetFormat targetFormat = TargetFormat.wasm]) async {
  final chunks =
      await File(inputFile).openRead().transform(utf8.decoder).toList();

  _WasminWriter out;

  if (outputFile == null) {
    out = _SysoutWriter();
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
  FutureOr<T> use<T>(FutureOr<T> Function(StringSink) user);
}

class _SysoutWriter with _WasminWriter, StringSink {
  final _toPrint = <Object?>[];

  @override
  FutureOr<T> use<T>(FutureOr<T> Function(StringSink) user) {
    final result = user(this);
    flush();
    return result;
  }

  @override
  void write(Object? obj) {
    _write(obj?.toString());
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    final writeSeparator = separator != null && separator.isNotEmpty;
    for (final obj in objects) {
      _write(obj?.toString());
      if (writeSeparator) _write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) {
    _write(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? obj = '']) {
    _write(obj.toString());
    _write('\n');
  }

  void _write(String? obj) {
    _toPrint.add(obj);
    if (obj != null && obj.contains('\n')) {
      flush();
    }
  }

  void flush() {
    _toPrint.forEach(print);
    _toPrint.clear();
  }
}

class _FileWriter with _WasminWriter {
  final File file;

  _FileWriter(this.file);

  @override
  FutureOr<T> use<T>(FutureOr<T> Function(StringSink) user) {
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
