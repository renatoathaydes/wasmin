import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;

  group('success', () {
    setUp(() => parser = ExpressionParser(WordParser(), ParsingContext()));

    test('can use variable at same scope level', () {
      final expectedResult = Expression.group([
        Expression.let('x', Expression.constant('0', ValueType.i64)),
        Expression.funCall(
            'add',
            [
              Expression.variable('x', ValueType.i64),
              Expression.constant('1', ValueType.i64),
            ],
            ValueType.i64),
      ]);

      for (final expression in [
        '((let x = 0) (add x 1))',
        '(((let x = 0)) ((add x 1)))',
        '(let x = 0;add x 1)',
      ]) {
        parser.parse(expression.runes.iterator);
        expect(parser.failure, isNull, reason: 'Expression: $expression');
        expect(parser.consume(), equals(expectedResult),
            reason: 'Expression: $expression');
      }
    });
  });

  group('failures', () {
    setUp(() => parser = ExpressionParser(WordParser(), ParsingContext()));

    test('cannot use variable from different scope', () {
      for (final expression in [
        '(loop (let x = 0) (add x 1))',
        '((if 1; let x = 0) add x 1)',
        '((if 1; (let x = 0;x) (let x = 2;x)) add x 1)',
      ]) {
        final result = parser.parse(expression.runes.iterator);
        expect(parser.failure,
            equals("type checking failed: unknown variable: 'x'"),
            reason: 'Expression: $expression');
        expect(result, equals(ParseResult.FAIL));
      }
    });
  });
}
