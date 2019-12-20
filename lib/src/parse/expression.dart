import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';

abstract class ParsedExpression {
  const ParsedExpression._();

  bool get isSingleMember => false;

  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(List<String>) onErrors,
  });
}

class _SingleMember extends ParsedExpression {
  final String name;

  @override
  final bool isSingleMember = true;

  const _SingleMember(this.name) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression> members) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String value) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
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
    T Function(ParsedExpression) onLoop,
    T Function(String value) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
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
    T Function(ParsedExpression) onLoop,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(List<String>) onErrors,
  }) {
    return onGroup(members);
  }
}

class _Assignment extends ParsedExpression {
  final String keyword;
  final String id;
  final ParsedExpression value;

  const _Assignment(this.keyword, this.id, this.value) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(List<String>) onErrors,
  }) {
    return onAssignment(keyword, id, value);
  }
}

class _If extends ParsedExpression {
  final ParsedExpression condition;
  final ParsedExpression thenExpression;
  final ParsedExpression elseExpression;

  const _If(this.condition, this.thenExpression, [this.elseExpression])
      : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(List<String>) onErrors,
  }) {
    return onIf(condition, thenExpression, elseExpression);
  }
}

class _Loop extends ParsedExpression {
  final ParsedExpression expression;

  _Loop(this.expression) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression>) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(List<String>) onErrors,
  }) {
    return onLoop(expression);
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
    } catch (e, s) {
      failure = e.toString();
      return ParseResult.FAIL;
    }
  }

  ParseResult _parseGroup(RuneIterator runes) {
    if (_done) return _unterminatedExpression();
    ParsedExpression group;
    try {
      group = _parseToGroupEnd(runes, false);
    } on _UnterminatedExpression {
      return _unterminatedExpression();
    }
    _expr = exprWithInferredType(group, _context);
    return _done ? ParseResult.DONE : ParseResult.CONTINUE;
  }

  ParsedExpression _parseToGroupEnd(
      RuneIterator runes, bool isOuterParensGroup) {
    whitespaces.parse(runes);
    final isParensGroup = runes.currentAsString == '(';
    final withinParens = isParensGroup || isOuterParensGroup;
    if (isParensGroup) runes.moveNext();
    final isEnd = isParensGroup
        ? _isCloseParens
        : isOuterParensGroup ? _isAnyEnd : _isEndOfExpression;
    final members = <ParsedExpression>[];
    while (!isEnd(runes)) {
      final word = nextWord(runes);
      if (word == 'if') {
        members.add(_parseIf(runes, withinParens));
        // if this is not a parens group, we're completely done now with 1 if-expr
        if (!isParensGroup) return members[0];
        // if it is within parens, and it's ended, stop consuming symbols
        if (withinParens && isEnd(runes)) break;
      } else if (word == 'loop') {
        members.add(_parseLoop(runes, withinParens));
        if (!isParensGroup) return members[0];
        if (withinParens && isEnd(runes)) break;
      } else if (word.isNotEmpty) {
        members.add(_SingleMember(word));
      }

      whitespaces.parse(runes);

      // check if the symbol after the word has special meaning
      final nextSymbol = runes.currentAsString;
      if (nextSymbol == '(') {
        members.add(_parseToGroupEnd(runes, false));
      } else if (nextSymbol == '=') {
        _done = !runes.moveNext();
        members.add(_parseToAssignmentEnd(runes, members, withinParens));
        if (!isParensGroup) return members[0];
        if (withinParens && isEnd(runes)) break;
      } else if (word.isEmpty) {
        if (nextSymbol == null) {
          throw const _UnterminatedExpression();
        } else if (!isEnd(runes)) {
          return _Error(['expression to be closed'.wasExpected(runes, false)]);
        }
      }
    }

    // if it's the outer group that ends, don't skip the group-ending character
    final outerGroupEnds =
        !isParensGroup && isOuterParensGroup && _isCloseParens(runes);
    if (!outerGroupEnds) {
      _done = !runes.moveNext();
    }
    if (members.isEmpty) throw const _UnterminatedExpression();
    final errors = members.whereType<_Error>();
    final result = errors.isEmpty ? members : errors.toList(growable: false);
    if (result.length == 1) return result[0];
    return _GroupedExpression(result);
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

  static bool _isCloseParens(RuneIterator runes) =>
      runes.currentAsString == ')';

  static bool _isEndOfExpression(RuneIterator runes) =>
      runes.currentAsString == null || runes.currentAsString == ';';

  static bool _isAnyEnd(RuneIterator runes) =>
      _isCloseParens(runes) || _isEndOfExpression(runes);

  @override
  Expression consume() {
    if (_expr == null) throw Exception('expression not parsed yet');
    final expr = _expr;
    reset();
    return expr;
  }

  ParsedExpression _parseToAssignmentEnd(
      RuneIterator runes, List<ParsedExpression> members, bool isParensGroup) {
    _done = whitespaces.parse(runes) == ParseResult.DONE;
    if (_done) {
      return _Error(['assignment expression'.wasExpected(runes, false)]);
    }
    if (members.length < 2) {
      return _Error(["Unexpected '='"]);
    }
    final prevExpr = members.removeLast();
    final prev2Expr = members.removeLast();
    final value = _parseToGroupEnd(runes, isParensGroup);
    final errors = <String>[];
    String keyword;
    String id;
    if (prev2Expr is _SingleMember && prev2Expr.name.isAssignmentKeyword) {
      keyword = prev2Expr.name;
    } else {
      errors.add('Malformed assignment: '
          "'let' or 'mut' keywords were expected, but got ${prevExpr.match(
        onGroup: (_) => 'a multi-expression',
        onLoop: (_) => 'a loop instead',
        onMember: (m) => "'$m' instead",
        onAssignment: (k, i, v) => 'a nested assignment',
        onIf: (c, t, [e]) => 'an if expression',
        onErrors: (err) => 'an invalid expression: $err',
      )}");
    }
    if (prevExpr is _SingleMember && prevExpr.name.isValidIdentifier) {
      id = prevExpr.name;
    } else {
      errors.add('Malformed assignment: '
          "expected an identifier, but got ${prevExpr.match(
        onGroup: (_) => 'a multi-expression',
        onLoop: (_) => 'a loop instead',
        onMember: (m) => "an invalid identifier: '$m'",
        onAssignment: (k, i, v) => 'a nested assignment',
        onIf: (c, t, [e]) => 'an if expression',
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

  ParsedExpression _parseIf(RuneIterator runes, bool isParensGroup) {
    final condExpr = _parseToGroupEnd(runes, isParensGroup);
    if (isParensGroup && runes.currentAsString == ')') {
      return _Error(
          ['if expression ended unexpectedly: no then branch provided']);
    }
    final thenExpr = _parseToGroupEnd(runes, isParensGroup);
    final noElse = (isParensGroup && _isCloseParens(runes)) ||
        runes.currentAsString == null;

    if (noElse) {
      return _If(condExpr, thenExpr);
    }

    final elseExpr = _parseToGroupEnd(runes, isParensGroup);
    return _If(condExpr, thenExpr, elseExpr);
  }

  ParsedExpression _parseLoop(RuneIterator runes, bool isParensGroup) {
    whitespaces.parse(runes);
    final expr = _parseToGroupEnd(runes, isParensGroup);
    return _Loop(expr);
  }
}
