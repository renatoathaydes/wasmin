import '../ast.dart';
import '../expression.dart';
import '../type_context.dart';
import 'base.dart';
import 'expression.dart';
import 'iterator.dart';

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
    var result = expr.whitespaces.parse(runes);
    while (result == ParseResult.CONTINUE) {
      result = expr.parse(runes);
      if (result == ParseResult.FAIL) {
        throw Exception(expr.failure);
      } else {
        yield expr.consume().forceIntoTopLevelNode();
      }
    }
  }
}

extension TopLevelElement on Expression {
  WasminNode forceIntoTopLevelNode() {
    return matchExpr(
      onGroup: (g) => throw Exception('top-level expressions not allowed'),
      onFunCall: (f) => throw Exception('top-level function call not allowed'),
      onVariable: (v) => throw Exception('top-level variable not allowed'),
      onBreak: () => throw Exception('top-level break not allowed'),
      onLoop: (l) => throw Exception('top-level loop not allowed'),
      onIf: (i) => throw Exception('top-level loop not allowed'),
      onError: (err) => throw Exception(err.message),
      onConst: (c) => throw Exception('top-level constant now allowed'),
      onAssign: (a) {
        if (a.assignmentType == AssignmentType.reassign) {
          throw Exception('top-level re-assignment now allowed');
        }
        return Let(a.declaration, a.body);
      },
    );
  }
}
