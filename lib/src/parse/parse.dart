import '../ast.dart';
import '../type_context.dart';
import 'base.dart';
import 'expression.dart';
import 'let.dart';

class WasminParser {
  final _wordParser = WordParser();
  final _context = ParsingContext();

  Stream<AstNode> parse(RuneIterator runes) async* {
    final expr = ExpressionParser(_wordParser, _context);
    final let = LetParser(expr, _context);
    ParseResult result = ParseResult.CONTINUE;

    while (result == ParseResult.CONTINUE) {
      result = _wordParser.parse(runes);
      Parser currentParser;
      switch (result) {
        case ParseResult.CONTINUE:
          final word = _wordParser.consumeWord();
//          print("Word: '$word'");
          if (word == 'let') {
            currentParser = let;
          } else if (word.isEmpty) {
//            print("Got empty word, skipping separator");
            runes.moveNext();
          } else {
            throw "top-level element not allowed: '$word'";
          }
          break;
        case ParseResult.DONE:
          break;
        case ParseResult.FAIL:
          throw 'unreachable';
      }
      if (currentParser != null) {
        result = currentParser.parse(runes);
        if (result == ParseResult.FAIL) {
          throw currentParser.failure;
        } else {
          yield currentParser.consume();
        }
      }
    }
  }
}
