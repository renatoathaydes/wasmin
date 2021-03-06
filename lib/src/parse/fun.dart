import '../ast.dart';
import '../expression.dart';
import '../type.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';
import 'expression.dart';
import 'iterator.dart';

class FunParser with WordBasedParser<Fun> {
  final _whitespaces = SkipWhitespaces();
  @override
  final WordParser words;
  final ParsingContext _typeContext;

  Fun _fun;

  FunParser(this.words, this._typeContext);

  @override
  ParseResult parse(ParserState runes) {
    reset();
    var word = nextWord(runes);
    if (word.isEmpty) {
      failure = 'function identifier'
          .wasExpected(runes, prefix: 'Incomplete function declaration');
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
      failure = '='.wasExpected(runes,
          quoteExpected: true, prefix: 'Incomplete function declaration');
      return ParseResult.FAIL;
    }

    // drop '='
    runes.moveNext();

    Expression expression;
    ParseResult result;

    var decl = _typeContext.declarationOf(id);
    if (decl != null) {
      expression = decl.match(
          onVar: (_) =>
              throw TypeCheckException("'$id' is declared as a variable, "
                  'but implemented as a function.'),
          onFun: (fun) {
            if (fun.type.takes.length == args.length) {
              final types = fun.type.takes.iterator;
              final funContext = _typeContext.createChild();
              for (final arg in args) {
                types.moveNext();
                funContext.add(VarDeclaration(arg, types.current));
              }
              final funExpression = ExpressionParser(words, funContext);

              result = funExpression.parse(runes);

              if (result == ParseResult.FAIL) {
                failure = funExpression.failure;
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
      // undeclared function
      if (args.isNotEmpty) {
        throw Exception('Functions with arguments require '
            "a type declaration, but the '$id' function is missing one. "
            'This is a requirement because function argument types '
            'cannot be inferred.');
      }
      final funExpression = ExpressionParser(words, _typeContext.createChild());
      result = funExpression.parse(runes);
      if (result == ParseResult.FAIL) {
        failure = funExpression.failure;
      } else {
        expression = funExpression.consume();
        decl = FunDeclaration(id, FunType(expression.type, const []));
        _typeContext.add(decl);
      }
    }

    if (result != ParseResult.FAIL) {
      final funDecl = decl as FunDeclaration;
      _verifyType(funDecl, expression);
      _fun = Fun(funDecl, args, expression);
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
