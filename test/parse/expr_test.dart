import 'package:test/test.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/expression.dart';
import 'package:wasmin/src/type_context.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;

  setUp(() => parser = ExpressionParser(WordParser(), ParsingContext()));

  group('success', () {
    test('can parse constant', () {
      final result = parser.parse('1'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(parser.consume(), equals(Expression.constant('1', ValueType.i64)));
    });

    test('can parse function call', () {
      final result = parser.parse('mul 1 2'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.funCall(
            'mul',
            [
              Expression.constant('1', ValueType.i64),
              Expression.constant('2', ValueType.i64),
            ],
            ValueType.i64,
          )));
    });

    test('can parse grouped function call', () {
      final result = parser.parse('(mul 1 2)'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.funCall(
            'mul',
            [
              Expression.constant('1', ValueType.i64),
              Expression.constant('2', ValueType.i64),
            ],
            ValueType.i64,
          )));
    });

    test('can parse nested function calls', () {
      final result = parser.parse('(mul (add 1 2) 3)'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.funCall(
            'mul',
            [
              Expression.funCall(
                'add',
                [
                  Expression.constant('1', ValueType.i64),
                  Expression.constant('2', ValueType.i64),
                ],
                ValueType.i64,
              ),
              Expression.constant('3', ValueType.i64),
            ],
            ValueType.i64,
          )));
    });

    test('can parse multiple nested function calls', () {
      final result = parser.parse('mul (add 1 2)( div_s 10 5 )'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.funCall(
            'mul',
            [
              Expression.funCall(
                'add',
                [
                  Expression.constant('1', ValueType.i64),
                  Expression.constant('2', ValueType.i64),
                ],
                ValueType.i64,
              ),
              Expression.funCall(
                'div_s',
                [
                  Expression.constant('10', ValueType.i64),
                  Expression.constant('5', ValueType.i64),
                ],
                ValueType.i64,
              )
            ],
            ValueType.i64,
          )));
    });

    test('can parse grouped expressions', () {
      final result = parser.parse('(let n = 1;mul n 2)'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.group([
            Expression.let('n', Expression.constant('1', ValueType.i64)),
            Expression.funCall(
              'mul',
              [
                Expression.variable('n', ValueType.i64),
                Expression.constant('2', ValueType.i64),
              ],
              ValueType.i64,
            )
          ])));
    });

    test('can parse complex grouped expressions', () {
      final result = parser
          .parse('(let x = 1; (let y = (add 1 2) )(add x y))X'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(
          parser.consume(),
          equals(Expression.group([
            Expression.let('x', Expression.constant('1', ValueType.i64)),
            Expression.let(
                'y',
                Expression.funCall(
                    'add',
                    [
                      Expression.constant('1', ValueType.i64),
                      Expression.constant('2', ValueType.i64),
                    ],
                    ValueType.i64)),
            Expression.funCall(
              'add',
              [
                Expression.variable('x', ValueType.i64),
                Expression.variable('y', ValueType.i64),
              ],
              ValueType.i64,
            )
          ])));
    });

    test('can parse complex grouped expressions (no parenthesis)', () {
      final result = parser
          .parse('(let x = 1;\nlet y = add 1 2\n;add x y\n)X'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(
          parser.consume(),
          equals(Expression.group([
            Expression.let('x', Expression.constant('1', ValueType.i64)),
            Expression.let(
                'y',
                Expression.funCall(
                    'add',
                    [
                      Expression.constant('1', ValueType.i64),
                      Expression.constant('2', ValueType.i64),
                    ],
                    ValueType.i64)),
            Expression.funCall(
              'add',
              [
                Expression.variable('x', ValueType.i64),
                Expression.variable('y', ValueType.i64),
              ],
              ValueType.i64,
            )
          ])));
    });

    test('can parse if expression without else', () {
      final result = parser.parse('if (0) 1'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(Expression.constant('0', ValueType.i64),
              Expression.constant('1', ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.empty));
    });

    test('can parse grouped if expression without else', () {
      final iter = '(if (0) 1)X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(Expression.constant('0', ValueType.i64),
              Expression.constant('1', ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.empty));
    });

    test('can parse if expression with else', () {
      final result = parser.parse('if 1; 2; 3'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(
              Expression.constant('1', ValueType.i64),
              Expression.constant('2', ValueType.i64),
              Expression.constant('3', ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.i64));
    });

    test('can parse if expression with complex expressions', () {
      final iter = 'if gt_s 1 0; mul 2 3; add 10 20;X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(
              Expression.funCall(
                  'gt_s',
                  [
                    Expression.constant('1', ValueType.i64),
                    Expression.constant('0', ValueType.i64)
                  ],
                  ValueType.i64),
              Expression.funCall(
                  'mul',
                  [
                    Expression.constant('2', ValueType.i64),
                    Expression.constant('3', ValueType.i64)
                  ],
                  ValueType.i64),
              Expression.funCall(
                  'add',
                  [
                    Expression.constant('10', ValueType.i64),
                    Expression.constant('20', ValueType.i64)
                  ],
                  ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.i64));
    });

    test('can parse if expression with complex grouped expressions', () {
      final iter =
          'if (let n = 1; gt_s n 0) (mul 2 3) (add 10 20)X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(
              Expression.group([
                Expression.let('n', Expression.constant('1', ValueType.i64)),
                Expression.funCall(
                    'gt_s',
                    [
                      Expression.variable('n', ValueType.i64),
                      Expression.constant('0', ValueType.i64)
                    ],
                    ValueType.i64),
              ]),
              Expression.funCall(
                  'mul',
                  [
                    Expression.constant('2', ValueType.i64),
                    Expression.constant('3', ValueType.i64)
                  ],
                  ValueType.i64),
              Expression.funCall(
                  'add',
                  [
                    Expression.constant('10', ValueType.i64),
                    Expression.constant('20', ValueType.i64)
                  ],
                  ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.i64));
    });

    test('can parse simple loop expression', () {
      final iter = 'loop(0)X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final loopExpr = parser.consume();
      expect(loopExpr, LoopExpression(Expression.constant('0', ValueType.i64)));
      expect(loopExpr.type, equals(ValueType.empty));
    });

    test('can parse usual loop expression', () {
      final iter = 'loop  (\n'
              '  (if 1; break)\n'
              '  add 2 2\n'
              ')X'
          .runes
          .iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final loopExpr = parser.consume();
      expect(
          loopExpr,
          Expression.loopExpr(Expression.group([
            Expression.ifExpr(Expression.constant('1', ValueType.i64),
                Expression.breakExpr()),
            Expression.funCall(
                'add',
                [
                  Expression.constant('2', ValueType.i64),
                  Expression.constant('2', ValueType.i64)
                ],
                ValueType.i64)
          ])));
      expect(loopExpr.type, equals(ValueType.empty));
    });
  });

  group('failures', () {
    test('cannot parse invalid constant', () {
      final result = parser.parse('abcdef'.runes.iterator);
      expect(parser.failure, equals("unknown variable: 'abcdef'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse unknown function call', () {
      final result = parser.parse('xxxx 1 2'.runes.iterator);
      expect(parser.failure, equals("unknown function: 'xxxx'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was terminated in the middle', () {
      final result = parser.parse('(add 1 2;'.runes.iterator);
      expect(parser.failure, equals("Exception: Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was not terminated', () {
      final result = parser.parse('(mul 3 2'.runes.iterator);
      expect(parser.failure, equals("Exception: Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse nested function call that was not terminated', () {
      final result = parser.parse('(mul (add 3 2);'.runes.iterator);
      expect(parser.failure, equals("Exception: Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    // FIXME need to return error expression instead of throw, to fix this
    test('cannot parse if expression that was not terminated', () {
      final result = parser.parse('if (add 3 2)'.runes.iterator);
      expect(parser.failure,
          equals('Exception: Expected then expression, got EOF'));
      expect(result, equals(ParseResult.FAIL));
    }, skip: true);

    test('type check fails for if and else branches with different types', () {
      final result = parser.parse('if 0; 0.1; 0'.runes.iterator);
      expect(
          parser.failure,
          equals('if branches have different types '
              '(then: f64, else: i64)'));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
