import '../ast.dart';
import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';
import 'declaration.dart';
import 'iterator.dart';

class ExpressionParser with WordBasedParser<Expression> {
  @override
  final WordParser words;
  final ParsingContext _context;
  final DeclarationParser _declaration;

  Expression _expr;

  ExpressionParser(this.words, this._context)
      : _declaration = DeclarationParser(words, _context);

  @override
  ParseResult parse(ParserState runes) {
    reset();
    try {
      _expr = _parseExpression(runes);
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

  Expression _parseExpression(ParserState runes) {
    whitespaces.parse(runes);
    if (runes.currentAsString == '(') {
      runes.moveNext();
      return _parseToExpressionEnd(runes, _Grouping.withinParensImmediate);
    } else {
      return _parseToExpressionEnd(runes, _Grouping.noParens);
    }
  }

  Expression _parseToExpressionEnd(ParserState runes, _Grouping grouping) {
    whitespaces.parse(runes);

    final firstWord = nextWord(runes);
    switch (firstWord) {
      case 'if':
        return _parseIf(runes, grouping);
      case 'loop':
        return _parseLoop(runes, grouping);
      case 'let':
        return _parseToAssignmentEnd(runes, AssignmentType.let, grouping);
      case 'mut':
        return _parseToAssignmentEnd(runes, AssignmentType.mut, grouping);
    }

    if (firstWord.isEmpty) {
      if (runes.currentAsString == '(') {
        runes.moveNext();
        return _parseGroup(runes);
      } else {
        final error = _verifyExpressionEnd(runes, grouping);
        if (error != null) {
          return error;
        }
        return Expression.empty();
      }
    }
    // check if this is a re-assignment
    whitespaces.parse(runes);
    if (runes.currentAsString == '=') {
      runes.moveNext();
      final value = _parseToExpressionEnd(runes, grouping);
      return assignmentExpression(
          AssignmentType.reassign, firstWord, value, _context);
    }

    // this may be a function call, where 'firstWord' is the fun name,
    // the rest are its args
    final args = <Expression>[];
    while (true) {
      final word = nextWord(runes);
      if (word.isEmpty) {
        if (runes.currentAsString == '(') {
          runes.moveNext();
          args.add(_parseGroup(runes));
        } else {
          break;
        }
      } else {
        args.add(singleMemberExpression(word, _context));
      }
    }

    final error = _verifyExpressionEnd(runes, grouping);
    if (error != null) {
      return error;
    }

    return args.isEmpty
        ? singleMemberExpression(firstWord, _context)
        : funCall(firstWord, args, _context);
  }

  Expression _parseGroup(ParserState runes) {
    var group = <Expression>[];
    var parensImmediate = true;
    while (true) {
      group.add(_parseToExpressionEnd(runes, _Grouping.withinParensIndirect));
      if (parensImmediate && runes.currentAsString == ')') {
        runes.moveNext();
        break;
      }
      parensImmediate = false;
      if (runes.currentAsString == ';') {
        runes.moveNext();
      } else if (runes.currentAsString == ')') {
        runes.moveNext();
        break;
      } else if (runes.currentAsString == null) {
        return ')'.wasExpected(runes, quoteExpected: true);
      }
    }
    return (group.length == 1) ? group[0] : Expression.group(group);
  }

  CompilerError _verifyExpressionEnd(ParserState runes, _Grouping grouping) {
    switch (grouping) {
      case _Grouping.withinParensImmediate:
        if (runes.currentAsString == ')') {
          runes.moveNext();
          return null;
        }
        if (runes.currentAsString == ';') {
          return null;
        }
        return ')'.wasExpected(runes, quoteExpected: true);
      case _Grouping.withinParensIndirect:
        if (runes.currentAsString == ')') {
          return null;
        }
        if (runes.currentAsString == ';') {
          runes.moveNext();
          return null;
        }
        return "';' or ')'".wasExpected(runes, quoteExpected: false);
      case _Grouping.noParens:
        if (runes.currentAsString == ';' || runes.currentAsString == null) {
          runes.moveNext();
          return null;
        }
        return ';'.wasExpected(runes, quoteExpected: true);
    }
    throw 'unreachable';
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

  Expression _parseToAssignmentEnd(
      ParserState runes, AssignmentType assignmentType, _Grouping grouping) {
    var done = whitespaces.parse(runes) == ParseResult.DONE;
    if (done) {
      return 'assignment expression'
          .wasExpected(runes, prefix: 'Incomplete assignment');
    }
    final id = nextWord(runes);
    if (id.isEmpty) return 'identifier'.wasExpected(runes);
    done = whitespaces.parse(runes) == ParseResult.DONE;
    final symbol = runes.currentAsString;
    if (done || symbol != '=') {
      return '='.wasExpected(runes,
          quoteExpected: true, prefix: 'Incomplete assignment');
    }

    // consume '='
    runes.moveNext();

    final value = _parseToExpressionEnd(runes, grouping);

    return assignmentExpression(assignmentType, id, value, _context);
  }

  Expression _parseIf(ParserState runes, _Grouping grouping) {
    whitespaces.parse(runes);
    final condExpr = _parseToExpressionEnd(
        runes,
        (runes.currentAsString == '(')
            ? _Grouping.withinParensImmediate
            : ((grouping == _Grouping.noParens)
                ? _Grouping.noParens
                : _Grouping.withinParensIndirect));
    var result = whitespaces.parse(runes);
    if (result == ParseResult.DONE) {
      return CompilerError(runes.position, 'Expected then expression, got EOF');
    }
    final thenExpr = _parseToExpressionEnd(
        runes,
        (runes.currentAsString == '(')
            ? _Grouping.withinParensImmediate
            : ((grouping == _Grouping.noParens)
                ? _Grouping.noParens
                : _Grouping.withinParensIndirect));
    result = whitespaces.parse(runes);
    bool noElse;
    if (result == ParseResult.DONE) {
      noElse = true;
    } else {
      switch (grouping) {
        case _Grouping.withinParensImmediate:
        case _Grouping.withinParensIndirect:
          noElse = const {';', ')'}.contains(runes.currentAsString);
          break;
        case _Grouping.noParens:
          noElse = runes.currentAsString == ';';
          break;
      }
    }

    if (noElse) {
      final error = _verifyExpressionEnd(runes, grouping);
      return error ?? ifExpression(_context.createChild(), condExpr, thenExpr);
    }

    final elseExpr = _parseExpression(runes);
    return ifExpression(_context.createChild(), condExpr, thenExpr, elseExpr);
  }

  Expression _parseLoop(ParserState runes, _Grouping grouping) {
    final expr = _parseToExpressionEnd(runes, grouping);
    return Expression.loopExpr(expr);
  }
}

enum _Grouping {
  withinParensImmediate,
  withinParensIndirect,
  noParens,
}
