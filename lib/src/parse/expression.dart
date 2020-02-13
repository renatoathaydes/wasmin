import 'package:wasmin/src/ast.dart';
import 'package:wasmin/src/parse/declaration.dart';

import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';
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
      _expr = _parseExpression(runes, false);
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

  Expression _parseExpression(ParserState runes, bool withinParens) {
    whitespaces.parse(runes);
    if (runes.currentAsString == '(') {
      runes.moveNext();
      return _parseToExpressionEnd(runes, true);
    } else {
      return _parseToExpressionEnd(runes, withinParens);
    }
  }

  Expression _parseToExpressionEnd(ParserState runes, bool withinParens) {
    whitespaces.parse(runes);

    final firstWord = nextWord(runes);
    switch (firstWord) {
      case 'if':
        return _parseIf(runes, withinParens);
      case 'loop':
        return _parseLoop(runes, withinParens);
      case 'let':
        return _parseToAssignmentEnd(runes, AssignmentType.let, withinParens);
      case 'mut':
        return _parseToAssignmentEnd(runes, AssignmentType.mut, withinParens);
    }

    if (firstWord.isEmpty) {
      if (runes.currentAsString == '(') {
        runes.moveNext();
        return _parseToExpressionEnd(runes, true);
      } else {
        final error = _verifyExpressionEnd(runes, withinParens);
        if (error != null) return error;
        return Expression.empty();
      }
    }
    // check if this is a re-assignment
    whitespaces.parse(runes);
    if (runes.currentAsString == '=') {
      runes.moveNext();
      final value = _parseExpression(runes, withinParens);
      return assignmentExpression(
          AssignmentType.reassign, firstWord, value, _context);
    }

    // this must be a function call, where 'firstWord' is the fun name,
    // the rest are its args
    final args = <Expression>[];
    while (true) {
      final word = nextWord(runes);
      if (word.isEmpty) {
        if (runes.currentAsString == '(') {
          runes.moveNext();
          args.add(_parseToExpressionEnd(runes, true));
        } else {
          break;
        }
      } else {
        args.add(singleMemberExpression(word, _context));
      }
    }

    final error = _verifyExpressionEnd(runes, withinParens);
    if (error != null) return error;

    return args.isEmpty
        ? singleMemberExpression(firstWord, _context)
        : funCall(firstWord, args, _context);
  }

  CompilerError _verifyExpressionEnd(ParserState runes, bool withinParens) {
    // expression must be properly terminated
    final nextSymbol = runes.currentAsString;

    if (withinParens) {
      if (nextSymbol != ')') {
        return ')'.wasExpected(runes, quoteExpected: true);
      }
      // parens properly closed, done
      runes.moveNext();
      return null;
    }
    if (nextSymbol != ';' && nextSymbol != null) {
      return ';'.wasExpected(runes, quoteExpected: true);
    }
    // expression terminated properly, done
    runes.moveNext();
    return null;
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
      ParserState runes, AssignmentType assignmentType, bool withinParens) {
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

    final value = _parseExpression(runes, withinParens);

    return assignmentExpression(assignmentType, id, value, _context);
  }

  Expression _parseIf(ParserState runes, bool withinParens) {
    final condExpr = _parseExpression(runes, withinParens);
    if (withinParens && runes.currentAsString == ')') {
      return 'else expression'
          .wasExpected(runes, prefix: 'Incomplete if expression');
    }
    var result = whitespaces.parse(runes);
    if (result == ParseResult.DONE) {
      return CompilerError(runes.position, 'Expected then expression, got EOF');
    }
    final thenExpr = _parseExpression(runes, withinParens);
    whitespaces.parse(runes);
    final noElse = (withinParens && runes.currentAsString == ')') ||
        runes.currentAsString == null;

    if (noElse) {
      return ifExpression(_context.createChild(), condExpr, thenExpr);
    }

    final elseExpr = _parseExpression(runes, withinParens);
    return ifExpression(_context.createChild(), condExpr, thenExpr, elseExpr);
  }

  Expression _parseLoop(ParserState runes, bool withinParens) {
    final expr = _parseExpression(runes, withinParens);
    return Expression.loopExpr(expr);
  }
}
