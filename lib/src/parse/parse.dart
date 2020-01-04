import '../ast.dart';
import '../type_context.dart';
import 'base.dart';
import 'declaration.dart';
import 'expression.dart';
import 'fun.dart';
import 'iterator.dart';
import 'let.dart';

class WasminUnit {
  final List<Declaration> declarations = [];
  final List<Implementation> implementations = [];

  WasminUnit();
}

class WasminParser {
  final _wordParser = WordParser();
  final _context = ParsingContext();

  Future<WasminUnit> parse(ParserState runes) async {
    final unit = WasminUnit();
    await for (final node in _parse(runes)) {
      node.matchNode(
        onDeclaration: unit.declarations.add,
        onImpl: unit.implementations.add,
      );
    }
    return unit;
  }

  Stream<WasminNode> _parse(ParserState runes) async* {
    final expr = ExpressionParser(_wordParser, _context);
    final declaration = DeclarationParser(_wordParser, _context);
    final let = LetParser(expr, _context);
    final fun = FunParser(_wordParser, _context);
    var result = expr.whitespaces.parse(runes);

    while (result == ParseResult.CONTINUE) {
      expr.whitespaces.parse(runes);
      result = _wordParser.parse(runes);
      Parser<WasminNode> currentParser;
      switch (result) {
        case ParseResult.CONTINUE:
          final word = _wordParser.consume();
//          print("Word: '$word'");
          if (word == 'let') {
            currentParser = let;
          } else if (word == 'fun') {
            currentParser = fun;
          } else if (word == 'def') {
            currentParser = declaration;
          } else if (word == 'export') {
            currentParser = declaration..isExported = true;
          } else if (word.isEmpty) {
//            print("Got empty word, skipping separator");
            runes.moveNext();
          } else {
            // TODO this is an error
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
          throw Exception(currentParser.failure);
        } else {
          yield currentParser.consume();
        }
      }
    }
  }
}
