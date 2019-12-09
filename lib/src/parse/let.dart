import 'package:wasmin/src/parse/expression.dart';
import 'package:wasmin/src/type_check.dart';

import '../ast.dart';
import '../expression.dart';
import '../type_context.dart';
import 'base.dart';

class LetParser with WordBasedParser<Let> {
  String _id = '';
  Expression _expression;
  final ExpressionParser _expr;

  final _whitespaces = const SkipWhitespaces();
  final WordParser words;
  final TypeContext _typeContext;
  final Map<String, Declaration> declarations;

  LetParser(this._expr,
      [this._typeContext = const WasmDefaultTypeContext(),
      this.declarations = const {}])
      : words = _expr.words;

  @override
  ParseResult parse(RuneIterator runes) {
    reset();
    var word = nextWord(runes);
    if (word.isEmpty) {
      failure = "Incomplete let expresion. Expected identifier!";
      return ParseResult.FAIL;
    }
    _id = word;

    _whitespaces.parse(runes);

    if (runes.currentAsString != '=') {
      failure = "Incomplete let expresion. Expected '='!";
      return ParseResult.FAIL;
    }

    // drop '='
    runes.moveNext();

    final result = _expr.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = "Let expression error: ${_expr.failure}";
    } else {
      _expression = _expr.consume();

      // success!! Remember defined variable
      if (_typeContext is MutableTypeContext) {
        (_typeContext as MutableTypeContext)
            .addFun(FunDeclaration.variable(_expression.type, _id));
      }
    }
    return result;
  }

  void reset() {
    _id = '';
    _expression = null;
    _expr.reset();
    failure = null;
  }

  @override
  Let consume() {
    if (_id.isEmpty) throw Exception('Let identifier has not been set');
    if (_expression == null) throw Exception('Let expression has not been set');
    Declaration decl = declarations[_id];
    if (decl != null) {
      decl.match(
          onFun: (_) => throw TypeCheckException(
              "'$_id' is declared as a function, but implemented as a let expression."),
          onLet: (_) {});
    } else {
      decl = LetDeclaration(_id, _expression.type);
    }
    final let = Let(decl as LetDeclaration, _expression);
    reset();
    return let;
  }
}
