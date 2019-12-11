import 'package:wasmin/src/parse/expression.dart';
import 'package:wasmin/src/type.dart';
import 'package:wasmin/src/type_check.dart';

import '../ast.dart';
import '../expression.dart';
import '../type_context.dart';
import 'base.dart';

class FunParser with WordBasedParser<Fun> {
  final _whitespaces = const SkipWhitespaces();
  final WordParser words;
  final ParsingContext _typeContext;

  Fun _fun;

  FunParser(this.words, this._typeContext);

  @override
  ParseResult parse(RuneIterator runes) {
    reset();
    var word = nextWord(runes);
    if (word.isEmpty) {
      failure = "Incomplete fun. Expected identifier!";
      return ParseResult.FAIL;
    }

    final id = word;
    final args = <String>[];

    while (word.isNotEmpty) {
      word = nextWord(runes);
      if (word.isNotEmpty) args.add(word);
    }

    _whitespaces.parse(runes);

    if (runes.currentAsString != '=') {
      failure = "Incomplete fun. Expected '='!";
      return ParseResult.FAIL;
    }

    // drop '='
    runes.moveNext();

    Expression expression;
    ParseResult result;

    Declaration decl = _typeContext.declarationOf(id);
    if (decl != null) {
      expression = decl.match(
          onLet: (_) => throw TypeCheckException(
              "'$id' is declared as a let expression, but implemented as a fun expression."),
          onFun: (fun) {
            if (fun.type.takes.length == args.length) {
              final types = fun.type.takes.iterator;
              final funContext = _typeContext.createChild();
              for (final arg in args) {
                types.moveNext();
                funContext.add(LetDeclaration(arg, types.current));
              }
              final funExpression = ExpressionParser(words, funContext);

              result = funExpression.parse(runes);

              if (result == ParseResult.FAIL) {
                failure = "fun error: ${funExpression.failure}";
                return null;
              }
              return funExpression.consume();
            } else {
              throw TypeCheckException(
                  'function has ${args.length} parameters, but its '
                  'declaration requires ${fun.type.takes.length} arguments');
            }
          });
    } else {
      if (args.isNotEmpty) {
        throw Exception("Functions with arguments require "
            "a type declaration, but '$id' is missing one. "
            "This is a requirement because argument types cannot be inferred.");
      }
      decl = FunDeclaration(id, FunType(expression.type, const []));
      _typeContext.add(decl);
      final funExpression = ExpressionParser(words, _typeContext.createChild());
      result = funExpression.parse(runes);
      if (result == ParseResult.FAIL) {
        failure = "fun error: ${funExpression.failure}";
      } else {
        expression = funExpression.consume();
      }
    }

    if (result != ParseResult.FAIL) {
      _verifyType(decl, expression);
      _fun = Fun(decl as FunDeclaration, expression);
    }

    return result;
  }

  void reset() {
    _fun = null;
    failure = null;
  }

  @override
  Fun consume() {
    final result = _fun;
    if (result == null) throw Exception('Fun has not been parsed yet');
    reset();
    return result;
  }

  void _verifyType(FunDeclaration decl, Expression body) {
    if (decl.type.returns != body.type) {
      throw TypeCheckException(
          "'${decl.id}' return type should be '${decl.type.returns.name}', "
          "but its implementation has type '${body.type.name}'");
    }
  }
}
