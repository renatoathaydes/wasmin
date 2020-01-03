import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  final parser = FunParser(WordParser(), ParsingContext());

  group('functions without type declarations', () {
    test('can parse function with no args returning constant', () {
      final result = parser.parse(ParserState.fromString('main = 10'));

      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(FunDeclaration('main', FunType(ValueType.i32, const [])),
              const [], Expression.constant('10', ValueType.i32))));
    });

    test('can parse function with no args returning single expression', () {
      final result = parser.parse(ParserState.fromString('foo = add 2.0 3.3'));

      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(
              FunDeclaration('foo', FunType(ValueType.f32, const [])),
              const [],
              Expression.funCall(
                  'add',
                  [
                    Expression.constant('2.0', ValueType.f32),
                    Expression.constant('3.3', ValueType.f32),
                  ],
                  ValueType.f32))));
    });

    test('can parse function with no args returning grouped expression', () {
      final iter =
          ParserState.fromString('n = (let x = 2.0; let y = 3.3; add x y)');
      final result = parser.parse(iter);

      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(
              FunDeclaration('n', FunType(ValueType.f32, [])),
              const [],
              Expression.group([
                Expression.let('x', Expression.constant('2.0', ValueType.f32)),
                Expression.let('y', Expression.constant('3.3', ValueType.f32)),
                Expression.funCall(
                    'add',
                    [
                      Expression.variable('x', ValueType.f32),
                      Expression.variable('y', ValueType.f32),
                    ],
                    ValueType.f32)
              ]))));
    });
  });
}
