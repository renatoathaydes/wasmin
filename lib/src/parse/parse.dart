import '../ast.dart';
import '../type_context.dart';
import 'base.dart';
import 'expression.dart';
import 'let.dart';

class WasminUnit {
  final List<Declaration> declarations = [];
  final List<Implementation> implementations = [];

  WasminUnit();
}

class WasminParser {
  final _wordParser = WordParser();
  final _context = ParsingContext();

  Future<WasminUnit> parse(RuneIterator runes) async {
    final unit = WasminUnit();
    await for (final node in _parse(runes)) {
      if (node is Declaration) {
        unit.declarations.add(node);
      } else if (node is Implementation) {
        unit.implementations.add(node);
      } else {
        throw 'Parser emitted unknown node type: $node';
      }
    }
    return unit;
  }

  Stream _parse(RuneIterator runes) async* {
    // TODO parse fun and let type declarations
    // TODO parse fun implementation

    final declarations = <String, Declaration>{};
    final expr = ExpressionParser(_wordParser, _context);
    final let = LetParser(expr, _context, declarations);
    ParseResult result = ParseResult.CONTINUE;

    while (result == ParseResult.CONTINUE) {
      result = _wordParser.parse(runes);
      Parser currentParser;
      switch (result) {
        case ParseResult.CONTINUE:
          final word = _wordParser.consume();
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
