import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;

  setUp(() => parser = ExpressionParser(WordParser(), ParsingContext()));

  group('success', () {
    test('can parse constant', () {
      final result = parser.parse(ParserState.fromString('1'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(parser.consume(), equals(Expression.constant('1', ValueType.i64)));
    });

    test('can parse function call', () {
      final result = parser.parse(ParserState.fromString('mul 1 2'));
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(ParserState.fromString('(mul 1 2)'));
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(ParserState.fromString('(mul (add 1 2) 3)'));
      expect(parser.failure?.message, isNull);
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
      final result =
          parser.parse(ParserState.fromString('mul (add 1 2)( div_s 10 5 )'));
      expect(parser.failure?.message, isNull);
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
      final result =
          parser.parse(ParserState.fromString('(let n = 1;mul n 2)'));
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(ParserState.fromString(
          '(let x = 1; (let y = (add 1 2) )(add x y))X'));
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(
          ParserState.fromString('(let x = 1;\nlet y = add 1 2\n;add x y\n)X'));
      expect(parser.failure?.message, isNull);
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

    test('can parse re-assignment of mutable variables', () {
      final result =
          parser.parse(ParserState.fromString('(mut n = 1;n = 2; n)'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Expression.group([
            Expression.mut('n', Expression.constant('1', ValueType.i64)),
            Expression.reassign('n', Expression.constant('2', ValueType.i64)),
            Expression.variable('n', ValueType.i64),
          ])));
    });

    test('can parse if expression without else', () {
      final result = parser.parse(ParserState.fromString('if (0) 1'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      final ifExpr = parser.consume();
      expect(
          ifExpr,
          IfExpression(Expression.constant('0', ValueType.i64),
              Expression.constant('1', ValueType.i64)));
      expect(ifExpr.type, equals(ValueType.empty));
    });

    test('can parse grouped if expression without else', () {
      final iter = ParserState.fromString('(if (0) 1)X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(ParserState.fromString('if 1; 2; 3'));
      expect(parser.failure?.message, isNull);
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
      final iter = ParserState.fromString('if gt_s 1 0; mul 2 3; add 10 20;X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
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
      final iter = ParserState.fromString(
          'if (let n = 1; gt_s n 0) (mul 2 3) (add 10 20)X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
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
      final iter = ParserState.fromString('loop(0)X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));
      final loopExpr = parser.consume();
      expect(loopExpr, LoopExpression(Expression.constant('0', ValueType.i64)));
      expect(loopExpr.type, equals(ValueType.empty));
    });

    test('can parse usual loop expression', () {
      final iter = ParserState.fromString('loop  (\n'
          '  (if 1; break)\n'
          '  add 2 2\n'
          ')X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
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
      final result = parser.parse(ParserState.fromString('abcdef'));
      expect(parser.failure?.message, equals("unknown variable: 'abcdef'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse unknown function call', () {
      final result = parser.parse(ParserState.fromString('xxxx 1 2'));
      expect(parser.failure?.message, equals("unknown function: 'xxxx'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was terminated in the middle', () {
      final result = parser.parse(ParserState.fromString('(add 1 2;'));
      expect(parser.failure?.message, equals("Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was not terminated', () {
      final result = parser.parse(ParserState.fromString('(mul 3 2'));
      expect(parser.failure?.message, equals("Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse nested function call that was not terminated', () {
      final result = parser.parse(ParserState.fromString('(mul (add 3 2);'));
      expect(parser.failure?.message, equals("Expected ')', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse assignment not preceeded by binding', () {
      final result = parser.parse(ParserState.fromString('x=1'));
      expect(parser.failure?.message,
          equals("unknown variable 'x' cannot be re-assigned"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot re-assign immutable binding', () {
      final result =
          parser.parse(ParserState.fromString('(let x = 0 ; x = 1 ; x)'));
      expect(parser.failure?.message,
          equals("immutable variable 'x' cannot be re-assigned"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse if expression that was not terminated', () {
      final result = parser.parse(ParserState.fromString('if (add 3 2)'));
      expect(
          parser.failure?.message, equals('Expected then expression, got EOF'));
      expect(result, equals(ParseResult.FAIL));
    });

    test('type check fails for if and else branches with different types', () {
      final result = parser.parse(ParserState.fromString('if 0; 0.1; 0'));
      expect(
          parser.failure?.message,
          equals('if branches have different types '
              '(then: f64, else: i64)'));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
