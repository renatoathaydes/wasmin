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
      : _declaration = DeclarationParser(words);

  @override
  ParseResult parse(ParserState runes) {
    reset();
    try {
      _expr = _parseExpression(runes, _context);
    } on TypeCheckException catch (e) {
      failure = CompilerError(runes.position, e.message);
      return ParseResult.FAIL;
    } catch (e) {
      failure = CompilerError(runes.position, e.toString());
      return ParseResult.FAIL;
    }

    final error = _expr.findError();
    if (error != null) {
      failure = error;
      return ParseResult.FAIL;
    }

    return runes.currentAsString == null
        ? ParseResult.DONE
        : ParseResult.CONTINUE;
  }

  Expression _parseExpression(ParserState runes, ParsingContext ctx) {
    whitespaces.parse(runes);
    if (runes.currentAsString == '(') {
      runes.moveNext();
      ctx = ctx.createChild();
      final group = <Expression>[];
      while (true) {
        final end =
            _parseToExpressionEnd(runes, _Grouping.withinParensImmediate, ctx);
        if (end.done) {
          if (end.expr != Expression.empty()) {
            group.add(end.expr);
          }
          break;
        } else {
          group.add(end.expr);
        }
      }
      return group.isEmpty
          ? Expression.empty()
          : group.length == 1 ? group[0] : Expression.group(group);
    } else {
      final end = _parseToExpressionEnd(runes, _Grouping.noParens, ctx);
      return end.expr;
    }
  }

  _ExpressionEnd _parseToExpressionEnd(
      ParserState runes, _Grouping grouping, ParsingContext ctx) {
    whitespaces.parse(runes);

    final firstWord = nextWord(runes);
    switch (firstWord) {
      case 'if':
        return _parseIf(runes, grouping, ctx);
      case 'loop':
        return _parseLoop(runes, grouping, ctx);
      case 'let':
        return _parseToAssignmentEnd(runes, AssignmentType.let, grouping, ctx);
      case 'mut':
        return _parseToAssignmentEnd(runes, AssignmentType.mut, grouping, ctx);
      case 'def':
      case 'export':
        _parseDeclaration(runes, ctx, firstWord.startsWith('e'));
        return _parseToExpressionEnd(runes, grouping, ctx);
    }

    if (firstWord.isEmpty) {
      if (runes.currentAsString == '(') {
        final expr = _parseExpression(runes, ctx.createChild());
        return _ExpressionEnd(expr, false);
      } else if (grouping == _Grouping.withinParensImmediate) {
        final end = _verifyExpressionEnd(runes, grouping);
        final error = end.expr;
        if (error != null) {
          return end;
        }
        return _ExpressionEnd(Expression.empty(), end.done);
      } else {
        // cannot have an empty expression that doesn't look like: ()
        return _ExpressionEnd(
            CompilerError(
                runes.position,
                runes.currentAsString == null
                    ? 'EOF encountered prematurely, incomplete expression'
                    : 'Missing expression'),
            true);
      }
    }
    // check if this is a re-assignment
    whitespaces.parse(runes);
    if (runes.currentAsString == '=') {
      runes.moveNext();
      final value = _parseToExpressionEnd(runes, grouping, ctx);
      return _ExpressionEnd(
          assignmentExpression(
              AssignmentType.reassign, firstWord, value.expr, ctx),
          value.done);
    }

    // this may be a function call, where 'firstWord' is the fun name,
    // the rest are its args
    final args = <Expression>[];
    while (true) {
      final word = nextWord(runes);
      if (word.isEmpty) {
        if (runes.currentAsString == '(') {
          args.add(_parseExpression(runes, ctx.createChild()));
        } else {
          break;
        }
      } else {
        args.add(singleMemberExpression(word, ctx));
      }
    }

    final end = _verifyExpressionEnd(runes, grouping);
    final error = end.expr;
    if (error != null) {
      return end;
    }

    return _ExpressionEnd(
        args.isEmpty
            ? singleMemberExpression(firstWord, ctx)
            : funCall(firstWord, args, ctx),
        end.done);
  }

  _ExpressionEnd _verifyExpressionEnd(ParserState runes, _Grouping grouping) {
    switch (grouping) {
      case _Grouping.withinParensImmediate:
        if (runes.currentAsString == ')') {
          runes.moveNext();
          return _ExpressionEnd(null, true);
        }
        if (runes.currentAsString == ';') {
          runes.moveNext();
          return _ExpressionEnd(null, false);
        }
        return _ExpressionEnd(')'.wasExpected(runes, quoteExpected: true),
            runes.currentAsString == null);
      case _Grouping.withinParensIndirect:
        if (runes.currentAsString == ')') {
          runes.moveNext();
          return _ExpressionEnd(null, true);
        }
        if (runes.currentAsString == ';') {
          runes.moveNext();
          return _ExpressionEnd(null, false);
        }
        return _ExpressionEnd(
            "';' or ')'".wasExpected(runes, quoteExpected: false),
            runes.currentAsString == null);
      case _Grouping.noParens:
        if (runes.currentAsString == ';' || runes.currentAsString == null) {
          runes.moveNext();
          return _ExpressionEnd(null, true);
        }
        return _ExpressionEnd(
            ';'.wasExpected(runes, quoteExpected: true), false);
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

  void _parseDeclaration(ParserState runes, ParsingContext ctx,
      bool isExported) {
    _declaration.isExported = isExported;
    final result = _declaration.parse(runes);
    switch (result) {
      case ParseResult.CONTINUE:
        ctx.add(_declaration.consume());
        break;
      case ParseResult.DONE:
        throw Exception('missing implementation for declaration');
      case ParseResult.FAIL:
        throw Exception('Malformed declaration: ${_declaration.failure}');
    }
  }

  _ExpressionEnd _parseToAssignmentEnd(ParserState runes,
      AssignmentType assignmentType, _Grouping grouping, ParsingContext ctx) {
    var done = whitespaces.parse(runes) == ParseResult.DONE;
    if (done) {
      return _ExpressionEnd(
          'assignment expression'
              .wasExpected(runes, prefix: 'Incomplete assignment'),
          true);
    }
    final id = nextWord(runes);
    if (id.isEmpty) {
      final end = _verifyExpressionEnd(runes, grouping);
      return _ExpressionEnd('identifier'.wasExpected(runes), end.done);
    }
    done = whitespaces.parse(runes) == ParseResult.DONE;
    final symbol = runes.currentAsString;
    if (done || symbol != '=') {
      return _ExpressionEnd(
          '='.wasExpected(runes,
              quoteExpected: true, prefix: 'Incomplete assignment'),
          true);
    }

    // consume '='
    runes.moveNext();

    final end = _parseToExpressionEnd(runes, grouping, ctx);
    return _ExpressionEnd(
        assignmentExpression(assignmentType, id, end.expr, ctx), end.done);
  }

  _ExpressionEnd _parseIf(ParserState runes, _Grouping grouping,
      ParsingContext ctx) {
    final condExprEnd = _parseToExpressionEnd(runes, grouping, ctx);
    if (grouping != _Grouping.noParens && condExprEnd.done) {
      return _ExpressionEnd(
          CompilerError(runes.position, 'then expression is missing'), true);
    }
    var result = whitespaces.parse(runes);
    if (result == ParseResult.DONE) {
      return _ExpressionEnd(
          CompilerError(runes.position, 'Expected then expression, got EOF'),
          true);
    }
    final thenExprEnd = _parseToExpressionEnd(runes, grouping, ctx);
    if ((grouping != _Grouping.noParens && thenExprEnd.done) ||
        whitespaces.parse(runes) == ParseResult.DONE) {
      return _ExpressionEnd(
          ifExpression(condExprEnd.expr, thenExprEnd.expr), thenExprEnd.done);
    }
    final elseExprEnd = _parseToExpressionEnd(runes, grouping, ctx);
    return _ExpressionEnd(
        ifExpression(condExprEnd.expr, thenExprEnd.expr, elseExprEnd.expr),
        elseExprEnd.done);
  }

  _ExpressionEnd _parseLoop(ParserState runes, _Grouping grouping,
      ParsingContext ctx) {
    final end = _parseToExpressionEnd(runes, grouping, ctx);
    return _ExpressionEnd(Expression.loopExpr(end.expr), end.done);
  }
}

enum _Grouping {
  withinParensImmediate,
  withinParensIndirect,
  noParens,
}

class _ExpressionEnd {
  final Expression expr;
  final bool done;

  _ExpressionEnd(this.expr, this.done);
}
