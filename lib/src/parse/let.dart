import '../ast.dart';
import '../expression.dart';
import '../type_check.dart';
import '../type_context.dart';
import 'base.dart';
import 'expression.dart';
import 'iterator.dart';

class LetParser with WordBasedParser<Let> {
  final ExpressionParser _expr;

  @override
  final WordParser words;

  final ParsingContext _context;

  Expression _let;

  LetParser(this._expr, this._context) : words = _expr.words;

  @override
  ParseResult parse(ParserState runes) {
    reset();
    final let = _expr.parseLet(runes);

    try {
      _let = exprWithInferredType(let, _context);
    } on TypeCheckException catch (e) {
      failure = CompilerError(runes.position, e.message);
      return ParseResult.FAIL;
    } catch (e) {
      // FIXME parser should not throw Exception
      failure = CompilerError(runes.position, e.toString());
      return ParseResult.FAIL;
    }
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

}
