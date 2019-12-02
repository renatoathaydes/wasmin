import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

import 'test_helper.dart';

void main() {
  LetParser parser;
  setUp(() => parser = LetParser(ExpressionParser(WordParser())));

  group('success cases', () {
    test('can parse let expression', () {
      final result = parser.parse("x=0".runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.id, equals('x'));
      expect(let.expr.op, equals('0'));
      expect(let.expr, isConstant);
    });

    test('can parse let expression with whitespace', () {
      final result =
          parser.parse(" one_thousand  =     1000   ".runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.id, equals('one_thousand'));
      expect(let.expr.op, equals('1000'));
      expect(let.expr, isConstant);
    });

    test('can parse let expression with function call', () {
      final iter = "abc = mul 30 50;X".runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));

      final let = parser.consume();

      expect(let.id, equals('abc'));
      expect(let.expr.op, equals('mul'));
      expect(
          argsOfFunCall(let.expr),
          equals(
              ['30', '50'].map((i) => Expression.constant(i, ValueType.i64))));
    });

    test('can parse let expression with complex expression', () {
      final result = parser.parse(
          "complex = div_s (add 2 3) (mul 30 (sub 32 21))".runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.id, equals('complex'));
      expect(let.expr.op, equals('div_s'));
      expect(
          argsOfFunCall(let.expr),
          equals([
            Expression.funCall(
                'add',
                [
                  Expression.constant('2', ValueType.i64),
                  Expression.constant('3', ValueType.i64),
                ],
                ValueType.i64),
            Expression.funCall(
                'mul',
                [
                  Expression.constant('30', ValueType.i64),
                  Expression.funCall(
                      'sub',
                      [
                        Expression.constant('32', ValueType.i64),
                        Expression.constant('21', ValueType.i64),
                      ],
                      ValueType.i64),
                ],
                ValueType.i64),
          ]));
    });
  });

  group('failures', () {
    test('cannot parse let expression with no assignment', () {
      final result = parser.parse("one".runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no =', () {
      final result = parser.parse("one 1".runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value', () {
      final result = parser.parse("one = ".runes.iterator);
      expect(parser.failure, equals("Let expression error: Empty expression"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no = (end with separator)', () {
      final result = parser.parse("one; = foo".runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value (end with separator)', () {
      final result = parser.parse("one=; foo".runes.iterator);
      expect(parser.failure,
          equals("Let expression error: Unterminated expression"));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
