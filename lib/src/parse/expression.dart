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

class ExpressionParser with WordBasedParser<Expression> {
  @override
  final WordParser words;
  final ParsingContext _context;
  Expression _expr;

  ExpressionParser(this.words, this._context);

  @override
  ParseResult parse(RuneIterator runes) {
    reset();
    final expr = _parseExpression(runes, false);
    try {
      _expr = exprWithInferredType(expr, _context);
    } on TypeCheckException catch (e, s) {
      failure = e.message;
      return ParseResult.FAIL;
    } catch (e, s) {
      // FIXME parser should not throw Exception
      failure = e.toString();
      return ParseResult.FAIL;
    }

    return runes.currentAsString == null
        ? ParseResult.DONE
        : ParseResult.CONTINUE;
  }

  ParsedExpression _parseExpression(RuneIterator runes, bool withinParens) {
    whitespaces.parse(runes);
    if (runes.currentAsString == '(') {
      runes.moveNext();
      return _parseToGroupEnd(runes);
    } else {
      return _parseToExpressionEnd(runes, withinParens);
    }
  }

  ParsedExpression _parseToGroupEnd(RuneIterator runes) {
    whitespaces.parse(runes);
    final members = <ParsedExpression>[];
    while (runes.currentAsString != ')' && runes.currentAsString != null) {
      members.add(_parseToExpressionEnd(runes, true));
      whitespaces.parse(runes);
    }

    if (runes.currentAsString == ')') {
      runes.moveNext();
    } else {
      return _Error([')'.wasExpected(runes, true)]);
    }

    final errors = members.whereType<_Error>();
    final result = errors.isEmpty ? members : errors.toList(growable: false);
    if (result.length == 1) return result[0];
    return _GroupedExpression(result);
  }

  ParsedExpression _parseToExpressionEnd(
      RuneIterator runes, bool withinParens) {
    whitespaces.parse(runes);
    final members = <ParsedExpression>[];

    final firstWord = nextWord(runes);
    if (firstWord == 'if') return _parseIf(runes, withinParens);
    if (firstWord == 'loop') return _parseLoop(runes, withinParens);
    if (firstWord == 'let' || firstWord == 'mut') {
      return _parseToAssignmentEnd(runes, firstWord, members, withinParens);
    }

    if (firstWord.isEmpty) {
      if (runes.currentAsString == '(') {
        runes.moveNext();
        return _parseToGroupEnd(runes);
      } else {
        return _verifyExpressionEnd(runes, members, withinParens);
      }
    } else {
      // check if this is a re-assignment
      whitespaces.parse(runes);
      if (runes.currentAsString == '=') {
        runes.moveNext();
        final value = _parseExpression(runes, withinParens);
        return _Assignment('', firstWord, value);
      }

      members.add(_SingleMember(firstWord));
    }

    while (true) {
      final word = nextWord(runes);
      if (word.isNotEmpty) {
        members.add(_SingleMember(word));
      } else if (runes.currentAsString == '(') {
        runes.moveNext();
        members.add(_parseToGroupEnd(runes));
      } else {
        return _verifyExpressionEnd(runes, members, withinParens);
      }
    }
  }

  ParsedExpression _verifyExpressionEnd(
      RuneIterator runes, List<ParsedExpression> members, bool withinParens) {
    // check if the symbol after the word has special meaning or ends the
    // current group properly
    final nextSymbol = runes.currentAsString;
    if (nextSymbol == ')') {
      if (!withinParens) {
        return _Error([';'.wasExpected(runes, true)]);
      }
    } else if (nextSymbol == ';') {
      runes.moveNext();
    } else if (nextSymbol == null) {
      if (withinParens) {
        return _Error([')'.wasExpected(runes, true)]);
      }
    } else {
      return _Error([(withinParens ? ')' : ';').wasExpected(runes, true)]);
    }

    final errors = members.whereType<_Error>();
    final result = errors.isEmpty ? members : errors.toList(growable: false);
    if (result.length == 1) return result[0];
    return _GroupedExpression(result);
  }

  void reset() {
    _expr = null;
    failure = null;
  }

  @override
  Expression consume() {
    if (_expr == null) throw Exception('expression not parsed yet');
    final expr = _expr;
    reset();
    return expr;
  }

  ParsedExpression _parseToAssignmentEnd(RuneIterator runes, String keyword,
      List<ParsedExpression> members, bool withinParens) {
    var done = whitespaces.parse(runes) == ParseResult.DONE;
    if (done) {
      return _Error(['assignment expression'.wasExpected(runes, false)]);
    }

    final id = nextWord(runes);
    if (id.isEmpty) return _Error(['identifier'.wasExpected(runes, false)]);
    done = whitespaces.parse(runes) == ParseResult.DONE;
    final symbol = runes.currentAsString;
    if (done || symbol != '=') return _Error(['='.wasExpected(runes, true)]);

    // consume '='
    runes.moveNext();

    final value = _parseExpression(runes, withinParens);

    return _Assignment(keyword, id, value);
  }

  ParsedExpression _parseIf(RuneIterator runes, bool withinParens) {
    final condExpr = _parseExpression(runes, withinParens);
    if (withinParens && runes.currentAsString == ')') {
      return _Error(
          ['if expression ended unexpectedly: no then branch provided']);
    }
    final thenExpr = _parseExpression(runes, withinParens);
    whitespaces.parse(runes);
    final noElse = (withinParens && runes.currentAsString == ')') ||
        runes.currentAsString == null;

    if (noElse) {
      return _If(condExpr, thenExpr);
    }

    final elseExpr = _parseExpression(runes, withinParens);
    return _If(condExpr, thenExpr, elseExpr);
  }

  ParsedExpression _parseLoop(RuneIterator runes, bool withinParens) {
    final expr = _parseExpression(runes, withinParens);
    return _Loop(expr);
  }
}
