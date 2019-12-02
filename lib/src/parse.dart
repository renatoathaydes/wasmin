import 'ast.dart';
import 'type_check.dart';
import 'type_context.dart';

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
  final _context = ParsingContext();

  Stream<AstNode> parse(RuneIterator runes) async* {
    final expr = ExpressionParser(_wordParser, _context);
    final let = LetParser(expr, _context);
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
    if (_separator(rune)) return ParseResult.DONE;
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
  final TypeContext _typeContext;

  LetParser(this._expr, [this._typeContext = const WasmDefaultTypeContext()])
      : _words = _expr._words;

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

      // success!! Remember defined variable
      if (_typeContext is MutableTypeContext) {
        (_typeContext as MutableTypeContext)
            .addFun(_id, FunctionType(_expression.type, const []));
      }
    }
    return result;
  }

  void _reset() {
    _id = '';
    _expression = null;
    _expr._reset();
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

class ParsedGroup {
  final String _entity;
  final List<ParsedGroup> _members;

  const ParsedGroup.empty()
      : _entity = null,
        _members = const [];

  const ParsedGroup.entity(String entity)
      : _entity = entity,
        _members = null;

  const ParsedGroup.group(List<ParsedGroup> members)
      : _entity = null,
        _members = members;

  int get length => _members?.length ?? 1;

  T match<T>(
      {T Function(List<ParsedGroup> members) onGroup,
      T Function(String value) onMember}) {
    if (_entity != null) return onMember(_entity);
    if (_members != null) return onGroup(_members);
    throw 'unreachable';
  }
}

class _UnterminatedExpression implements Exception {
  const _UnterminatedExpression();
}

class ExpressionParser with WordBasedParser {
  final WordParser _words;
  final TypeContext _typeContext;
  Expression _expr;
  bool _done = false;

  ExpressionParser(this._words,
      [this._typeContext = const WasmDefaultTypeContext()]);

  @override
  ParseResult parse(RuneIterator runes) {
    _reset();

    final result = _whitespaces.parse(runes);
    if (result == ParseResult.DONE) {
      failure = 'Empty expression';
      return ParseResult.FAIL;
    }

    try {
      return _parseGroup(runes);
    } catch (e) {
      failure = e.toString();
      return ParseResult.FAIL;
    }
  }

  ParseResult _parseGroup(RuneIterator runes) {
    var isEnd = _isEndOfExpression;
    if (runes.currentAsString == '(') {
      isEnd = _isCloseBracket;
      _done = !runes.moveNext();
      if (_done) return _unterminatedExpression();
    }
    ParsedGroup group;
    try {
      group = _parseToGroupEnd(runes, isEnd);
    } on _UnterminatedExpression {
      return _unterminatedExpression();
    }
    _expr = exprWithInferredType(group, _typeContext);
    return _done ? ParseResult.DONE : ParseResult.CONTINUE;
  }

  ParsedGroup _parseToGroupEnd(
      RuneIterator runes, bool Function(RuneIterator) isEnd) {
    final members = <ParsedGroup>[];
    while (!isEnd(runes)) {
      var word = _nextWord(runes);
      if (word.isNotEmpty) members.add(ParsedGroup.entity(word));
      _whitespaces.parse(runes);
      if (runes.currentAsString == '(') {
        _done = !runes.moveNext();
        members.add(_parseToGroupEnd(runes, _isCloseBracket));
      } else if (word.isEmpty) {
        throw const _UnterminatedExpression();
      }
    }
    if (members.isEmpty) throw const _UnterminatedExpression();
    _done = !runes.moveNext();
    return ParsedGroup.group(members);
  }

  void _reset() {
    _expr = null;
    failure = null;
    _done = false;
  }

  ParseResult _unterminatedExpression() {
    failure = "Unterminated expression";
    return ParseResult.FAIL;
  }

  static bool _isCloseBracket(RuneIterator runes) =>
      runes.currentAsString == ')';

  static bool _isEndOfExpression(RuneIterator runes) =>
      runes.currentAsString == null || runes.currentAsString == ';';

  @override
  Expression consume() {
    if (_expr == null) throw Exception('expression not parsed yet');
    final expr = _expr;
    _reset();
    return expr;
  }
}
