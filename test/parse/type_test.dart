import 'package:test/test.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/type.dart';
import 'package:wasmin/src/type.dart';

void main() {
  final parser = TypeParser(WordParser());
  group('success', () {
    test('can parse simple value type', () {
      final result = parser.parse("i32".runes.iterator);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type, equals(ValueType.i32));
    });

    test('can parse simple value type without consuming all input', () {
      final iter = "f64 X".runes.iterator;
      final result = parser.parse(iter);
      expect(result, equals(ParseResult.CONTINUE));
      final type = parser.consume();
      expect(type, equals(ValueType.f64));
      expect(iter.moveNext(), isTrue);
      expect(iter.currentAsString, equals('X'));
    });

    test('can parse simple function type', () {
      final result = parser.parse("[]i32".runes.iterator);
      expect(result, equals(ParseResult.DONE));
      final type = parser.consume();
      expect(type, equals(FunType(ValueType.i32, const [])));
    });
  });
}
