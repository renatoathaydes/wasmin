import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;

  group('success', () {
    setUp(() => parser = ExpressionParser(WordParser(), ParsingContext()));

    test('can use variable at same scope level', () {
      final expectedResult = Expression.group([
        Expression.let('x', Expression.constant('0', ValueType.i32)),
        Expression.funCall(
            'add',
            [
              Expression.variable('x', ValueType.i32),
              Expression.constant('1', ValueType.i32),
            ],
            ValueType.i32),
      ]);

      for (final expression in [
        '(let x = 0;(add x 1))',
        '(((let x = 0;(add x 1))))',
        '(let x = 0;add x 1)',
      ]) {
        parser.parse(ParserState.fromString(expression));
        expect(parser.failure?.message, isNull,
            reason: 'Expression: $expression');
        expect(parser.consume(), equals(expectedResult),
            reason: 'Expression: $expression');
      }
    });

    test('can use variable from outer scope level', () {
      final expectedFirstResult = Expression.group([
        Expression.let('x', Expression.constant('0', ValueType.i32)),
        Expression.loopExpr(Expression.funCall(
            'add',
            [
              Expression.variable('x', ValueType.i32),
              Expression.constant('1', ValueType.i32),
            ],
            ValueType.i32)),
      ]);
      final expectedSecondResult = Expression.group([
        Expression.let('x', Expression.constant('0', ValueType.i32)),
        Expression.ifExpr(
            Expression.variable('x', ValueType.i32),
            Expression.funCall(
                'add',
                [
                  Expression.variable('x', ValueType.i32),
                  Expression.constant('1', ValueType.i32),
                ],
                ValueType.i32),
            Expression.variable('x', ValueType.i32)),
      ]);
      final expectedThirdResult = Expression.group([
        Expression.let('x', Expression.constant('0', ValueType.i32)),
        Expression.ifExpr(
            Expression.constant('1', ValueType.i32),
            Expression.funCall(
                'add',
                [
                  Expression.variable('x', ValueType.i32),
                  Expression.constant('1', ValueType.i32),
                ],
                ValueType.i32),
            Expression.funCall(
                'add',
                [
                  Expression.variable('x', ValueType.i32),
                  Expression.constant('2', ValueType.i32),
                ],
                ValueType.i32)),
      ]);

      final results = [
        expectedFirstResult,
        expectedSecondResult,
        expectedThirdResult
      ].iterator;

      for (final expression in [
        '(let x = 0; loop(add x 1))',
        '(let x = 0; (if (x) (add x 1) x))',
        '(let x = 0; if 1; add x 1; add x 2)',
      ]) {
        parser.parse(ParserState.fromString(expression));
        expect(parser.failure?.message, isNull,
            reason: 'Expression: $expression');
        results.moveNext();
        expect(parser.consume(), equals(results.current),
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
        final result = parser.parse(ParserState.fromString(expression));
        expect(parser.failure?.message, equals("unknown variable: 'x'"),
            reason: 'Expression: $expression');
        expect(result, equals(ParseResult.FAIL));
      }
    });
    test('cannot use variable before it is defined', () {
      for (final expression in [
        '(add x 1; let x = 0)',
        '(add x 1;(if 1; let x = 0))',
        '(add x 1; loop (let x = 0))',
      ]) {
        final result = parser.parse(ParserState.fromString(expression));
        expect(parser.failure?.message, equals("unknown variable: 'x'"),
            reason: 'Expression: $expression');
        expect(result, equals(ParseResult.FAIL));
      }
    });
  });
}
