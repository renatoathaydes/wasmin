import 'package:test/test.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/expression.dart';
import 'package:wasmin/src/parse/let.dart';
import 'package:wasmin/src/type_context.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  LetParser parser;
  MutableTypeContext context;
  setUp(() {
    context = ParsingContext();
    parser = LetParser(ExpressionParser(WordParser(), ParsingContext()), context);
  });

  group('success cases', () {
    test('can parse let expression', () {
      final result = parser.parse('x=0'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.declaration.id, equals('x'));
      expect(let.body, equals(Expression.constant('0', ValueType.i64)));
      expect(context.declarationOf('x'),
          equals(LetDeclaration('x', ValueType.i64)));
    });

    test('can parse let expression with whitespace', () {
      final result =
          parser.parse(' one_thousand  =     1000   '.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.declaration.id, equals('one_thousand'));
      expect(let.body, equals(Expression.constant('1000', ValueType.i64)));
    });

    test('can parse let expression with function call', () {
      final iter = 'abc = mul 30 50;X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));

      final let = parser.consume();

      expect(let.declaration.id, equals('abc'));
      expect(
          let.body,
          equals(Expression.funCall(
              'mul',
              [
                Expression.constant('30', ValueType.i64),
                Expression.constant('50', ValueType.i64),
              ],
              ValueType.i64)));
    });

    test('can parse let expression with complex expression', () {
      final result = parser.parse(
          'complex = div_s (add 2 3) (mul 30 (sub 32 21))'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume();

      expect(let.declaration.id, equals('complex'));

      expect(
          let.body,
          equals(Expression.funCall(
              'div_s',
              [
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
              ],
              ValueType.i64)));
    });
  });

  group('failures', () {
    test('cannot parse let expression with no assignment', () {
      final result = parser.parse('one'.runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no =', () {
      final result = parser.parse('one 1'.runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value', () {
      final result = parser.parse('one = '.runes.iterator);
      expect(parser.failure, equals('Let expression error: Empty expression'));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no = (end with separator)', () {
      final result = parser.parse('one; = foo'.runes.iterator);
      expect(parser.failure, equals("Incomplete let expresion. Expected '='!"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value (end with separator)', () {
      final result = parser.parse('one=; foo'.runes.iterator);
      expect(parser.failure,
          equals('Let expression error: Unterminated expression'));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
