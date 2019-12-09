import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';

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

class ExpressionParser with WordBasedParser<Expression> {
  final WordParser words;
  final TypeContext _typeContext;
  Expression _expr;
  bool _done = false;

  ExpressionParser(this.words,
      [this._typeContext = const WasmDefaultTypeContext()]);

  @override
  ParseResult parse(RuneIterator runes) {
    reset();

    final result = whitespaces.parse(runes);
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
      var word = nextWord(runes);
      if (word.isNotEmpty) members.add(ParsedGroup.entity(word));
      whitespaces.parse(runes);
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

  void reset() {
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
    reset();
    return expr;
  }
}
