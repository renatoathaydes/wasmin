import 'package:wasmin/src/parse/declaration.dart';
import 'package:wasmin/src/parse/fun.dart';

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

  // TODO this implementation should be recursive, so all levels of the program
  //      are basically treated as expressions.
  Stream _parse(RuneIterator runes) async* {
    final expr = ExpressionParser(_wordParser, _context);
    final declaration = DeclarationParser(_wordParser, _context);
    final let = LetParser(expr, _context);
    final fun = FunParser(_wordParser, _context);
    var result = ParseResult.CONTINUE;

    while (result == ParseResult.CONTINUE) {
      result = _wordParser.parse(runes);
      Parser currentParser;
      switch (result) {
        case ParseResult.CONTINUE:
          final word = _wordParser.consume();
//          print("Word: '$word'");
          if (word == 'let') {
            currentParser = let;
          } else if (word == 'fun') {
            currentParser = fun;
          } else if (word.isEmpty) {
//            print("Got empty word, skipping separator");
            runes.moveNext();
          } else {
            currentParser = declaration..firstWord = word;
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
