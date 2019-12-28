import 'package:test/test.dart';
import 'package:wasmin/src/ast.dart';
import 'package:wasmin/src/expression.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/fun.dart';
import 'package:wasmin/src/type.dart';
import 'package:wasmin/src/type_context.dart';

void main() {
  final parser = FunParser(WordParser(), ParsingContext());

  group('functions without type declarations', () {
    test('can parse function with no args returning constant', () {
      final result = parser.parse('main = 10'.runes.iterator);

      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(FunDeclaration('main', FunType(ValueType.i64, const [])),
              const [], Expression.constant('10', ValueType.i64))));
    });

    test('can parse function with no args returning single expression', () {
      final result = parser.parse('foo = add 2.0 3.3'.runes.iterator);

      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(
              FunDeclaration('foo', FunType(ValueType.f64, const [])),
              const [],
              Expression.funCall(
                  'add',
                  [
                    Expression.constant('2.0', ValueType.f64),
                    Expression.constant('3.3', ValueType.f64),
                  ],
                  ValueType.f64))));
    });

    test('can parse function with no args returning grouped expression', () {
      final iter = 'n = (let x = 2.0; let y = 3.3; add x y)'.runes.iterator;
      final result = parser.parse(iter);

      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      expect(
          parser.consume(),
          equals(Fun(
              FunDeclaration('n', FunType(ValueType.f64, [])),
              const [],
              Expression.group([
                Expression.let('x', Expression.constant('2.0', ValueType.f64)),
                Expression.let('y', Expression.constant('3.3', ValueType.f64)),
                Expression.funCall(
                    'add',
                    [
                      Expression.variable('x', ValueType.f64),
                      Expression.variable('y', ValueType.f64),
                    ],
                    ValueType.f64)
              ]))));
    });
  });
}
