import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  ExpressionParser parser;
  ParsingContext context;
  setUp(() {
    context = ParsingContext();
    parser = ExpressionParser(WordParser(), context);
  });

  group('success cases', () {
    test('can parse let expression', () {
      final result = parser.parse(ParserState.fromString('let x=0'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('x'));
      expect(let.body, equals(Expression.constant('0', ValueType.i32)));
      expect(context.declarationOf('x'),
          equals(VarDeclaration('x', ValueType.i32, isGlobal: true)));
    });

    test('can parse def then let expression', () {
      final result =
          parser.parse(ParserState.fromString('def int i64;\nlet int = 32'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('int'));
      expect(let.body, equals(Expression.constant('32', ValueType.i64)));
      expect(context.declarationOf('int'),
          equals(VarDeclaration('int', ValueType.i64, isGlobal: true)));
    });

    test('can parse exported let expression', () {
      final result = parser.parse(
          ParserState.fromString('export def num f64;\nlet num = 0.314159'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('num'));
      expect(let.body, equals(Expression.constant('0.314159', ValueType.f64)));
      expect(
          context.declarationOf('num'),
          equals(VarDeclaration('num', ValueType.f64,
              isExported: true, isGlobal: true)));
    });

    test('can parse let expression with whitespace', () {
      final result = parser
          .parse(ParserState.fromString('let one_thousand  =     1000   '));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('one_thousand'));
      expect(let.body, equals(Expression.constant('1000', ValueType.i32)));
    });

    test('can parse let expression with function call', () {
      final iter = ParserState.fromString('let abc = mul 30 50;X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      expect(iter.currentAsString, equals('X'));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('abc'));
      expect(
          let.body,
          equals(Expression.funCall(
              'mul',
              [
                Expression.constant('30', ValueType.i32),
                Expression.constant('50', ValueType.i32),
              ],
              ValueType.i32)));
    });

    test('can parse let expression with complex expression', () {
      final result = parser.parse(ParserState.fromString(
          'let complex = div_s (add 2 3) (mul 30 (sub 32 21))'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final let = parser.consume().forceIntoTopLevelNode() as Let;

      expect(let.declaration.id, equals('complex'));

      expect(
          let.body,
          equals(Expression.funCall(
              'div_s',
              [
                Expression.funCall(
                    'add',
                    [
                      Expression.constant('2', ValueType.i32),
                      Expression.constant('3', ValueType.i32),
                    ],
                    ValueType.i32),
                Expression.funCall(
                    'mul',
                    [
                      Expression.constant('30', ValueType.i32),
                      Expression.funCall(
                          'sub',
                          [
                            Expression.constant('32', ValueType.i32),
                            Expression.constant('21', ValueType.i32),
                          ],
                          ValueType.i32),
                    ],
                    ValueType.i32),
              ],
              ValueType.i32)));
    });
  });

  group('failures', () {
    test('cannot parse let expression with no assignment', () {
      final result = parser.parse(ParserState.fromString('let one'));
      expect(parser.failure?.message,
          equals("Incomplete assignment. Expected '=', got EOF"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no =', () {
      final result = parser.parse(ParserState.fromString('let one 1'));
      expect(parser.failure?.message,
          equals("Incomplete assignment. Expected '=', got '1'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value', () {
      final result = parser.parse(ParserState.fromString('let one = '));
      expect(parser.failure?.message,
          equals('EOF encountered prematurely, incomplete expression'));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no = (end with separator)', () {
      final result = parser.parse(ParserState.fromString('let one; = foo'));
      expect(parser.failure?.message,
          equals("Incomplete assignment. Expected '=', got ';'"));
      expect(result, equals(ParseResult.FAIL));
    });

    test('cannot parse let expression with no value (end with separator)', () {
      final result = parser.parse(ParserState.fromString('let one=;'));
      expect(parser.failure?.message, equals('Missing expression'));
      expect(result, equals(ParseResult.FAIL));
    });
  });
}
