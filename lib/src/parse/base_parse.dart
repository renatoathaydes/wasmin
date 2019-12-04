import '../ast.dart';

const whitespace = {
  ' ', '\r', '\n', '\t', //
};

const separators = {
  ...whitespace, ',', ';', '[', ']', '(', ')', '{', '}', //
  '=', '!', '<', '>', //
};

enum ParseResult { CONTINUE, DONE, FAIL }

bool isSeparator(String rune) => separators.contains(rune);

mixin Parser {
  /// The last failure seem by this parser.
  String get failure;

  /// Parse the runes emitted by the given iterator.
  ParseResult parse(RuneIterator runes);

  /// Consume the AST node parsed by this parser.
  ///
  /// If no node has been parsed successfully, returns null.
  AstNode consume();
}

mixin RuneBasedParser implements Parser {
  ParseResult parse(RuneIterator runes) {
    bool firstRune = runes.currentAsString != null;
    while (firstRune || runes.moveNext()) {
      firstRune = false;
      final rune = runes.currentAsString;
      final result = accept(rune);
      switch (result) {
        case ParseResult.FAIL:
          return ParseResult.FAIL;
        case ParseResult.DONE:
          return ParseResult.CONTINUE;
        case ParseResult.CONTINUE:
        // keep going
      }
    }
    return ParseResult.DONE;
  }

  ParseResult accept(String rune);
}

mixin WordBasedParser implements Parser {
  final whitespaces = const SkipWhitespaces();
  WordParser words;
  String failure;

  String nextWord(RuneIterator runes) {
    whitespaces.parse(runes);
    words.parse(runes);
    return words.consumeWord();
  }
}

class SkipWhitespaces with RuneBasedParser {
  const SkipWhitespaces();

  final String failure = null;

  bool _whitespace(String rune) => whitespace.contains(rune);

  @override
  ParseResult accept(String rune) {
    if (_whitespace(rune)) return ParseResult.CONTINUE;
    return ParseResult.DONE;
  }

  @override
  AstNode consume() => const Noop();
}

class WordParser with RuneBasedParser {
  final _buffer = StringBuffer();

  final String failure = null;

  String consumeWord() {
    final word = _buffer.toString();
    _buffer.clear();
    return word;
  }

  @override
  ParseResult accept(String rune) {
    if (isSeparator(rune)) return ParseResult.DONE;
    _buffer.write(rune);
    return ParseResult.CONTINUE;
  }

  @override
  AstNode consume() => const Noop();
}
