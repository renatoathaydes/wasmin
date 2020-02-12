import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';
import 'iterator.dart';

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
    T Function(CompilerError) onError,
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
    T Function(CompilerError) onError,
  }) {
    return onMember(name);
  }
}

class _Error extends ParsedExpression {
  final CompilerError error;

  const _Error(this.error) : super._();

  @override
  T match<T>({
    T Function(List<ParsedExpression> members) onGroup,
    T Function(ParsedExpression) onLoop,
    T Function(String value) onMember,
    T Function(String keyword, String id, ParsedExpression value) onAssignment,
    T Function(ParsedExpression cond, ParsedExpression thenExpr,
            [ParsedExpression elseExpr])
        onIf,
    T Function(CompilerError) onError,
  }) {
    return onError(error);
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
    T Function(CompilerError) onError,
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
    T Function(CompilerError) onError,
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
    T Function(CompilerError) onError,
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
    T Function(CompilerError) onError,
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
  ParseResult parse(ParserState runes) {
    reset();
    final expr = _parseExpression(runes, false);
    try {
      _expr = exprWithInferredType(expr, _context);
    } on TypeCheckException catch (e) {
      failure = CompilerError(runes.position, e.message);
      return ParseResult.FAIL;
    } catch (e) {
      failure = CompilerError(runes.position, e.toString());
      return ParseResult.FAIL;
    }

    if (_expr is CompilerError) {
      failure = _expr as CompilerError;
      return ParseResult.FAIL;
    }

    return runes.currentAsString == null
        ? ParseResult.DONE
        : ParseResult.CONTINUE;
  }

  ParsedExpression _parseExpression(ParserState runes, bool withinParens) {
    whitespaces.parse(runes);
    if (runes.currentAsString == '(') {
      runes.moveNext();
      return _parseToGroupEnd(runes);
    } else {
      return _parseToExpressionEnd(runes, withinParens);
    }
  }

  ParsedExpression _parseToGroupEnd(ParserState runes) {
    whitespaces.parse(runes);
    final members = <ParsedExpression>[];
    while (runes.currentAsString != ')' && runes.currentAsString != null) {
      members.add(_parseToExpressionEnd(runes, true));
      whitespaces.parse(runes);
    }

    if (runes.currentAsString == ')') {
      runes.moveNext();
    } else {
      return _Error(')'.wasExpected(runes, quoteExpected: true));
    }

    final errors = members.whereType<_Error>();
    final result = errors.isEmpty ? members : errors.toList(growable: false);
    if (result.length == 1) return result[0];
    return _GroupedExpression(result);
  }

  ParsedExpression _parseToExpressionEnd(ParserState runes, bool withinParens) {
    whitespaces.parse(runes);
    final members = <ParsedExpression>[];

    final firstWord = nextWord(runes);
    switch (firstWord) {
      case 'if':
        return _parseIf(runes, withinParens);
      case 'loop':
        return _parseLoop(runes, withinParens);
      case 'let':
      case 'mut':
        return _parseToAssignmentEnd(runes, firstWord, withinParens);
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
      ParserState runes, List<ParsedExpression> members, bool withinParens) {
    // check if the symbol after the word has special meaning or ends the
    // current group properly
    final nextSymbol = runes.currentAsString;
    if (nextSymbol == ')') {
      if (!withinParens) {
        return _Error(';'.wasExpected(runes, quoteExpected: true));
      }
    } else {
      if (members.isEmpty) {
        return _Error(CompilerError(runes.position, 'missing expression'));
      }
      if (nextSymbol == ';') {
        runes.moveNext();
      } else if (nextSymbol == null) {
        if (withinParens) {
          return _Error(')'.wasExpected(runes, quoteExpected: true));
        }
      } else {
        return _Error(
            (withinParens ? ')' : ';').wasExpected(runes, quoteExpected: true));
      }
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

  ParsedExpression _parseToAssignmentEnd(
      ParserState runes, String keyword, bool withinParens) {
    var done = whitespaces.parse(runes) == ParseResult.DONE;
    if (done) {
      return _Error('assignment expression'
          .wasExpected(runes, prefix: 'Incomplete assignment'));
    }
    final id = nextWord(runes);
    if (id.isEmpty) return _Error('identifier'.wasExpected(runes));
    done = whitespaces.parse(runes) == ParseResult.DONE;
    final symbol = runes.currentAsString;
    if (done || symbol != '=') {
      return _Error('='.wasExpected(runes,
          quoteExpected: true, prefix: 'Incomplete assignment'));
    }

    // consume '='
    runes.moveNext();

    final value = _parseExpression(runes, withinParens);

    return _Assignment(keyword, id, value);
  }

  ParsedExpression _parseIf(ParserState runes, bool withinParens) {
    final condExpr = _parseExpression(runes, withinParens);
    if (withinParens && runes.currentAsString == ')') {
      return _Error('else expression'
          .wasExpected(runes, prefix: 'Incomplete if expression'));
    }
    var result = whitespaces.parse(runes);
    if (result == ParseResult.DONE) {
      return _Error(
          CompilerError(runes.position, 'Expected then expression, got EOF'));
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

  ParsedExpression _parseLoop(ParserState runes, bool withinParens) {
    final expr = _parseExpression(runes, withinParens);
    return _Loop(expr);
  }
}
