import 'package:wasmin/src/parse/iterator.dart';

const whitespace = {
  ' ', '\r', '\n', '\t', //
};

const startLineComment = '#';

const separators = {
  ...whitespace, ',', ';', '[', ']', '(', ')', '{', '}', //
  '=', '!', '<', '>', startLineComment, //
};

const assignmentKeywords = {'let', 'mut'};

const keywords = {
  ...assignmentKeywords,
  'set',
  'get',
  'copy',
};

enum ParseResult { CONTINUE, DONE, FAIL }

mixin Parser<N> {
  /// The last failure seem by this parser.
  String get failure;

  /// Parse the runes emitted by the given iterator.
  ParseResult parse(ParserState runes);

  /// Consume the node parsed by this parser.
  ///
  /// If no node has been parsed successfully, returns null.
  N consume();
}

mixin RuneBasedParser<N> implements Parser<N> {
  @override
  ParseResult parse(ParserState runes) {
    var firstRun = true;
    do {
      var rune = runes.currentAsString;
      if (firstRun && rune == null) {
        runes.moveNext();
        rune = runes.currentAsString;
        if (rune == null) return ParseResult.DONE;
      }
      firstRun = false;
      final result = accept(rune);
      switch (result) {
        case ParseResult.FAIL:
          return ParseResult.FAIL;
        case ParseResult.DONE:
          return ParseResult.CONTINUE;
        case ParseResult.CONTINUE:
        // keep going
      }
    } while (runes.moveNext());
    return ParseResult.DONE;
  }

  ParseResult accept(String rune);
}

mixin WordBasedParser<N> implements Parser<N> {
  final whitespaces = SkipWhitespaces();
  @override
  String failure;

  WordParser get words;

  String nextWord(ParserState runes) {
    whitespaces.parse(runes);
    words.parse(runes);
    return words.consume();
  }
}

class SkipWhitespaces with RuneBasedParser<void> {
  bool parsingComment = false;

  SkipWhitespaces();

  @override
  final String failure = null;

  @override
  ParseResult parse(ParserState runes) {
    final result = super.parse(runes);
    if (result != ParseResult.CONTINUE) parsingComment = false;
    return result;
  }

  @override
  ParseResult accept(String rune) {
    if (parsingComment) {
      if (rune == '\n') parsingComment = false;
      return ParseResult.CONTINUE;
    } else if (rune == startLineComment) {
      parsingComment = true;
      return ParseResult.CONTINUE;
    } else if (rune.isWhitespace) return ParseResult.CONTINUE;
    return ParseResult.DONE;
  }

  @override
  void consume() => null;
}

class WordParser with RuneBasedParser<String> {
  final _buffer = StringBuffer();

  @override
  final String failure = null;

  @override
  String consume() {
    final word = _buffer.toString();
    _buffer.clear();
    return word;
  }

  @override
  ParseResult accept(String rune) {
    if (rune.isSeparator) return ParseResult.DONE;
    _buffer.write(rune);
    return ParseResult.CONTINUE;
  }
}

extension ParserStringExtensions on String {
  bool get isWhitespace => whitespace.contains(this);

  bool get isNotWhitespace => !isWhitespace;

  bool get isSeparator => separators.contains(this);

  bool get isValidIdentifier =>
      !keywords.contains(this) && _allValidIdentifierRunes(runes);

  bool get isAssignmentKeyword => assignmentKeywords.contains(this);

  String quote() => "'${this}'";

  String wasExpected(ParserState actual, bool quoteExpected) {
    return 'Expected ${quoteExpected ? quote() : this}, '
        "got ${actual.currentAsString?.quote() ?? 'EOF'}";
  }
}

bool _allValidIdentifierRunes(Runes runes) {
  for (final rune in runes) {
    if (separators.contains(rune)) return false;
  }
  return true;
}
