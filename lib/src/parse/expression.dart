import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';

abstract class ParsedExpression {
  const ParsedExpression._();

  bool get isAssignment => false;

  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(List<String>) onErrors,
  });
}

class _SingleMember extends ParsedExpression {
  final String name;

  const _SingleMember(this.name) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression> members) onGroup,
    T Function(String value) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(List<String>) onErrors,
  }) {
    return onMember(name);
  }
}

class _Error extends ParsedExpression {
  final List<String> messages;

  const _Error(this.messages) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression> members) onGroup,
    T Function(String value) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(List<String>) onErrors,
  }) {
    return onErrors(messages);
  }
}

class _GroupedExpression extends ParsedExpression {
  final List<ParsedExpression> members;

  const _GroupedExpression(this.members) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(List<String>) onErrors,
  }) {
    return onGroup(members);
  }
}

class _Assignment extends ParsedExpression {
  final String keyword;
  final String id;
  final ParsedExpression value;
  @override
  final isAssignment = true;

  const _Assignment(this.keyword, this.id, this.value) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(List<String>) onErrors,
  }) {
    return onAssignment(keyword, id, value);
  }
}

class _UnterminatedExpression implements Exception {
  const _UnterminatedExpression();
}

class ExpressionParser with WordBasedParser<Expression> {
  @override
  final WordParser words;
  final ParsingContext _context;
  Expression _expr;
  bool _done = false;

  ExpressionParser(this.words, this._context);

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
    final isEnd = _endGroupFunction(runes);
    if (_done) return _unterminatedExpression();
    ParsedExpression group;
    try {
      group = _parseToGroupEnd(runes, isEnd);
    } on _UnterminatedExpression {
      return _unterminatedExpression();
    }
    _expr = exprWithInferredType(group, _context);
    return _done ? ParseResult.DONE : ParseResult.CONTINUE;
  }

  ParsedExpression _parseToGroupEnd(
      RuneIterator runes, bool Function(RuneIterator) isEnd) {
    final members = <ParsedExpression>[];
    while (!isEnd(runes)) {
      var word = nextWord(runes);
      if (word.isNotEmpty) {
        members.add(_SingleMember(word));
      }

      whitespaces.parse(runes);

      // check if the symbol after the word has special meaning
      final nextSymbol = runes.currentAsString;
      if (nextSymbol == '(') {
        _done = !runes.moveNext();
        members.add(_parseToGroupEnd(runes, _isCloseBracket));
      } else if (nextSymbol == '=') {
        _done = !runes.moveNext();
        members.add(_parseToAssignmentEnd(runes, members));
      } else if (word.isEmpty) {
        if (nextSymbol == null) {
          throw const _UnterminatedExpression();
        } else {
          return _Error(['expression to be closed'.wasExpected(runes, false)]);
        }
      }
    }
    if (members.isEmpty) throw const _UnterminatedExpression();
    _done = !runes.moveNext();
    final errors = members.whereType<_Error>();
    final result = errors.isEmpty ? members : errors.toList(growable: false);
    if (result.length == 1) return result[0];
    return _GroupedExpression(result);
  }

  bool Function(RuneIterator) _endGroupFunction(RuneIterator runes) {
    if (runes.currentAsString == '(') {
      _done = !runes.moveNext();
      return _isCloseBracket;
    }
    return _isEndOfExpression;
  }

  void reset() {
    _expr = null;
    failure = null;
    _done = false;
  }

  ParseResult _unterminatedExpression() {
    failure = 'Unterminated expression';
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

  ParsedExpression _parseToAssignmentEnd(
      RuneIterator runes, List<ParsedExpression> members) {
    if (_done) {
      return _Error(['assignment expression'.wasExpected(runes, false)]);
    }
    if (members.isEmpty || members.length > 2) {
      return _Error(["Unexpected '='"]);
    }
    final keywordExpr = members.removeAt(0);
    final idExpr = members.isNotEmpty ? members.removeAt(0) : null;
    final value = _parseToGroupEnd(runes, _endGroupFunction(runes));
    final errors = <String>[];
    String keyword;
    String id;
    if (keywordExpr is _SingleMember && keywordExpr.name.isAssignmentKeyword) {
      keyword = keywordExpr.name;
    } else {
      errors.add('Malformed assignment: '
          "'let' or 'mut' keywords were expected, but got ${keywordExpr.match(
        onGroup: (_) => 'a multi-expression',
        onMember: (m) => "'$m' instead",
        onAssignment: (k, i, v) => 'a nested assignment',
        onErrors: (err) => 'an invalid expression: $err',
      )}");
    }
    if (idExpr is _SingleMember && idExpr.name.isValidIdentifier) {
      id = idExpr.name;
    } else {
      errors.add('Malformed assignment: '
          "expected an identifier, but got ${keywordExpr.match(
        onGroup: (_) => 'a multi-expression',
        onMember: (m) => "an invalid identifier: '$m'",
        onAssignment: (k, i, v) => 'a nested assignment',
        onErrors: (err) => 'an invalid expression: $err',
      )}");
    }
    if (value is _Error) {
      value..messages.addAll(errors);
      return value;
    } else if (errors.isNotEmpty) {
      return _Error(errors);
    } else {
      return _Assignment(keyword, id, value);
    }
  }
}
