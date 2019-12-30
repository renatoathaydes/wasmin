import 'package:wasmin/src/parse/expression.dart';
import 'package:wasmin/src/type_check.dart';

import '../ast.dart';
import '../expression.dart';
import '../type_context.dart';
import 'base.dart';
import 'iterator.dart';

class LetParser with WordBasedParser<Let> {
  final ExpressionParser _expr;

  final _whitespaces = SkipWhitespaces();
  @override
  final WordParser words;
  final MutableTypeContext _typeContext;

  Let _let;

  LetParser(this._expr, this._typeContext) : words = _expr.words;

  @override
  ParseResult parse(ParserState runes) {
    reset();
    var word = nextWord(runes);
    if (word.isEmpty) {
      failure =
          'identifier'.wasExpected(runes, prefix: 'Incomplete let expresion');
      return ParseResult.FAIL;
    }
    final id = word;

    _whitespaces.parse(runes);

    if (runes.currentAsString != '=') {
      failure = '='.wasExpected(runes,
          quoteExpected: true, prefix: 'Incomplete let expresion');
      return ParseResult.FAIL;
    }

    // drop '='
    runes.moveNext();

    final result = _expr.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = _expr.failure;
    } else {
      final expression = _expr.consume();

      // success!! Remember defined variable
      var decl = _typeContext.declarationOf(id);
      if (decl != null) {
        decl.match(
            onFun: (_) => throw TypeCheckException(
                "'$id' is declared as a function, but implemented as a let expression."),
            onVar: (let) => _verifyType(let, expression));
      } else {
        decl = VarDeclaration(id, expression.type, isGlobal: true);
        _typeContext.add(decl);
      }
      _let = Let(decl as VarDeclaration, expression);
    }
    return result;
  }

  void reset() {
    _let = null;
    _expr.reset();
    failure = null;
  }

  @override
  Let consume() {
    final result = _let;
    if (result == null) {
      throw Exception('Let expression has not been parsed yet');
    }
    reset();
    return result;
  }

  void _verifyType(VarDeclaration decl, Expression body) {
    if (decl.varType != body.type) {
      throw TypeCheckException(
          "'${decl.id}' type should be '${decl.varType.name}', but its "
          "implementation has type '${body.type.name}'");
    }
  }
}
