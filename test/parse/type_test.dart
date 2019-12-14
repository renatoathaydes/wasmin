import 'package:test/test.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/type.dart';
import 'package:wasmin/src/type.dart';

void main() {
  final parser = TypeParser(WordParser());
  group('success', () {
    test('can parse simple value type', () {
      final result = parser.parse('i32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type, equals(ValueType.i32));
    });

    test('can parse simple value type without consuming all input', () {
      final iter = 'f64 ;X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      final type = parser.consume();
      expect(type, equals(ValueType.f64));
      expect(iter.moveNext(), isTrue);
      expect(iter.currentAsString, equals('X'));
    });

    test('can parse simple function type', () {
      final result = parser.parse('[]i32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type, equals(FunType(ValueType.i32, const [])));
    });

    test('can parse simple function type with whitespaces', () {
      final result = parser.parse('[  ]  i32 '.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));
      final type = parser.consume();
      expect(type, equals(FunType(ValueType.i32, const [])));
    });

    test('can parse function type with single arg', () {
      final result = parser.parse('[f64]i32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type, equals(FunType(ValueType.i32, const [ValueType.f64])));
    });

    test('can parse function type with many args', () {
      final result = parser.parse('[f64, i32,f32  , i64 ] i32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(
          type,
          equals(FunType(ValueType.i32, const [
            ValueType.f64,
            ValueType.i32,
            ValueType.f32,
            ValueType.i64
          ])));
    });

    test('can parse function type with two args and trailing comma', () {
      final result = parser.parse('[f64, i32, ] \ni64'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type,
          equals(FunType(ValueType.i64, const [ValueType.f64, ValueType.i32])));
    });
  });

  group('failures', () {
    test('cannot parse empty string', () {
      final result = parser.parse(''.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure, equals('Expected type declaration, got EOF'));
    });

    test('must close function arguments list', () {
      final result = parser.parse('[i32'.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(
          parser.failure,
          equals(
              "Unterminated function parameter list. Expected ']', got EOF"));

      final result2 = parser.parse('[i32; ]i64'.runes.iterator);
      expect(result2, equals(ParseResult.FAIL));
      expect(
          parser.failure,
          equals(
              "Unterminated function parameter list. Expected ']', got ';'"));
    });
  });
}
