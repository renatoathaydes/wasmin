import 'package:wasmin/src/type_check.dart';

import 'ast.dart';

const whitespace = {
  ' ', '\r', '\n', '\t', //
};

const separators = {
  ...whitespace, ',', ';', '[', ']', '(', ')', '{', '}', //
  '=', '!', '<', '>', //
};

enum ParseResult { CONTINUE, DONE, FAIL }

bool _separator(String rune) => separators.contains(rune);

class WasminParser {
  final _wordParser = WordParser();

  Stream<AstNode> parse(RuneIterator runes) async* {
    final expr = ExpressionParser(_wordParser);
    final let = LetParser(expr);
    ParseResult result = ParseResult.CONTINUE;

    while (result == ParseResult.CONTINUE) {
      result = _wordParser.parse(runes);
      Parser currentParser;
      switch (result) {
        case ParseResult.CONTINUE:
          final word = _wordParser.consumeWord();
//          print("Word: '$word'");
          if (word == 'let') {
            currentParser = let;
          } else if (word.isEmpty) {
//            print("Got empty word, skipping separator");
            runes.moveNext();
          } else {
            throw "top-level element not allowed: '$word'";
          }
          break;
        case ParseResult.DONE:
          break;
        case ParseResult.FAIL:
          throw 'unreachable';
      }
      if (currentParser != null) {
        result = currentParser.parse(runes);
        if (result == ParseResult.FAIL) {
          throw currentParser.failure;
        } else {
          yield currentParser.consume();
        }
      }
    }
  }
}

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
  final _whitespaces = const SkipWhitespaces();
  WordParser _words;
  String failure;

  String _nextWord(RuneIterator runes) {
    _whitespaces.parse(runes);
    _words.parse(runes);
    return _words.consumeWord();
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
    if (separators.contains(rune)) return ParseResult.DONE;
    _buffer.write(rune);
    return ParseResult.CONTINUE;
  }

  @override
  AstNode consume() => const Noop();
}

class LetParser with WordBasedParser {
  String _id = '';
  Expression _expression;
  final ExpressionParser _expr;

  final _whitespaces = const SkipWhitespaces();
  final WordParser _words;

  LetParser(this._expr) : _words = _expr._words;

  @override
  ParseResult parse(RuneIterator runes) {
    _reset();
    var word = _nextWord(runes);
    if (word.isEmpty) {
      failure = "Incomplete let expresion. Expected identifier!";
      return ParseResult.FAIL;
    }
    _id = word;

    _whitespaces.parse(runes);

    if (runes.currentAsString != '=') {
      failure = "Incomplete let expresion. Expected '='!";
      return ParseResult.FAIL;
    }

    // drop '='
    runes.moveNext();

    final result = _expr.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = "Let expression error: ${_expr.failure}";
    } else {
      _expression = _expr.consume();
    }
    return result;
  }

  void _reset() {
    _id = '';
    _expression = null;
    failure = null;
  }

  @override
  Let consume() {
    if (_id.isEmpty) throw Exception('Let identifier has not been set');
    if (_expression == null) throw Exception('Let expression has not been set');
    final let = Let(_id, _expression);
    _reset();
    return let;
  }
}

class ExpressionParser with WordBasedParser {
  String _op = '';
  List<String> _args = <String>[];
  final WordParser _words;

  ExpressionParser(this._words);

  @override
  ParseResult parse(RuneIterator runes) {
    _reset();
    var word = _nextWord(runes);
    if (word.isEmpty) {
      failure = "Empty expression";
      return ParseResult.FAIL;
    }
    _op = word;

    var result = _whitespaces.parse(runes);

    if (_separator(runes.currentAsString)) return ParseResult.CONTINUE;

    while (result == ParseResult.CONTINUE) {
      result = _whitespaces.parse(runes);
      if (result == ParseResult.DONE) return result;
      if (_separator(runes.currentAsString)) return ParseResult.CONTINUE;
      word = _nextWord(runes);
      if (word.isEmpty) return ParseResult.CONTINUE;
      _args.add(word);
    }

    return result;
  }

  void _reset() {
    _op = '';
    _args = <String>[];
    failure = null;
  }

  @override
  Expression consume() {
    if (_op.isEmpty) throw Exception('op has not been set');
    final expr = exprWithInferredType(_op, _args);
    _reset();
    return expr;
  }
}
