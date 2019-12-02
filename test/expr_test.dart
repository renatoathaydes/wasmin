import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;

  setUp(() => parser = ExpressionParser(WordParser()));

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
          equals(Expression(
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
          equals(Expression(
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
          equals(Expression(
            'mul',
            [
              Expression(
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
          equals(Expression(
            'mul',
            [
              Expression(
                'add',
                [
                  Expression.constant('1', ValueType.i64),
                  Expression.constant('2', ValueType.i64),
                ],
                ValueType.i64,
              ),
              Expression(
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
  });

  group('failures', () {
    test('cannot parse invalid constant', () {
      final result = parser.parse('abcdef'.runes.iterator);
      expect(parser.failure,
          equals("type checking failed: unknown variable: 'abcdef'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse unknown function call', () {
      final result = parser.parse('xxxx 1 2'.runes.iterator);
      expect(parser.failure,
          equals("type checking failed: unknown function: 'xxxx'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was terminated in the middle', () {
      final result = parser.parse('add (1; 2)'.runes.iterator);
      expect(parser.failure, equals("Unterminated expression"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse function call that was not terminated', () {
      final result = parser.parse('(mul 3 2'.runes.iterator);
      expect(parser.failure, equals("Unterminated expression"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse nested function call that was not terminated', () {
      final result = parser.parse('(mul (add 3 2);'.runes.iterator);
      expect(parser.failure, equals("Unterminated expression"));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
